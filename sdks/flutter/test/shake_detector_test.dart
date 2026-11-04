import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:seaproof/src/shake_detector.dart';

void main() {
  test('three strong peaks within a second are one shake, then it cools down', () async {
    final samples = StreamController<(double, double, double)>();
    var now = DateTime(2026);
    var shakes = 0;
    final detector = ShakeDetector(samples: samples.stream, onShake: () => shakes++, now: () => now);

    Future<void> sample(double x, {int afterMs = 100}) async {
      now = now.add(Duration(milliseconds: afterMs));
      samples.add((x, 0, 0));
      await Future<void>.delayed(Duration.zero);
    }

    await sample(20);
    await sample(1); // walking around is not a shake
    await sample(-18);
    expect(shakes, 0);
    await sample(19);
    expect(shakes, 1);

    await sample(20);
    await sample(20);
    await sample(20);
    expect(shakes, 1, reason: 'cooldown');

    await sample(20, afterMs: 2500);
    await sample(20, afterMs: 600);
    await sample(20, afterMs: 600);
    expect(shakes, 1, reason: 'peaks too far apart');

    await detector.dispose();
    await samples.close();
  });
}
