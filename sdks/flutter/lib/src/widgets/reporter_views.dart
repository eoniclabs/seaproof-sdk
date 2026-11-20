import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controller.dart';
import '../design.dart';
import '../models.dart';
import '../screen_recorder.dart';
import '../strings.dart';
import 'annotator.dart';
import 'chat.dart';
import 'ios_composer.dart';

/// The user's own feedback, and the conversation with the team about one item.
class OwnFeedbackView extends StatefulWidget {
  /// Creates the view.
  const OwnFeedbackView({
    super.key,
    required this.controller,
    required this.strings,
    required this.items,
    required this.onRead,
    this.screenshot,
    this.recording,
    this.onRecord,
    this.onRemoveRecording,
    this.annotationColor,
  });

  /// The SDK state.
  final SeaproofController controller;

  /// Texts.
  final SeaproofStrings strings;

  /// The user's items, newest first.
  final List<OwnFeedback> items;

  /// Called after an item's replies were read, so unread markers can update.
  final VoidCallback onRead;

  /// The masked screenshot captured when the feedback panel opened.
  final Uint8List? screenshot;

  /// A newly captured recording waiting to be sent to this item.
  final SeaproofRecording? recording;

  /// Starts recording the app, if available to the reporter.
  final VoidCallback? onRecord;

  /// Clears the newly captured recording.
  final VoidCallback? onRemoveRecording;

  /// Brand color for screenshot annotations.
  final Color? annotationColor;

  @override
  State<OwnFeedbackView> createState() => _OwnFeedbackViewState();
}

class _OwnFeedbackViewState extends State<OwnFeedbackView> {
  final TextEditingController _reply = TextEditingController();
  final ScrollController _history = ScrollController();
  final GlobalKey<IosComposerState> _iosComposer = GlobalKey();
  final List<FeedbackAttachment> _draft = [];
  ui.Image? _photo;
  ImageProvider<Object>? _playing;
  bool _openingAttachment = false;
  OwnFeedback? _open;
  OwnFeedbackDetail? _detail;
  String? _attachmentRetryMessageId;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  SeaproofStrings get _strings => widget.strings;

  @override
  void dispose() {
    _reply.dispose();
    _history.dispose();
    _photo?.dispose();
    super.dispose();
  }

