import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../client.dart';
import '../controller.dart';
import '../design.dart';
import '../models.dart';
import '../screen_recorder.dart';
import '../strings.dart';
import '../theme.dart';
import 'annotator.dart';
import 'assist_views.dart';
import 'chat.dart';
import 'ios_composer.dart';
import 'reporter_views.dart';

/// The feedback form. Full screen on phones, a centred card on wider screens.
class FeedbackPanel extends StatefulWidget {
  /// Creates the panel.
  const FeedbackPanel({
    super.key,
    required this.controller,
    required this.strings,
    required this.request,
    required this.onClose,
    this.screenshot,
    this.theme = const SeaproofTheme(),
    this.recording,
    this.onRecord,
    this.onRemoveRecording,
  });

  /// The SDK state.
  final SeaproofController controller;

  /// Texts.
  final SeaproofStrings strings;

  /// What opened the panel.
  final ShowRequest request;

  /// The screen as it was when the panel opened, as PNG, if one could be taken.
  final Uint8List? screenshot;

  /// Closes the panel.
  final VoidCallback onClose;

  /// Layout and shape; colours come from the surrounding [Theme].
  final SeaproofTheme theme;

  /// The screen recording to attach, once one was made.
  final SeaproofRecording? recording;

  /// Hides the panel and starts recording. Null when recording is not offered.
  final VoidCallback? onRecord;

  /// Removes [recording].
  final VoidCallback? onRemoveRecording;

  /// Width from which the panel is a card instead of full screen.
  static const double wideBreakpoint = 600;

  bool _isCard(BuildContext context) => switch (theme.panelStyle ?? SeaproofPanelStyle.auto) {
    SeaproofPanelStyle.card => true,
    SeaproofPanelStyle.fullScreen => false,
    SeaproofPanelStyle.auto => MediaQuery.sizeOf(context).width >= wideBreakpoint,
  };

  @override
  State<FeedbackPanel> createState() => _FeedbackPanelState();
}

enum _Tab { send, ownFeedback, ideas }

enum _Quick { mark, record, done }

/// One line in the conversation.
sealed class _Line {
  const _Line();
}

final class _AssistantLine extends _Line {
  const _AssistantLine(this.text, [this.quickReplies = const []]);

  final String text;
  final List<_Quick> quickReplies;
}

final class _YourText extends _Line {
  const _YourText(this.text);

  final String text;
}

final class _YourImage extends _Line {
  const _YourImage(this.png, this.label, {this.recording});

  final Uint8List png;
  final String label;
  final Uint8List? recording;
}

/// The conversation that makes a report. The first message saves it, with the screenshot
/// and recording waiting in the composer; everything after that is added to the saved report,
/// so nothing the user said is lost if Seaproof Assist is slow, off or out of quota.
class _FeedbackPanelState extends State<FeedbackPanel> {
  final TextEditingController _description = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final GlobalKey<IosComposerState> _iosComposer = GlobalKey();
  final GlobalKey _pastedPreview = GlobalKey();
  final ScrollController _scroll = ScrollController();
  late FeedbackType _type;
  late bool _mayContact;
  bool _showEmail = false;
  bool _emailEdited = false;

  /// The screen as it was when the panel opened. Kept to mark it up later in the conversation.
  Uint8List? _screenshot;

  /// What goes out with the next message.
  Uint8List? _pendingShot;
  FeedbackAttachment? _pastedShot;
  bool _pendingMarked = false;
  ui.Image? _decoded;
  Uint8List? _playingRecording;
  bool _annotating = false;
  bool _annotatingPasted = false;
  bool _openingAnnotator = false;
  bool _recordingForOwn = false;
  final List<_Line> _lines = [];
  SubmittedFeedback? _saved;
  bool _finished = false;
  bool _busy = false;
  String? _error;
  Timer? _closeTimer;
  _Tab _tab = _Tab.send;
  List<OwnFeedback> _ownFeedback = const [];
  List<PublicIdea> _ideas = const [];
  AssistSettings _assist = AssistSettings.off;
  List<Suggestion> _suggestions = const [];
  final Set<String> _voted = {};
  List<({String text, String? receipt})> _questions = const [];

  /// All Assist help for this report is one conversation against the plan's quota.
  final String _conversationId = newConversationId();
  Timer? _suggestTimer;
  String _suggestedFor = '';

  /// Wait this long after the last keystroke before looking for similar reports.
  static const _suggestDelay = Duration(milliseconds: 600);
  static const _minSuggestLength = 10;

  /// Seaproof Assist asks at most this many questions per report.
  static const _maxQuestions = 5;

