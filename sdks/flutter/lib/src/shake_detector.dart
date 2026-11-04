import 'dart:async';
import 'dart:math' as math;

/// Detects a deliberate shake from linear acceleration (gravity removed), in m/s².
///
/// A shake is [requiredPeaks] readings above [threshold] within [window]. After a shake,
/// readings are ignored for [cooldown], so one shake opens the panel once.
final class ShakeDetector {
  /// Creates a detector over a stream of (x, y, z) samples.
  ShakeDetector({
    required Stream<(double, double, double)> samples,
    required void Function() onShake,
    this.threshold = 15,
    this.requiredPeaks = 3,
    this.window = const Duration(milliseconds: 1000),
    this.cooldown = const Duration(seconds: 2),
    DateTime Function()? now,
  }) : _onShake = onShake,
       _now = now ?? DateTime.now {
    _subscription = samples.listen(_onSample, onError: (Object _) {});
  }

  /// Acceleration a sample must exceed to count as a peak, in m/s².
  final double threshold;

  /// Peaks needed within [window].
  final int requiredPeaks;

  /// Time in which the peaks must happen.
  final Duration window;

  /// Quiet period after a detected shake.
  final Duration cooldown;

  final void Function() _onShake;
  final DateTime Function() _now;
  final List<DateTime> _peaks = [];
  late final StreamSubscription<(double, double, double)> _subscription;
  DateTime? _lastShake;

  void _onSample((double, double, double) sample) {
    final (x, y, z) = sample;
    if (math.sqrt(x * x + y * y + z * z) < threshold) {
      return;
    }

    final now = _now();
    if (_lastShake != null && now.difference(_lastShake!) < cooldown) {
      return;
    }

    _peaks
      ..add(now)
      ..removeWhere((t) => now.difference(t) > window);
    if (_peaks.length >= requiredPeaks) {
      _peaks.clear();
      _lastShake = now;
      _onShake();
    }
  }

  /// Stops listening.
  Future<void> dispose() => _subscription.cancel();
}
