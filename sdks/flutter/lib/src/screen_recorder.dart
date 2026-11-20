import 'dart:async';

import 'package:flutter/foundation.dart';

import 'apng.dart';
import 'models.dart';

/// A finished recording of the app: an animated PNG that plays in the Seaproof inbox.
@immutable
final class SeaproofRecording {
  /// Creates a recording.
  const SeaproofRecording({required this.apng, required this.duration, required this.firstFrame});

  /// The animation, as `image/apng`.
  final Uint8List apng;

  /// How long it ran.
  final Duration duration;

  /// The first frame as PNG, for a preview.
  final Uint8List firstFrame;

  /// The file sent with a report or follow-up.
  FeedbackAttachment toAttachment() => FeedbackAttachment(
    kind: AttachmentKind.recording,
    fileName: 'recording.png',
    contentType: 'image/apng',
    bytes: apng,
  );
}

/// Records the app by capturing frames, with the same masking as screenshots.
///
/// A video of the device screen would need a native plugin per platform and would show
/// everything, including other apps and [SeaproofMask]ed content. Frames of the app itself
/// work on every platform and respect the masks; a few frames per second shows the steps
/// that led to a bug well enough.
final class ScreenRecorder {
  /// Creates a recorder that calls [capture] for each frame.
  ScreenRecorder({
    required this.capture,
    this.framesPerSecond = 2,
    this.maxDuration = const Duration(seconds: 30),
    this.onStop,
    @visibleForTesting DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Takes one frame as PNG, or null if it fails.
  final Future<Uint8List?> Function() capture;

  /// Frames per second.
  final int framesPerSecond;

  /// Stops by itself after this long.
  final Duration maxDuration;

  /// Called when the recording stops on its own at [maxDuration].
  final void Function(SeaproofRecording?)? onStop;

  final DateTime Function() _clock;
  final List<({Uint8List png, DateTime at})> _frames = [];
  Timer? _timer;
  DateTime? _startedAt;
  bool _capturing = false;

  /// Whether frames are being taken.
  bool get isRecording => _timer != null;

  /// How long the current recording has run.
  Duration get elapsed => _startedAt == null ? Duration.zero : _clock().difference(_startedAt!);

  /// Starts taking frames.
  void start() {
    if (isRecording) {
      return;
    }

    _frames.clear();
    _startedAt = _clock();
    unawaited(_tick());
    _timer = Timer.periodic(Duration(milliseconds: 1000 ~/ framesPerSecond), (_) => _tick());
  }

  /// Stops and returns the recording, or null if no frame could be taken.
  Future<SeaproofRecording?> stop() async {
    if (!isRecording) {
      return null;
    }

    _timer?.cancel();
    _timer = null;
    // The frame being captured, if any, is still wanted.
    while (_capturing) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final end = _clock();
    final duration = end.difference(_startedAt!);
    final frames = <ApngFrame>[];
    for (var i = 0; i < _frames.length; i++) {
      final next = i + 1 < _frames.length ? _frames[i + 1].at : end;
      frames.add((png: _frames[i].png, duration: next.difference(_frames[i].at)));
    }

    _frames.clear();
    _startedAt = null;
    if (frames.isEmpty) {
      return null;
    }

    return SeaproofRecording(apng: encodeApng(frames), duration: duration, firstFrame: frames.first.png);
  }

  Future<void> _tick() async {
    if (_capturing) {
      return;
    }

    if (elapsed >= maxDuration) {
      final recording = await stop();
      onStop?.call(recording);
      return;
    }

    _capturing = true;
    try {
      final at = _clock();
      final png = await capture();
      if (png == null) {
        return;
      }

      // A still screen gives identical frames; showing the previous one longer is much smaller.
      // A frame of another size (the window was resized or rotated) cannot join the animation.
      if (_frames.isNotEmpty && (listEquals(_frames.last.png, png) || !_sameSize(_frames.first.png, png))) {
        return;
      }

      _frames.add((png: png, at: at));
    } finally {
      _capturing = false;
    }
  }

  // Width and height are bytes 16-23 of a PNG.
  static bool _sameSize(Uint8List a, Uint8List b) {
    for (var i = 16; i < 24; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }

    return true;
  }
}
