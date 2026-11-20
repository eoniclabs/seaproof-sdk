import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seaproof/src/apng.dart';
import 'package:seaproof/src/screen_recorder.dart';

Future<Uint8List> _png(Color color, {int width = 8, int height = 6}) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = color);
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

List<(String, Uint8List)> _chunks(Uint8List png) {
  final data = ByteData.sublistView(png);
  final chunks = <(String, Uint8List)>[];
  for (var offset = 8; offset < png.length;) {
    final length = data.getUint32(offset);
    chunks.add((
      String.fromCharCodes(png, offset + 4, offset + 8),
      Uint8List.sublistView(png, offset + 8, offset + 8 + length),
    ));
    offset += 12 + length;
  }

  return chunks;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('frames become one animated PNG that still opens as a PNG', (tester) async {
    await tester.runAsync(() async {
      final frames = [
        (png: await _png(const Color(0xFFFF0000)), duration: const Duration(milliseconds: 500)),
        (png: await _png(const Color(0xFF00FF00)), duration: const Duration(seconds: 2)),
        (png: await _png(const Color(0xFF0000FF)), duration: const Duration(milliseconds: 500)),
      ];

      final apng = encodeApng(frames);
      final chunks = _chunks(apng);

      expect(chunks.map((c) => c.$1).toSet(), {'IHDR', 'acTL', 'fcTL', 'IDAT', 'fdAT', 'IEND'});
      expect(chunks[1].$1, 'acTL');
      expect(ByteData.sublistView(chunks[1].$2).getUint32(0), 3, reason: 'three frames');
      final controls = chunks.where((c) => c.$1 == 'fcTL').map((c) => ByteData.sublistView(c.$2)).toList();
      expect(controls.map((c) => c.getUint16(20)), [500, 2000, 500]);
      expect(controls.map((c) => c.getUint32(4)), [8, 8, 8], reason: 'width');
      // Sequence numbers run across fcTL and fdAT without gaps.
      final sequences = [
        for (final c in chunks)
          if (c.$1 == 'fcTL' || c.$1 == 'fdAT') ByteData.sublistView(c.$2).getUint32(0),
      ];
      expect(sequences, List.generate(sequences.length, (i) => i));

      final codec = await ui.instantiateImageCodec(apng);
      expect(codec.frameCount, 3, reason: 'the recording viewer can play every frame');
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 8);
      frame.image.dispose();
      codec.dispose();
    });
  });

  testWidgets('frames of another size are refused', (tester) async {
    await tester.runAsync(() async {
      final small = await _png(const Color(0xFFFF0000));
      final large = await _png(const Color(0xFFFF0000), width: 16);
      expect(
        () => encodeApng([(png: small, duration: Duration.zero), (png: large, duration: Duration.zero)]),
        throwsArgumentError,
      );
    });
  });

  testWidgets('the recorder keeps changed frames, merges still ones and stops at the limit', (tester) async {
    await tester.runAsync(() async {
      final red = await _png(const Color(0xFFFF0000));
      final green = await _png(const Color(0xFF00FF00));
      final rotated = await _png(const Color(0xFF00FF00), width: 6, height: 8);
      final screens = [red, red, green, rotated, green];
      var now = DateTime(2026);
      var i = 0;
      SeaproofRecording? stoppedAtLimit;
      final recorder = ScreenRecorder(
        capture: () async => screens[i++ % screens.length],
        framesPerSecond: 1000,
        maxDuration: const Duration(seconds: 5),
        onStop: (r) => stoppedAtLimit = r,
        clock: () => now,
      )..start();
      for (var step = 0; step < 5; step++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        now = now.add(const Duration(seconds: 1));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(recorder.isRecording, isFalse);
      final recording = stoppedAtLimit!;
      expect(recording.firstFrame, red);
      expect(recording.duration, greaterThanOrEqualTo(const Duration(seconds: 5)));
      final frames = ByteData.sublistView(_chunks(recording.apng)[1].$2).getUint32(0);
      expect(frames, greaterThanOrEqualTo(2));
      expect(frames, lessThan(i), reason: 'repeated and rotated frames are dropped');
    });
  });
}