  Future<void> _openItem(OwnFeedback item) async {
    _reply.clear();
    _draft.clear();
    setState(() {
      _open = item;
      _detail = null;
      _attachmentRetryMessageId = null;
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.controller.myFeedbackItem(item.id);
      if (!mounted || _open != item) {
        return;
      }

      setState(() => _detail = detail);
      widget.onRead();
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not load feedback ${item.id} ($e).');
      if (mounted && _open == item) {
        setState(() => _error = _strings.loadFailed);
      }
    } finally {
      if (mounted && _open == item) {
        setState(() => _loading = false);
      }
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
    unawaited(_iosComposer.currentState?.dismissKeyboard());
  }

  FeedbackAttachment _screenshot(Uint8List bytes, {bool marked = false}) => FeedbackAttachment(
    kind: AttachmentKind.screenshot,
    fileName: marked ? 'screenshot-marked.png' : 'screenshot.png',
    contentType: 'image/png',
    bytes: bytes,
  );

  void _paste(Uint8List? bytes) {
    if (_sending) return;
    setState(() {
      if (bytes == null) {
        _error = _strings.pasteScreenshotFailed;
      } else {
        _error = null;
        _draft.add(_screenshot(bytes));
      }
    });
  }

  void _closeImage() {
    final photo = _photo;
    setState(() {
      _photo = null;
      _playing = null;
      _editingDraft = null;
    });
    if (photo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => photo.dispose());
    }
  }

  FeedbackAttachment? _editingDraft;

  Future<void> _openScreenshot(ImageProvider<Object> source, {FeedbackAttachment? draft}) async {
    if (_sending || _openingAttachment) return;
    _dismissKeyboard();
    final item = _open;
    setState(() {
      _openingAttachment = true;
      _error = null;
    });
    final stream = source.resolve(createLocalImageConfiguration(context));
    final loaded = Completer<ui.Image>();
    final listener = ImageStreamListener(
      (info, _) {
        if (!loaded.isCompleted) loaded.complete(info.image.clone());
        info.dispose();
      },
      onError: (error, stack) {
        if (!loaded.isCompleted) loaded.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    try {
      final photo = await loaded.future;
      if (!mounted || _open != item) {
        photo.dispose();
        return;
      }
      setState(() {
        _photo = photo;
        _editingDraft = draft;
      });
    } on Object {
      if (mounted && _open == item) setState(() => _error = _strings.loadFailed);
    } finally {
      stream.removeListener(listener);
      if (mounted) setState(() => _openingAttachment = false);
    }
  }

  void _applyScreenshot(Uint8List bytes, int _) {
    final original = _editingDraft;
    final marked = _screenshot(bytes, marked: true);
    setState(() {
      final index = original == null ? -1 : _draft.indexOf(original);
      if (index < 0) {
        _draft.add(marked);
      } else {
        _draft[index] = marked;
      }
    });
    _closeImage();
  }

  void _playRecording(ImageProvider<Object> source) {
    _dismissKeyboard();
    setState(() => _playing = source);
  }

  Future<void> _send() async {
    final body = _reply.text.trim();
    final detail = _detail;
    final recording = widget.recording?.toAttachment();
    final files = [..._draft, ?recording];
    if (_sending || _openingAttachment || detail == null || (body.isEmpty && files.isEmpty)) return;

    _dismissKeyboard();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      var messageId = _attachmentRetryMessageId;
      if (body.isNotEmpty) {
        final message = await widget.controller.sendMessage(detail.id, body);
        if (!mounted) return;
        messageId = message.id;
        _reply.clear();
        setState(() => _detail = detail.withMessage(message));
      }
      if (files.isNotEmpty) {
        _attachmentRetryMessageId = messageId;
        final failed = await widget.controller.addAttachments(detail.id, files, messageId: messageId);
        if (!mounted) return;
        setState(() {
          _draft.removeWhere((file) => files.contains(file) && !failed.contains(file));
          if (failed.isNotEmpty) _error = _strings.addFailed;
          if (failed.isEmpty) _attachmentRetryMessageId = null;
        });
        if (recording != null && !failed.contains(recording)) widget.onRemoveRecording?.call();

        if (failed.length < files.length) {
          final updated = await widget.controller.myFeedbackItem(detail.id);
          if (!mounted) return;
          setState(() => _detail = updated);
          widget.onRead();
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_history.hasClients) {
          unawaited(
            _history.animateTo(
              _history.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: SeaproofTokens.tide,
            ),
          );
        }
      });
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not send the answer ($e).');
      if (mounted) setState(() => _error = _strings.failed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_photo case final photo?) {
      return ScreenshotAnnotator(
        image: photo,
        strings: _strings,
        hideFirst: !widget.controller.isTesterMode,
        penColor: widget.annotationColor ?? ScreenshotAnnotator.defaultPenColor,
        onDone: _applyScreenshot,
        onCancel: _closeImage,
      );
    }
    if (_playing case final recording?) {
      return ChatRecordingViewer(
        image: recording,
        title: _strings.screenRecording,
        back: _strings.back,
        loadFailed: _strings.loadFailed,
        onClose: _closeImage,
      );
    }
    return _open == null ? _list(context) : _conversation(context);
  }

  Widget _list(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final item in widget.items)
          ListTile(
            key: ValueKey('seaproof-own-${item.id}'),
            title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [
                '#${item.number}',
                _strings.statusLabels[item.status]!,
                if (item.replies > 0) _strings.replies(item.replies),
              ].join(' · '),
            ),
            trailing: widget.controller.hasUnreadReply(item)
                ? Semantics(
                    label: _strings.newReply,
                    child: const Icon(Icons.circle, size: 10, color: SeaproofTokens.signal),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => _openItem(item),
          ),
      ],
    );
  }

  Widget _conversation(BuildContext context) {
    final theme = Theme.of(context);
    final item = _open!;
    final detail = _detail;
    final attachments = detail?.attachments ?? const <ReporterAttachment>[];
    final original = attachments.where((file) => file.messageId == null && file.createdAt == item.createdAt);
    final canAttach = !_sending && !_openingAttachment;
    final entries = [
      for (final message in detail?.messages ?? const <ConversationMessage>[])
        (
          time: message.createdAt,
          child: message.fromTeam
              ? ChatIncomingBubble(text: message.body, icon: Icons.forum_outlined)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final file in attachments.where((file) => file.messageId == message.id))
                      Padding(padding: const EdgeInsets.only(bottom: 6), child: _sentAttachment(file, canAttach)),
                    ChatOutgoingBubble(child: Text(message.body)),
                  ],
                ),
        ),
      for (final file in attachments.where((file) => file.messageId == null && file.createdAt != item.createdAt))
        (time: file.createdAt, child: _sentAttachment(file, canAttach)),
      for (final update in detail?.statusUpdates ?? const <ReporterStatusUpdate>[])
        (
          time: update.createdAt,
          child: ChatIncomingBubble(text: _strings.statusUpdate(update.status), icon: Icons.info_outline),
        ),
    ]..sort((left, right) => left.time.compareTo(right.time));
    final native = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    const replyKey = ValueKey('seaproof-reply');
    final recorded = widget.recording;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: const BackButtonIcon(),
                tooltip: _strings.back,
                onPressed: _sending || _openingAttachment
                    ? null
                    : () {
                        _dismissKeyboard();
                        if (recorded != null) widget.onRemoveRecording?.call();
                        setState(() => _open = null);
                      },
              ),
              Expanded(child: Text(item.title, style: theme.textTheme.titleMedium, maxLines: 2)),
              StatusBadge(
                status: detail?.status ?? item.status,
                label: _strings.statusLabels[detail?.status ?? item.status]!,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ChatHistory(
            key: const ValueKey('seaproof-own-conversation'),
            controller: _history,
            children: [
              if (_loading)
                const Center(
                  child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                ),
              if (detail != null) ...[
                if (original.isNotEmpty) ...[
                  Text(_strings.attachments, style: theme.textTheme.titleSmall),
                  for (final file in original)
                    Padding(padding: const EdgeInsets.only(top: 6), child: _sentAttachment(file, canAttach)),
                  const SizedBox(height: 12),
                ],
                ChatOutgoingBubble(child: Text(detail.description)),
                for (final entry in entries) ...[const SizedBox(height: 10), entry.child],
              ],
              if (_error case final error?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error, style: TextStyle(color: theme.colorScheme.error)),
                ),
            ],
          ),
        ),
        if (_draft.isNotEmpty || recorded != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 115),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                children: [
                  for (final photo in _draft)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: ChatAttachmentRow(
                        key: const ValueKey('seaproof-reply-draft-screenshot'),
                        preview: _thumbnail(MemoryImage(photo.bytes)),
                        title: _strings.screenshotLabel,
                        onTap: canAttach ? () => _openScreenshot(MemoryImage(photo.bytes), draft: photo) : null,
                        removeTooltip: _strings.removeScreenshot,
                        onRemove: canAttach
                            ? () => setState(() {
                                _draft.remove(photo);
                                if (_draft.isEmpty && recorded == null) _attachmentRetryMessageId = null;
                              })
                            : null,
                      ),
                    ),
                  if (recorded != null)
                    ChatAttachmentRow(
                      preview: _thumbnail(MemoryImage(recorded.firstFrame)),
                      title: _strings.recordingLabel(recorded.duration),
                      leadingAction: Icons.play_arrow_outlined,
                      onTap: canAttach ? () => _playRecording(MemoryImage(recorded.apng)) : null,
                      removeTooltip: _strings.removeRecording,
                      onRemove: canAttach && widget.onRemoveRecording != null
                          ? () {
                              if (_draft.isEmpty) _attachmentRetryMessageId = null;
                              widget.onRemoveRecording!();
                            }
                          : null,
                    ),
                ],
              ),
            ),
          ),
        if (detail != null)
          ChatComposer(
            editor: native
                ? KeyedSubtree(
                    key: replyKey,
                    child: IosComposer(
                      key: _iosComposer,
                      controller: _reply,
                      hint: _strings.reply,
                      maxLength: 5000,
                      onImage: _paste,
                      enabled: !_sending,
                    ),
                  )
                : ChatTextField(
                    fieldKey: replyKey,
                    controller: _reply,
                    enabled: !_sending,
                    hint: _strings.reply,
                    maxLength: 5000,
                    onSubmit: () => unawaited(_send()),
                  ),
            actions: [
              if (widget.screenshot case final capture?)
                IconButton(
                  key: const ValueKey('seaproof-reply-screenshot'),
                  tooltip: _strings.includeScreenshot,
                  icon: const Icon(Icons.photo_camera_outlined),
                  onPressed: canAttach
                      ? () => setState(() {
                          if (!_draft.any((file) => identical(file.bytes, capture))) _draft.add(_screenshot(capture));
                        })
                      : null,
                ),
              if (widget.onRecord case final onRecord?)
                IconButton(
                  key: const ValueKey('seaproof-reply-record'),
                  tooltip: _strings.recordScreen,
                  icon: const Icon(Icons.videocam_outlined),
                  onPressed: canAttach
                      ? () {
                          _dismissKeyboard();
                          onRecord();
                        }
                      : null,
                ),
            ],
            send: IconButton.filled(
              key: const ValueKey('seaproof-reply-send'),
              tooltip: _sending ? _strings.sending : _strings.send,
              icon: const Icon(Icons.arrow_upward),
              onPressed: canAttach ? _send : null,
            ),
          ),
      ],
    );
  }

  Widget _sentAttachment(ReporterAttachment file, bool enabled) {
    final source = NetworkImage(file.url.toString());
    final recording = file.kind == AttachmentKind.recording;
    return ChatAttachmentRow(
      key: ValueKey('seaproof-attachment-${file.id}'),
      preview: recording
          ? const SizedBox(width: 56, height: 40, child: Icon(Icons.video_file_outlined))
          : _thumbnail(source),
      title: recording ? _strings.screenRecording : _strings.screenshotLabel,
      leadingAction: recording ? Icons.play_arrow_outlined : Icons.edit_outlined,
      onTap: !enabled
          ? null
          : () {
              if (recording) {
                _playRecording(source);
              } else {
                unawaited(_openScreenshot(source));
              }
            },
    );
  }

  Widget _thumbnail(ImageProvider<Object> source) => Image(
    image: source,
    width: 56,
    height: 40,
    fit: BoxFit.cover,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 40, child: Icon(Icons.broken_image_outlined)),
  );
}