  /// At most this share of the height above the composer goes to suggestions and previews.
  static const _extrasShare = 0.45;

  SeaproofController get _controller => widget.controller;
  SeaproofStrings get _strings => widget.strings;
  String get _reporterEmail => (_emailEdited ? _email.text : _controller.user?.email ?? '').trim();

  @override
  void initState() {
    super.initState();
    final types = _controller.types;
    _type = widget.request.type != null && types.contains(widget.request.type) ? widget.request.type! : types.first;
    _screenshot = widget.screenshot;
    // Testers want the screenshot; end users choose to share it, with the camera button.
    if (_screenshot != null && (widget.request.includeScreenshot ?? _controller.isTesterMode)) {
      _pendingShot = _screenshot;
    }
    // Testers are colleagues; end users must say yes before the team contacts them.
    _mayContact = _controller.isTesterMode;
    unawaited(_loadTabs());
    unawaited(_loadAssist());
    _description.addListener(_onDescriptionChanged);
  }

  @override
  void didUpdateWidget(FeedbackPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recording made after the report was saved goes straight to it.
    if (_sendRecording case final recording? when oldWidget.recording == null && _saved != null) {
      widget.onRemoveRecording?.call();
      unawaited(
        _addFiles(
          [recording.toAttachment()],
          shown: _YourImage(
            recording.firstFrame,
            _strings.recordingLabel(recording.duration),
            recording: recording.apng,
          ),
          what: _Added.recording,
        ),
      );
    }
  }

  Future<void> _loadAssist() async {
    final assist = await _controller.assistSettings();
    if (mounted) {
      setState(() => _assist = assist);
      _refreshSuggestions();
    }
  }

  /// Looks again for the current text, after the type or the settings changed.
  void _refreshSuggestions() {
    _suggestedFor = '';
    _onDescriptionChanged();
  }

