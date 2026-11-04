import 'dart:typed_data';

/// One frame of an animation: a PNG and how long it is shown.
typedef ApngFrame = ({Uint8List png, Duration duration});

/// Joins PNG frames of the same size into an animated PNG, which browsers play in an `<img>`.
///
/// The frames' compressed image data is reused as is, so this is cheap: no pixels are decoded
/// or compressed again. Every frame must have the same width, height, bit depth and colour
/// type as the first, as PNGs from one `RenderRepaintBoundary` do.
Uint8List encodeApng(List<ApngFrame> frames) {
  if (frames.isEmpty) {
    throw ArgumentError.value(frames, 'frames', 'At least one frame is needed.');
  }

  final first = _PngChunks.parse(frames.first.png);
  final out = BytesBuilder(copy: false)
    ..add(_signature)
    ..add(_chunk('IHDR', first.header))
    ..add(_chunk('acTL', _uint32s([frames.length, 0]))); // 0 plays = loop forever.

  var sequence = 0;
  for (var i = 0; i < frames.length; i++) {
    final png = i == 0 ? first : _PngChunks.parse(frames[i].png);
    if (!_sameHeader(png.header, first.header)) {
      throw ArgumentError.value(i, 'frames', 'Frame $i differs in size or format from the first.');
    }

    // Delays are a fraction; milliseconds over 1000, capped to what 16 bits can hold.
    final delay = frames[i].duration.inMilliseconds.clamp(1, 65535);
    final control = ByteData(26)
      ..setUint32(0, sequence++)
      ..setUint32(4, first.width)
      ..setUint32(8, first.height)
      ..setUint32(12, 0) // x offset
      ..setUint32(16, 0) // y offset
      ..setUint16(20, delay)
      ..setUint16(22, 1000)
      ..setUint8(24, 0) // dispose: none
      ..setUint8(25, 0); // blend: source
    out.add(_chunk('fcTL', control.buffer.asUint8List()));

    for (final data in png.data) {
      if (i == 0) {
        out.add(_chunk('IDAT', data));
      } else {
        out.add(
          _chunk(
            'fdAT',
            Uint8List.fromList([
              ..._uint32s([sequence++]),
              ...data,
            ]),
          ),
        );
      }
    }
  }

  out.add(_chunk('IEND', Uint8List(0)));
  return out.takeBytes();
}

const _signature = [137, 80, 78, 71, 13, 10, 26, 10];

final class _PngChunks {
  _PngChunks(this.header, this.data);

  factory _PngChunks.parse(Uint8List png) {
    for (var i = 0; i < _signature.length; i++) {
      if (png.length <= i || png[i] != _signature[i]) {
        throw const FormatException('Not a PNG.');
      }
    }

    final bytes = ByteData.sublistView(png);
    Uint8List? header;
    final data = <Uint8List>[];
    var offset = _signature.length;
    while (offset + 12 <= png.length) {
      final length = bytes.getUint32(offset);
      final type = String.fromCharCodes(png, offset + 4, offset + 8);
      final body = Uint8List.sublistView(png, offset + 8, offset + 8 + length);
      if (type == 'IHDR') {
        header = body;
      } else if (type == 'IDAT') {
        data.add(body);
      } else if (type == 'IEND') {
        break;
      }

      offset += 12 + length;
    }

    if (header == null || data.isEmpty) {
      throw const FormatException('The PNG has no header or image data.');
    }

    return _PngChunks(header, data);
  }

  final Uint8List header;
  final List<Uint8List> data;

  int get width => ByteData.sublistView(header).getUint32(0);
  int get height => ByteData.sublistView(header).getUint32(4);
}

bool _sameHeader(Uint8List a, Uint8List b) {
  if (a.length != b.length) {
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }

  return true;
}

Uint8List _uint32s(List<int> values) {
  final data = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    data.setUint32(i * 4, values[i]);
  }

  return data.buffer.asUint8List();
}

Uint8List _chunk(String type, Uint8List body) {
  final typeBytes = type.codeUnits;
  final out = ByteData(12 + body.length)..setUint32(0, body.length);
  final bytes = out.buffer.asUint8List()
    ..setAll(4, typeBytes)
    ..setAll(8, body);
  out.setUint32(8 + body.length, _crc32(bytes, 4, 8 + body.length));
  return bytes;
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }

    table[n] = c;
  }

  return table;
}();

int _crc32(Uint8List bytes, int start, int end) {
  var crc = 0xFFFFFFFF;
  for (var i = start; i < end; i++) {
    crc = _crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
  }

  return crc ^ 0xFFFFFFFF;
}