/// A public status as a small pill, coloured for the statuses that mean progress.
class StatusBadge extends StatelessWidget {
  /// Creates the badge.
  const StatusBadge({super.key, required this.status, required this.label});

  /// The status.
  final PublicStatus status;

  /// Its text.
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = SeaproofTokens.statusColors(status, theme.brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors?.tint ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors?.tone ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// The ideas the team published, where the user votes.
class IdeasView extends StatefulWidget {
  /// Creates the view.
  const IdeasView({
    super.key,
    required this.controller,
    required this.strings,
    required this.ideas,
    required this.onSuggest,
  });

  /// The SDK state.
  final SeaproofController controller;

  /// Texts.
  final SeaproofStrings strings;

  /// The published ideas, most voted first.
  final List<PublicIdea> ideas;

  /// Opens the form to suggest a new idea.
  final VoidCallback onSuggest;

  @override
  State<IdeasView> createState() => _IdeasViewState();
}

class _IdeasViewState extends State<IdeasView> {
  late List<PublicIdea> _ideas = widget.ideas;
  final Set<String> _pending = {};

  @override
  void didUpdateWidget(IdeasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.ideas, widget.ideas)) {
      _ideas = widget.ideas;
    }
  }

  void _replace(PublicIdea idea) => _ideas = [for (final i in _ideas) i.id == idea.id ? idea : i];