  void _onDescriptionChanged() {
    if (_error == _strings.descriptionRequired && _description.text.trim().isNotEmpty) {
      setState(() => _error = null);
    }
    final text = _description.text.trim();
    final wanted =
        _saved == null && _assist.suggestions && _type != FeedbackType.question && text.length >= _minSuggestLength
        ? text
        : '';
    if (wanted == _suggestedFor) {
      return;
    }

    _suggestedFor = wanted;
    _suggestTimer?.cancel();
    if (wanted.isEmpty) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const []);
      }
      return;
    }

    _suggestTimer = Timer(_suggestDelay, () async {
      List<Suggestion> found;
      try {
        found = await _controller.suggest(wanted, type: _type);
      } on SeaproofException catch (e) {
        // Suggestions are optional help: a failure must never get in the way of feedback.
        debugPrint('Seaproof: could not load suggestions ($e).');
        found = const [];
      }
      if (mounted && _suggestedFor == wanted) {
        setState(() => _suggestions = found);
      }
    });
  }

  Future<void> _toggleVote(Suggestion idea) async {
    final voting = !_voted.contains(idea.id);
    setState(() => voting ? _voted.add(idea.id) : _voted.remove(idea.id));
    try {
      await (voting ? _controller.vote(idea.id) : _controller.unvote(idea.id));
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: voting failed ($e).');
      if (mounted) {
        setState(() => voting ? _voted.remove(idea.id) : _voted.add(idea.id));
      }
    }
  }

  // The tabs appear only once there is something in them, so a first-time user sees the conversation.
  Future<void> _loadTabs() async {
    final config = _controller.config;
    Future<List<T>> load<T>(bool enabled, Future<List<T>> Function() fetch) async {
      if (!enabled) {
        return const [];
      }

      try {
        return await fetch();
      } on SeaproofException catch (e) {
        debugPrint('Seaproof: could not load the panel tabs ($e).');
        return const [];
      }
    }

    final (own, ideas) = await (
      load(config.showOwnFeedback, _controller.myFeedback),
      load(config.showIdeas, _controller.ideas),
    ).wait;
    if (mounted) {
      setState(() {
        _ownFeedback = own;
        _ideas = ideas;
      });
    }
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _suggestTimer?.cancel();
    _description.dispose();
    _email.dispose();
    _emailFocus.dispose();
    _scroll.dispose();
    _decoded?.dispose();
    super.dispose();
  }

  void _say(_Line line) {
    setState(() => _lines.add(line));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        unawaited(
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: SeaproofTokens.tide,
          ),
        );
      }
    });
  }

  String get _shotLabel => _pendingMarked ? _strings.screenshotMarked : _strings.screenshotLabel;

  List<_Quick> get _showOptions => [if (_screenshot != null) _Quick.mark, if (widget.onRecord != null) _Quick.record];

  static FeedbackAttachment _shotAttachment(Uint8List png, {bool marked = false}) => FeedbackAttachment(
    kind: AttachmentKind.screenshot,
    fileName: marked ? 'screenshot-marked.png' : 'screenshot.png',
    contentType: 'image/png',
    bytes: png,
  );

  SeaproofRecording? get _sendRecording => _recordingForOwn ? null : widget.recording;

  void _record({bool forOwnFeedback = false}) {
    _dismissKeyboard();
    setState(() => _recordingForOwn = forOwnFeedback);
    widget.onRecord?.call();
  }

  static FeedbackAttachment _pastedAttachment(Uint8List png) => FeedbackAttachment(
    kind: AttachmentKind.screenshot,
    fileName: 'screenshot-pasted.png',
    contentType: 'image/png',
    bytes: png,
  );

  void _pasteScreenshot(Uint8List? bytes) {
    if (_busy || _annotating) {
      return;
    }
    setState(() {
      _error = bytes == null ? _strings.pasteScreenshotFailed : null;
      if (bytes != null) {
        _pastedShot = _pastedAttachment(bytes);
      }
    });
    if (bytes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pastedPreview.currentContext case final preview?) {
          unawaited(Scrollable.ensureVisible(preview, alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd));
        }
      });
    }
  }

  Future<void> _startAnnotating({bool pasted = false, Uint8List? sentScreenshot}) async {
    final image = sentScreenshot ?? (pasted ? _pastedShot?.bytes : _pendingShot ?? _screenshot);
    if (image == null || _openingAnnotator) {
      return;
    }

    _openingAnnotator = true;
    _dismissKeyboard();
    try {
      final codec = await ui.instantiateImageCodec(image);
      final frame = await codec.getNextFrame().whenComplete(codec.dispose);
      if (!mounted || _busy || _tab != _Tab.send || (pasted && !identical(_pastedShot?.bytes, image))) {
        frame.image.dispose();
        return;
      }
      _decoded?.dispose();
      _decoded = frame.image;
      _annotatingPasted = pasted;
      setState(() => _annotating = true);
    } finally {
      _openingAnnotator = false;
    }
  }

  void _playRecording(Uint8List apng) {
    _dismissKeyboard();
    setState(() => _playingRecording = apng);
  }

  void _finishAnnotating(Uint8List png, int hidden) {
    setState(() {
      _annotating = false;
      _decoded?.dispose();
      _decoded = null;
    });
    if (_annotatingPasted) {
      setState(() => _pastedShot = _pastedAttachment(png));
    } else if (_saved == null) {
      setState(() {
        _pendingShot = png;
        _pendingMarked = true;
      });
    } else {
      unawaited(
        _addFiles(
          [_shotAttachment(png, marked: true)],
          shown: _YourImage(png, _strings.screenshotMarked),
          what: _Added.screenshot,
        ),
      );
    }
  }

  Future<void> _send({Suggestion? linkedTo}) async {
    if (_busy) {
      return;
    }

    final text = _description.text.trim();
    if (_saved case final saved?) {
      if (text.isEmpty && _pendingShot == null && _pastedShot == null) {
        return;
      }
      _dismissKeyboard();
      await _addMessage(saved, text);
      return;
    }

    if (text.isEmpty) {
      setState(() => _error = _strings.descriptionRequired);
      return;
    }

    _dismissKeyboard();
    await _save(text, linkedTo);
  }

  Future<void> _save(String description, Suggestion? linkedTo) async {
    final identified = _controller.user;
    final email = _reporterEmail;
    final user = identified == null && email.isEmpty
        ? null
        : SeaproofUser(
            id: identified?.id,
            name: identified?.name,
            userHash: identified?.userHash,
            email: email.isEmpty ? null : email,
          );
    final shot = _pendingShot;
    final pastedShot = _pastedShot;
    final recording = _sendRecording;
    final firstLine = _lines.length;
    if (shot != null) {
      _say(_YourImage(shot, _shotLabel));
    }
    if (recording != null) {
      _say(_YourImage(recording.firstFrame, _strings.recordingLabel(recording.duration), recording: recording.apng));
    }
    _say(_YourText(description));
    _description.clear();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _controller.submit(
        FeedbackDraft(
          type: _type,
          description: description,
          user: user,
          mayContact: user?.email != null && _mayContact,
          linkedTo: linkedTo?.id,
          attachments: [
            if (shot != null) _shotAttachment(shot, marked: _pendingMarked),
            ?pastedShot,
            if (recording != null) recording.toAttachment(),
          ],
        ),
      );
      if (result.failedUploads.isNotEmpty) {
        debugPrint(
          'Seaproof: #${result.number} was sent, but ${result.failedUploads.length} attachment(s) failed to upload.',
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _saved = result;
        _pendingShot = null;
        _pendingMarked = false;
        _suggestions = const [];
        if (result.failedUploads.contains(pastedShot)) {
          _error = _strings.addFailed;
        } else {
          _pastedShot = null;
        }
      });
      if (pastedShot != null && _pastedShot == null) {
        setState(() => _lines.insert(firstLine, _YourImage(pastedShot.bytes, _strings.pastedScreenshot)));
      }
      if (recording != null) {
        widget.onRemoveRecording?.call();
      }
      await _followUp(result, description, linkedTo);
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: sending feedback failed ($e).');
      if (mounted) {
        // Nothing was saved: put it all back so the user can try again.
        setState(() {
          _lines.removeRange(firstLine, _lines.length);
          _description.text = description;
          _error = _strings.failed;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _followUp(SubmittedFeedback saved, String description, Suggestion? linkedTo) async {
    final n = saved.number;
    if (linkedTo != null) {
      _say(_AssistantLine(SeaproofStrings.fill(_strings.savedLinked, number: n), const [_Quick.done]));
      return;
    }

    if (_assist.followUpQuestions) {
      final review = await _controller.review(
        _type,
        description,
        conversationId: _conversationId,
        feedbackId: saved.id,
      );
      final asked = [
        for (final (index, text) in review.questions.take(_maxQuestions).indexed)
          (text: text, receipt: index < review.questionReceipts.length ? review.questionReceipts[index] : null),
      ];
      final first = asked.firstOrNull;
      final recorded = mounted && first != null && await _controller.recordAssistQuestion(saved.id, first.receipt);
      if (!mounted) {
        return;
      }
      if (first != null && recorded) {
        _questions = asked.skip(1).toList();
        _say(
          _AssistantLine(SeaproofStrings.fill(_strings.savedWithQuestion, number: n, question: first.text), [
            if (_type == FeedbackType.bug || _type == FeedbackType.feedback) ..._showOptions,
            _Quick.done,
          ]),
        );
        return;
      }
    }

    final show = _showOptions;
    _say(switch (_type) {
      FeedbackType.bug when show.isNotEmpty => _AssistantLine(SeaproofStrings.fill(_strings.savedShow, number: n), [
        ...show,
        _Quick.done,
      ]),
      FeedbackType.bug => _AssistantLine(SeaproofStrings.fill(_strings.savedBug, number: n), const [_Quick.done]),
      FeedbackType.idea => _AssistantLine(SeaproofStrings.fill(_strings.savedIdea, number: n), const [_Quick.done]),
      FeedbackType.question => _AssistantLine(SeaproofStrings.fill(_strings.savedQuestion, number: n), const [
        _Quick.done,
      ]),
      FeedbackType.feedback => _AssistantLine(SeaproofStrings.fill(_strings.savedFeedback, number: n), [
        ...show,
        _Quick.done,
      ]),
    });
  }

  Future<void> _addMessage(SubmittedFeedback saved, String text) async {
    final shot = _pendingShot;
    final pastedShot = _pastedShot;
    var attachmentLine = _lines.length;
    if (text.isNotEmpty) {
      _say(_YourText(text));
    }
    _description.clear();
    setState(() {
      _busy = true;
      _error = null;
      _pendingShot = null;
    });
    try {
      final message = text.isEmpty ? null : await _controller.sendMessage(saved.id, text);
      if (shot != null) {
        if (!mounted) return;
        setState(() => _lines.insert(attachmentLine++, _YourImage(shot, _shotLabel)));
        await _controller.addAttachments(saved.id, [
          _shotAttachment(shot, marked: _pendingMarked),
        ], messageId: message?.id);
      }
      if (pastedShot != null) {
        final failed = await _controller.addAttachments(saved.id, [pastedShot], messageId: message?.id);
        if (!mounted) {
          return;
        }
        if (failed.isNotEmpty) {
          setState(() => _error = _strings.addFailed);
          return;
        }
        setState(() {
          _pastedShot = null;
          _lines.insert(attachmentLine, _YourImage(pastedShot.bytes, _strings.pastedScreenshot));
        });
      }
      if (!mounted) {
        return;
      }

      final next = _questions.firstOrNull;
      if (text.isNotEmpty && next != null) {
        final recorded = await _controller.recordAssistQuestion(saved.id, next.receipt);
        if (!mounted) {
          return;
        }
        _questions = recorded ? _questions.skip(1).toList() : const [];
        if (recorded) {
          _say(_AssistantLine(next.text, const [_Quick.done]));
          return;
        }
      }
      _say(_AssistantLine(SeaproofStrings.fill(_strings.addedMessage, number: saved.number), const [_Quick.done]));
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: adding to #${saved.number} failed ($e).');
      if (mounted) {
        setState(() => _error = _strings.addFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addFiles(List<FeedbackAttachment> files, {required _Line shown, required _Added what}) async {
    final saved = _saved!;
    _say(shown);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final failed = await _controller.addAttachments(saved.id, files);
      if (!mounted) {
        return;
      }
      if (failed.isNotEmpty) {
        setState(() => _error = _strings.addFailed);
      } else {
        final template = what == _Added.screenshot ? _strings.addedScreenshot : _strings.addedRecording;
        _say(_AssistantLine(SeaproofStrings.fill(template, number: saved.number), const [_Quick.done]));
      }
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: adding to #${saved.number} failed ($e).');
      if (mounted) {
        setState(() => _error = _strings.addFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _onQuick(_Quick quick) {
    switch (quick) {
      case _Quick.mark:
        unawaited(_startAnnotating());
      case _Quick.record:
        _record();
      case _Quick.done:
        setState(() => _finished = true);
        _closeTimer = Timer(const Duration(seconds: 2), widget.onClose);
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    unawaited(_iosComposer.currentState?.dismissKeyboard());
  }

  Future<void> _toggleEmail() async {
    if (_showEmail) {
      _emailFocus.unfocus();
      setState(() => _showEmail = false);
      return;
    }
    await _iosComposer.currentState?.dismissKeyboard();
    if (!mounted || _saved != null || _busy) {
      return;
    }
    if (!_emailEdited) {
      _email.text = _reporterEmail;
    }
    setState(() => _showEmail = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _showEmail) {
        _emailFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = widget._isCard(context);
    final Widget content;
    if (_playingRecording case final recording?) {
      content = ChatRecordingViewer(
        image: MemoryImage(recording),
        title: _strings.screenRecording,
        back: _strings.back,
        loadFailed: _strings.loadFailed,
        onClose: () => setState(() => _playingRecording = null),
      );
    } else if (_annotating) {
      content = ScreenshotAnnotator(
        image: _decoded!,
        strings: _strings,
        penColor: widget.theme.annotationColor ?? ScreenshotAnnotator.defaultPenColor,
        hideFirst: !_controller.isTesterMode,
        onCancel: () => setState(() => _annotating = false),
        onDone: _finishAnnotating,
      );
    } else if (_finished) {
      content = _Sent(strings: _strings, number: _saved?.number, onClose: widget.onClose);
    } else {
      content = _panel(context);
    }

    // The host sits above the app's Navigator, outside its Scaffold's keyboard resizing.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onTap: _dismissKeyboard,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              _surface(content, wide: wide, height: constraints.maxHeight, keyboardVisible: keyboardInset > 0),
        ),
      ),
    );
  }

  Widget _surface(Widget content, {required bool wide, required double height, required bool keyboardVisible}) {
    if (!wide) {
      final reduceMotion = MediaQuery.disableAnimationsOf(context);
      return TweenAnimationBuilder<Offset>(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
        curve: SeaproofTokens.swell,
        tween: Tween(begin: const Offset(0, 1), end: Offset.zero),
        builder: (context, offset, child) => FractionalTranslation(translation: offset, child: child),
        child: Material(child: SafeArea(child: content)),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _busy ? null : widget.onClose,
            child: ColoredBox(color: widget.theme.barrierColor ?? const Color(0x8A000000)),
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _annotating ? 1100 : 480,
              maxHeight: height * (keyboardVisible ? 1 : (_annotating ? 0.92 : 0.86)),
            ),
            child: SizedBox(
              height: _finished ? null : (_annotating ? height * 0.92 : 680),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(widget.theme.borderRadius ?? SeaproofTheme.defaultBorderRadius),
                clipBehavior: Clip.antiAlias,
                child: content,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panel(BuildContext context) {
    final strings = _strings;
    final theme = Theme.of(context);
    final tabs = [_Tab.send, if (_ownFeedback.isNotEmpty) _Tab.ownFeedback, if (_ideas.isNotEmpty) _Tab.ideas];
    final tab = tabs.contains(_tab) ? _tab : _Tab.send;
    final unread = _ownFeedback.any(_controller.hasUnreadReply);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_controller.isTesterMode) _TestStrip(label: strings.testMode, environment: _controller.environmentName),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              if (widget.controller.logo case final logo?)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 28, maxWidth: 112),
                    child: Image.memory(
                      logo,
                      key: const ValueKey('seaproof-logo'),
                      excludeFromSemantics: true,
                      gaplessPlayback: true,
                      // A broken image must never get in the way of feedback.
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              Expanded(
                child: Text(strings.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
              ),
              IconButton(icon: const Icon(Icons.close), tooltip: strings.close, onPressed: widget.onClose),
            ],
          ),
        ),
        if (tabs.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: _Tabs(
              key: const ValueKey('seaproof-tabs'),
              tabs: [
                for (final t in tabs)
                  (
                    value: t,
                    label: switch (t) {
                      _Tab.send => Text(strings.tabSend),
                      _Tab.ideas => Text(strings.tabIdeas),
                      _Tab.ownFeedback => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(strings.tabOwnFeedback, overflow: TextOverflow.ellipsis)),
                          if (unread) ...[
                            const SizedBox(width: 6),
                            Semantics(
                              label: strings.newReply,
                              child: const Icon(Icons.circle, size: 8, color: SeaproofTokens.signal),
                            ),
                          ],
                        ],
                      ),
                    },
                  ),
              ],
              selected: tab,
              onSelected: (t) {
                if (_tab == _Tab.ownFeedback && t != _tab && _recordingForOwn && widget.recording != null) {
                  widget.onRemoveRecording?.call();
                }
                setState(() => _tab = t);
              },
            ),
          ),
        Expanded(
          child: switch (tab) {
            _Tab.ownFeedback => OwnFeedbackView(
              controller: _controller,
              strings: strings,
              items: _ownFeedback,
              screenshot: _screenshot,
              recording: _recordingForOwn ? widget.recording : null,
              onRecord: widget.onRecord == null ? null : () => _record(forOwnFeedback: true),
              onRemoveRecording: widget.onRemoveRecording,
              annotationColor: widget.theme.annotationColor,
              onRead: () => setState(() {}),
            ),
            _Tab.ideas => IdeasView(
              controller: _controller,
              strings: strings,
              ideas: _ideas,
              onSuggest: () => setState(() {
                _tab = _Tab.send;
                if (_saved == null && _controller.types.contains(FeedbackType.idea)) {
                  _type = FeedbackType.idea;
                }
              }),
            ),
            _Tab.send => _conversation(context),
          },
        ),
      ],
    );
  }

  Widget _conversation(BuildContext context) {
    final strings = _strings;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final greeting = _controller.isTesterMode ? strings.greetingTester : strings.greeting;
    final lastAssistant = _lines.whereType<_AssistantLine>().lastOrNull;

    final extras = <Widget>[
      if (_saved == null && _suggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SuggestionList(
            suggestions: _suggestions,
            voted: _voted,
            strings: strings,
            onLink: (s) => unawaited(_send(linkedTo: s)),
            onVote: (s) => unawaited(_toggleVote(s)),
          ),
        ),
      if (_error case final error?)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Semantics(
            liveRegion: true,
            child: Text(error, style: TextStyle(color: scheme.error)),
          ),
        ),
      if (_pendingShot case final shot?)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ChatAttachmentRow(
            key: const ValueKey('seaproof-pending-screenshot'),
            preview: Image.memory(shot, height: 40, width: 56, fit: BoxFit.cover, gaplessPlayback: true),
            title: _shotLabel,
            onTap: _busy ? null : _startAnnotating,
            removeTooltip: strings.removeScreenshot,
            removeKey: const ValueKey('seaproof-remove-screenshot'),
            onRemove: _busy ? null : () => setState(() => _pendingShot = null),
          ),
        ),
      if (_pastedShot case final image?)
        Padding(
          key: _pastedPreview,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ChatAttachmentRow(
            key: const ValueKey('seaproof-pasted-screenshot'),
            preview: Image.memory(image.bytes, height: 40, width: 56, fit: BoxFit.cover, gaplessPlayback: true),
            title: strings.pastedScreenshot,
            onTap: _busy ? null : () => _startAnnotating(pasted: true),
            removeTooltip: strings.removeScreenshot,
            removeKey: const ValueKey('seaproof-remove-pasted-screenshot'),
            onRemove: _busy ? null : () => setState(() => _pastedShot = null),
          ),
        ),
      if (_sendRecording case final recording? when _saved == null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: ChatAttachmentRow(
            key: const ValueKey('seaproof-pending-recording'),
            preview: Image.memory(
              recording.firstFrame,
              height: 40,
              width: 56,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
            title: strings.recordingLabel(recording.duration),
            leadingAction: Icons.play_arrow_outlined,
            onTap: _busy ? null : () => _playRecording(recording.apng),
            removeTooltip: strings.removeRecording,
            removeKey: const ValueKey('seaproof-remove-recording'),
            onRemove: _busy ? null : widget.onRemoveRecording,
          ),
        ),
    ];

    // The keyboard only changes the height available here, never which widgets are built where:
    // moving a widget would rebuild the focused text field and close the keyboard again on iOS.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        const Divider(height: 1),
        // The composer below is laid out first, so it always fits; the conversation and the
        // suggestions and previews share what is left.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ChatHistory(
                    key: const ValueKey('seaproof-conversation'),
                    controller: _scroll,
                    children: [
                      ChatIncomingBubble(text: greeting),
                      if (_saved == null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 34),
                          child: _TypeChips(
                            types: _controller.types,
                            selected: _type,
                            labels: strings.typeLabels,
                            onSelected: _busy
                                ? null
                                : (type) {
                                    setState(() => _type = type);
                                    _refreshSuggestions();
                                  },
                          ),
                        ),
                      ],
                      for (final line in _lines) ...[
                        const SizedBox(height: 10),
                        switch (line) {
                          _AssistantLine() => ChatIncomingBubble(
                            text: line.text,
                            actions: identical(line, lastAssistant) && !_busy
                                ? [
                                    for (final quick in line.quickReplies)
                                      _QuickReply(
                                        key: ValueKey('seaproof-quick-${quick.name}'),
                                        label: switch (quick) {
                                          _Quick.mark => strings.markOnScreen,
                                          _Quick.record => strings.recordScreen,
                                          _Quick.done => strings.closeChat,
                                        },
                                        icon: switch (quick) {
                                          _Quick.mark => Icons.photo_camera_outlined,
                                          _Quick.record => Icons.videocam_outlined,
                                          _Quick.done => null,
                                        },
                                        primary: quick == _Quick.done,
                                        onPressed: () => _onQuick(quick),
                                      ),
                                  ]
                                : const [],
                          ),
                          _YourText() => ChatOutgoingBubble(child: Text(line.text)),
                          _YourImage() => ChatImageBubble(
                            image: MemoryImage(line.png),
                            label: line.label,
                            onTap: _busy
                                ? null
                                : () {
                                    if (line.recording case final recording?) {
                                      _playRecording(recording);
                                    } else {
                                      unawaited(_startAnnotating(sentScreenshot: line.png));
                                    }
                                  },
                          ),
                        },
                      ],
                      if (_busy) ...[const SizedBox(height: 10), const ChatIncomingBubble(text: '…')],
                    ],
                  ),
                ),
                ConstrainedBox(
                  key: const ValueKey('seaproof-extras'),
                  constraints: BoxConstraints(maxHeight: constraints.maxHeight * _extrasShare),
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: extras),
                  ),
                ),
              ],
            ),
          ),
        ),
        _composer(),
      ],
    );
  }

  Widget _composer() {
    final strings = _strings;
    final hasEmail = _reporterEmail.isNotEmpty;
    final hint = _saved == null ? strings.descriptionHint : strings.addHint;
    final native = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    const descriptionKey = ValueKey('seaproof-description');

    return ChatComposer(
      key: const ValueKey('seaproof-composer'),
      editor: native
          ? KeyedSubtree(
              key: descriptionKey,
              child: IosComposer(
                key: _iosComposer,
                controller: _description,
                hint: hint,
                onImage: _pasteScreenshot,
                enabled: !_busy,
                onFocus: _emailFocus.unfocus,
              ),
            )
          : ChatTextField(
              fieldKey: descriptionKey,
              controller: _description,
              hint: hint,
              maxLength: 10000,
              autofocus: true,
              onSubmit: () => unawaited(_send()),
            ),
      details: _saved == null && _showEmail
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const ValueKey('seaproof-email'),
                    focusNode: _emailFocus,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(labelText: strings.emailLabel, isDense: true),
                    onChanged: (_) => setState(() => _emailEdited = true),
                  ),
                  if (!_controller.isTesterMode && hasEmail)
                    CheckboxListTile(
                      key: const ValueKey('seaproof-may-contact'),
                      value: _mayContact,
                      onChanged: (v) => setState(() => _mayContact = v ?? false),
                      title: Text(strings.mayContact),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            )
          : null,
      actions: [
        if (_screenshot != null)
          IconButton(
            key: const ValueKey('seaproof-mark'),
            icon: const Icon(Icons.photo_camera_outlined),
            tooltip: strings.markOnScreen,
            onPressed: _busy ? null : _startAnnotating,
          ),
        if (widget.onRecord != null)
          IconButton(
            key: const ValueKey('seaproof-record'),
            icon: const Icon(Icons.videocam_outlined),
            tooltip: strings.recordScreen,
            onPressed: _busy ? null : _record,
          ),
        if (_saved == null)
          IconButton(
            key: const ValueKey('seaproof-toggle-email'),
            isSelected: _showEmail || hasEmail,
            icon: Badge(isLabelVisible: hasEmail, child: const Icon(Icons.alternate_email)),
            tooltip: hasEmail ? strings.editEmail : strings.addEmail,
            onPressed: _busy ? null : _toggleEmail,
          ),
      ],
      send: IconButton.filled(
        key: const ValueKey('seaproof-send'),
        icon: const Icon(Icons.arrow_upward),
        tooltip: _busy ? strings.sending : strings.send,
        onPressed: _busy ? null : () => unawaited(_send()),
      ),
    );
  }
}

