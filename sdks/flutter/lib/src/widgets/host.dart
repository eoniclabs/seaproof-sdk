import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../config.dart';
import '../controller.dart';
import '../design.dart';
import '../screen_recorder.dart';
import '../shake_detector.dart';
import '../strings.dart';
import '../theme.dart';
import 'feedback_panel.dart';
import 'floater.dart';
import 'mask.dart';

/// Hosts Seaproof in the app: takes screenshots, listens for the triggers and shows the panel.
///
/// Put it in `MaterialApp.builder`, so it sits inside the app's theme and localizations:
///
/// ```dart
/// MaterialApp(builder: (context, child) => SeaproofHost(child: child!), ...)
/// ```
class SeaproofHost extends StatefulWidget {
  /// Hosts [child].
  const SeaproofHost({
    super.key,
    required this.child,
    this.controller,
    this.strings,
    this.theme,
    @visibleForTesting this.shakeSamples,
  });

  /// The app.
  final Widget child;

  /// The SDK state, or [Seaproof.instance] when null.
  final SeaproofController? controller;

  /// The SDK's texts. Built-in English or Swedish, from the app's locale, when null.
  final SeaproofStrings? strings;

  /// The look of the floating button and panel. Follows the app's theme when null; see
  /// [SeaproofTheme] for setting it through `ThemeData.extensions` instead.
  final SeaproofTheme? theme;

  /// Replaces the accelerometer, for tests.
  final Stream<(double, double, double)>? shakeSamples;

  @override
  State<SeaproofHost> createState() => _SeaproofHostState();
}

class _SeaproofHostState extends State<SeaproofHost> {
  final GlobalKey _boundaryKey = GlobalKey();
  final MaskRegistry _masks = MaskRegistry();
  late SeaproofController _controller;
  StreamSubscription<ShowRequest>? _requests;
  ShakeDetector? _shake;
  bool _keyboardHandlerAdded = false;
  ({ShowRequest request, Uint8List? screenshot})? _open;
  bool _opening = false;
  ScreenRecorder? _recorder;
  Timer? _recordingTicker;
  SeaproofRecording? _recording;

  @override
  void initState() {
    super.initState();
    _attach(widget.controller ?? Seaproof.instance);
  }

  @override
  void didUpdateWidget(SeaproofHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controller = widget.controller ?? Seaproof.instance;
    if (controller != _controller) {
      _detach();
      _attach(controller);
    }
  }

  @override
  void dispose() {
    _recordingTicker?.cancel();
    unawaited(_recorder?.stop());
    _detach();
    super.dispose();
  }

  void _attach(SeaproofController controller) {
    _controller = controller;
    _requests = controller.showRequests.listen(_onShowRequest);
    controller.addListener(_onControllerChanged);
    _syncTriggers();
  }

  void _detach() {
    unawaited(_requests?.cancel());
    _controller.removeListener(_onControllerChanged);
    unawaited(_shake?.dispose());
    _shake = null;
    if (_keyboardHandlerAdded) {
      HardwareKeyboard.instance.removeHandler(_onKey);
      _keyboardHandlerAdded = false;
    }
  }

  void _onControllerChanged() {
    // The environment may have arrived, which can change the triggers.
    _syncTriggers();
    if (mounted) {
      setState(() {});
    }
  }

  void _syncTriggers() {
    final triggers = _controller.triggers;
    final wantShake = triggers.contains(SeaproofTrigger.shake) && (widget.shakeSamples != null || isMobilePlatform);
    if (wantShake && _shake == null) {
      _shake = ShakeDetector(
        samples:
            widget.shakeSamples ??
            userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).map((e) => (e.x, e.y, e.z)),
        onShake: () => _controller.show(),
      );
    } else if (!wantShake && _shake != null) {
      unawaited(_shake!.dispose());
      _shake = null;
    }