  // Optimistic: the count changes at once and is restored if the API refuses.
  Future<void> _toggle(PublicIdea idea) async {
    final value = !idea.voted;
    setState(() {
      _pending.add(idea.id);
      _replace(idea.withVote(value: value));
    });
    try {
      await (value ? widget.controller.vote(idea.id) : widget.controller.unvote(idea.id));
    } on SeaproofException catch (e) {
      debugPrint('Seaproof: could not change the vote ($e).');
      if (mounted) {
        setState(() => _replace(idea));
      }
    } finally {
      if (mounted) {
        setState(() => _pending.remove(idea.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = widget.strings;
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        for (final idea in _ideas)
          Padding(
            key: ValueKey('seaproof-idea-${idea.id}'),
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _VoteButton(
                  idea: idea,
                  label: strings.voteLabel(idea),
                  onPressed: _pending.contains(idea.id) ? null : () => _toggle(idea),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(idea.title, style: theme.textTheme.titleSmall),
                      if (idea.summary case final summary? when summary.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(summary, style: theme.textTheme.bodyMedium),
                      ],
                      if (idea.status != PublicStatus.received) ...[
                        const SizedBox(height: 6),
                        StatusBadge(status: idea.status, label: strings.statusLabels[idea.status]!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        OutlinedButton.icon(
          onPressed: widget.onSuggest,
          icon: Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: SeaproofTokens.typeColors(FeedbackType.idea, theme.brightness).tone,
          ),
          label: Text(strings.suggestIdea),
        ),
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({required this.idea, required this.label, required this.onPressed});

  final PublicIdea idea;
  final String label;
  final VoidCallback? onPressed;

  static final _style = ButtonStyle(
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
    minimumSize: const WidgetStatePropertyAll(Size(48, 56)),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );

  @override
  Widget build(BuildContext context) {
    // The button reads as "Vote for X, 4 votes" rather than "4".
    final child = Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [const Icon(Icons.keyboard_arrow_up, size: 20), Text('${idea.votes}')],
        ),
      ),
    );
    return idea.voted
        ? FilledButton(onPressed: onPressed, style: _style, child: child)
        : OutlinedButton(onPressed: onPressed, style: _style, child: child);
  }
}