enum _Added { screenshot, recording }

/// Testers see which environment they report from.
class _TestStrip extends StatelessWidget {
  const _TestStrip({required this.label, required this.environment});

  final String label;
  final String? environment;

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const ValueKey('seaproof-test-strip'),
    color: SeaproofTokens.ink,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFFFF8A3D)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: Color(0xFFE8F0F5), fontSize: 12, fontWeight: FontWeight.w600),
          ),
          if (environment case final environment?) ...[
            const SizedBox(width: 8),
            Text(environment, style: const TextStyle(color: Color(0xFF9DB2C2), fontSize: 12)),
          ],
        ],
      ),
    ),
  );
}

class _QuickReply extends StatelessWidget {
  const _QuickReply({
    super.key,
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData? icon;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shape = const StadiumBorder();
    final child = Text(label);
    if (primary) {
      return FilledButton(
        style: FilledButton.styleFrom(shape: shape),
        onPressed: onPressed,
        child: child,
      );
    }
    return icon == null
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(shape: shape),
            onPressed: onPressed,
            child: child,
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(shape: shape),
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: child,
          );
  }
}

/// A segmented control: a sunken track with the selected tab raised on it.
class _Tabs extends StatelessWidget {
  const _Tabs({super.key, required this.tabs, required this.selected, required this.onSelected});