    final wantKeyboard = triggers.contains(SeaproofTrigger.keyboardShortcut);
    if (wantKeyboard && !_keyboardHandlerAdded) {
      HardwareKeyboard.instance.addHandler(_onKey);
      _keyboardHandlerAdded = true;
    } else if (!wantKeyboard && _keyboardHandlerAdded) {
      HardwareKeyboard.instance.removeHandler(_onKey);
      _keyboardHandlerAdded = false;
    }
  }

  bool _onKey(KeyEvent event) {
    final shortcut = _controller.config.shortcut ?? defaultShortcut();
    if (event is KeyDownEvent && shortcut.accepts(event, HardwareKeyboard.instance)) {
      _controller.show();
      return true;
    }

    return false;
  }

  Future<void> _onShowRequest(ShowRequest request) async {
    if (_open != null || _opening) {
      return;
    }

    _opening = true;
    try {
      final screenshot = await _capture();
      if (mounted) {
        setState(() => _open = (request: request, screenshot: screenshot));
      }
    } finally {
      _opening = false;
    }
  }

  // The panel stays mounted but hidden while recording, so what the user typed is kept.
  void _startRecording() {
    final recorder = ScreenRecorder(
      // Small frames: the steps matter more than sharpness, and they keep the upload small.
      capture: () => _capture(maxWidth: 480),
      maxDuration: _controller.config.maxRecordingDuration,
      onStop: _onRecordingStopped,
    );
    setState(() {
      _recorder = recorder;
      _recording = null;
    });
    // Let the panel disappear before the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => recorder.start());
    _recordingTicker = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() {}));
  }

  Future<void> _stopRecording() async => _onRecordingStopped(await _recorder?.stop());

  void _onRecordingStopped(SeaproofRecording? recording) {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    if (recording == null) {
      debugPrint('Seaproof: the screen recording has no frames.');
    }

    if (mounted) {
      setState(() {
        _recorder = null;
        _recording = recording;
      });
    }
  }

  /// The app as it looks now, with masked areas blacked out, as PNG. Null if it fails.
  /// [maxWidth] limits the width in pixels.
  Future<Uint8List?> _capture({double? maxWidth}) async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary || !boundary.hasSize) {
        return null;
      }

      // Enough for a sharp image without huge uploads from 3x phones and 4K monitors.
      final view = View.of(context);
      final fullRatio = view.devicePixelRatio.clamp(1.0, 2.0);
      final pixelRatio = maxWidth == null ? fullRatio : (maxWidth / boundary.size.width).clamp(0.1, fullRatio);
      final masks = _masks.rectsIn(boundary);
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final ui.Image result;
      if (masks.isEmpty) {
        result = image;
      } else {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)..drawImage(image, Offset.zero, Paint());
        final black = Paint()..color = const Color(0xFF000000);
        for (final rect in masks) {
          canvas.drawRect(
            Rect.fromLTRB(
              rect.left * pixelRatio,
              rect.top * pixelRatio,
              rect.right * pixelRatio,
              rect.bottom * pixelRatio,
            ),
            black,
          );
        }

        final picture = recorder.endRecording();
        result = await picture.toImage(image.width, image.height);
        picture.dispose();
        image.dispose();
      }

      final bytes = await result.toByteData(format: ui.ImageByteFormat.png);
      result.dispose();
      return bytes?.buffer.asUint8List();
    } on Object catch (e) {
      debugPrint('Seaproof: could not take a screenshot ($e).');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings =
        widget.strings ?? SeaproofStrings.forLocale(_controller.config.locale ?? Localizations.maybeLocaleOf(context));
    final open = _open;
    final theme = SeaproofTheme.of(context, widget.theme, _controller.brandingTheme);
    final themeData = theme.applyTo(Theme.of(context));

    return MaskScope(
      registry: _masks,
      child: _HostOverlay(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(key: _boundaryKey, child: widget.child),
            if (open == null && _controller.triggers.contains(SeaproofTrigger.floatingButton))
              SeaproofFloater(
                onPressed: _controller.show,
                tooltip: strings.openFeedback,
                themeData: themeData,
                size: theme.floatingButtonSize ?? SeaproofTheme.defaultFloatingButtonSize,
                icon: theme.floatingButtonIcon ?? Icons.chat_bubble_outline,
              ),
            if (open != null)
              Positioned.fill(
                child: Offstage(
                  offstage: _recorder != null,
                  child: Theme(
                    data: themeData,
                    child: FeedbackPanel(
                      controller: _controller,
                      strings: strings,
                      theme: theme,
                      request: open.request,
                      screenshot: open.screenshot,
                      recording: _recording,
                      onRecord: _controller.allowScreenRecording ? _startRecording : null,
                      onRemoveRecording: () => setState(() => _recording = null),
                      onClose: () => setState(() {
                        _open = null;
                        _recording = null;
                      }),
                    ),
                  ),
                ),
              ),
            if (_recorder case final recorder?)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Center(
                    child: Theme(
                      data: themeData,
                      child: _RecordingBar(strings: strings, elapsed: recorder.elapsed, onStop: _stopRecording),
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

/// Shown while recording, so the user can stop.
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.strings, required this.elapsed, required this.onStop});

  final SeaproofStrings strings;
  final Duration elapsed;
  final VoidCallback onStop;

  // Dark whatever the app's theme, so it stands out on any screen.
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Material(
      elevation: 6,
      shape: const StadiumBorder(),
      color: SeaproofTokens.ink,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _PulsingDot(),
              const SizedBox(width: 10),
              Text('${strings.recordingNow} ${SeaproofStrings.formatDuration(elapsed)}'),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const ValueKey('seaproof-stop-recording'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFB42318),
                  shape: const StadiumBorder(),
                  minimumSize: const Size(64, 36),
                ),
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded, size: 18),
                label: Text(strings.stopRecording),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The recording dot. Pulses, unless the platform asks for less motion.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      unawaited(_pulse.repeat(reverse: true));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 1, end: 0.35).animate(_pulse),
    child: const DecoratedBox(
      decoration: BoxDecoration(color: SeaproofTokens.recording, shape: BoxShape.circle),
      child: SizedBox.square(dimension: 10),
    ),
  );
}

/// Gives the floating button and panel an [Overlay], which tooltips and text fields need.
/// The host sits above the app's navigator, so the app's own overlay is not an ancestor.
class _HostOverlay extends StatefulWidget {
  const _HostOverlay({required this.child});

  final Widget child;

  @override
  State<_HostOverlay> createState() => _HostOverlayState();
}

class _HostOverlayState extends State<_HostOverlay> {
  late final OverlayEntry _entry = OverlayEntry(builder: (_) => widget.child);

  @override
  void didUpdateWidget(_HostOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