  final List<({_Tab value, Widget label})> tabs;
  final _Tab selected;
  final ValueChanged<_Tab>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Light: the selected tab is the panel's white on a grey track. Dark: lighter than the track.
    final dark = theme.brightness == Brightness.dark;
    final track = dark ? scheme.surfaceContainerLowest : scheme.surfaceContainerHighest;
    final raised = dark ? scheme.surfaceContainerHighest : scheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: Semantics(
                  selected: tab.value == selected,
                  child: Material(
                    color: tab.value == selected ? raised : Colors.transparent,
                    elevation: tab.value == selected ? 1 : 0,
                    borderRadius: BorderRadius.circular(9),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(9),
                      onTap: onSelected == null ? null : () => onSelected!(tab.value),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: DefaultTextStyle.merge(
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: tab.value == selected ? scheme.onSurface : scheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: tab.label,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The kinds of feedback as chips, each with its own colour and icon.
class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.types, required this.selected, required this.labels, required this.onSelected});

  final List<FeedbackType> types;
  final FeedbackType selected;
  final Map<FeedbackType, String> labels;
  final ValueChanged<FeedbackType>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in types)
          Builder(
            builder: (context) {
              final colors = SeaproofTokens.typeColors(type, theme.brightness);
              final isSelected = type == selected;
              return Semantics(
                selected: isSelected,
                inMutuallyExclusiveGroup: true,
                child: Material(
                  key: ValueKey('seaproof-type-${type.name}'),
                  color: isSelected ? colors.tint : theme.colorScheme.surface,
                  shape: StadiumBorder(
                    side: isSelected
                        ? BorderSide(color: colors.tone, width: 1.5)
                        : BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onSelected == null ? null : () => onSelected!(type),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(SeaproofTokens.typeIcon(type), size: 16, color: colors.tone),
                            const SizedBox(width: 6),
                            Text(
                              labels[type]!,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colors.tone,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.strings, required this.number, required this.onClose});

  final SeaproofStrings strings;
  final int? number;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
            child: const SeaproofMark(),
          ),
          const SizedBox(height: 20),
          Text(strings.thanks, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            strings.thanksDetail,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (number case final number?) ...[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text('#$number', style: theme.textTheme.labelLarge?.copyWith(fontFamily: 'monospace')),
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextButton(onPressed: onClose, child: Text(strings.close)),
        ],
      ),
    );
  }
}
