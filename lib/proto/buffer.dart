import "dart:typed_data";
import "./quic.dart";

abstract class BufferReader {
  Uint8List readBytes(int length);
  Uint8List readFixed(int length);

  int readUint8();
  int readUint16([ Endian? endian ]);
  int readUint32([ Endian? endian ]);
  BigInt readUint64([ Endian? endian ]);

  int readInt8();
  int readInt16([ Endian? endian ]);
  int readInt32([ Endian? endian ]);
  int readInt64([ Endian? endian ]);

  double readFloat32([ Endian? endian ]);
  double readFloat64([ Endian? endian ]);
}

abstract class SizedBufferReader extends BufferReader {
  int get length;
  int get currentOffset;
  int get remainingLength;
}

class BaseReader implements BufferReader {
  Uint8List readBytes(int length) {
    throw UnimplementedError();
  }

  Uint8List readFixed(int length) {
    final bytes = readBytes(length);
    if (bytes.length != length) {
      throw Exception("Not enough buffer data.");
    }
    return bytes;
  }

  ByteData _readByteData(int length) => ByteData.view(readFixed(length).buffer);
  Endian _defaultEndian = .big;

  int readUint8() =>
    _readByteData(1).getUint8(0);
  int readUint16([ Endian? endian ]) =>
    _readByteData(2).getUint16(0, endian ?? _defaultEndian);
  int readUint32([ Endian? endian ]) =>
    _readByteData(4).getUint32(0, endian ?? _defaultEndian);
  BigInt readUint64([ Endian? endian ]) => readFixed(8).toU64();

  int readInt8() =>
    _readByteData(1).getInt8(0);
  int readInt16([ Endian? endian ]) =>
    _readByteData(2).getInt16(0, endian ?? _defaultEndian);
  int readInt32([ Endian? endian ]) =>
    _readByteData(4).getInt32(0, endian ?? _defaultEndian);
  int readInt64([ Endian? endian ]) =>
    _readByteData(8).getInt64(0, endian ?? _defaultEndian);

  double readFloat32([ Endian? endian ]) =>
    _readByteData(4).getFloat32(0, endian ?? _defaultEndian);
  double readFloat64([ Endian? endian ]) =>
    _readByteData(8).getFloat64(0, endian ?? _defaultEndian);
}

class BytesReader extends BaseReader implements SizedBufferReader {
  late final Uint8List _bytes;
  BytesReader(this._bytes);

  int _currentOffset = 0;

  int get length => _bytes.length;
  int get currentOffset => _currentOffset;
  int get remainingLength => length - currentOffset;

  @override
  Uint8List readBytes(int length) {
    if (remainingLength < length) {
      length = remainingLength;
    }
    _currentOffset += length;
    return Uint8List.view(_bytes.buffer, currentOffset, length);
  }

  @override
  Uint8List readFixed(int length) {
    if (remainingLength < length) {
      throw Exception("Not enough buffer data.");
    }
    _currentOffset += length;
    return Uint8List.view(_bytes.buffer, currentOffset, length);
  }
}

abstract class BufferWritter {
  void writeBytes(Uint8List bytes);

  void writeUint8(int value);
  void writeUint16(int value, [ Endian? endian ]);
  void writeUint32(int value, [ Endian? endian ]);
  void writeUint64(BigInt value, [ Endian? endian ]);

  void writeInt8(int value);
  void writeInt16(int value, [ Endian? endian ]);
  void writeInt32(int value, [ Endian? endian ]);
  void writeInt64(int value, [ Endian? endian ]);

  void writeFloat32(double value, [ Endian? endian ]);
  void writeFloat64(double value, [ Endian? endian ]);
}

abstract class SizedBufferWritter extends BufferWritter {
  int get length;
  int get currentOffset;
  int get remainingLength;

  Uint8List toBytes({ bool copy = false });
}

class BaseWritter implements BufferWritter {
  void writeBytes(Uint8List bytes) {
    throw UnimplementedError();
  }

  void _writeByteData(int length, void Function(ByteData byteData) callback) {
    final byteData = ByteData(length);
    callback(byteData);
    writeBytes(byteData.buffer.asUint8List());
  }

  Endian _defaultEndian = .big;

  void writeUint8(int value) =>
    _writeByteData(1, (b) => b.setUint8(0, value));
  void writeUint16(int value, [ Endian? endian ]) =>
    _writeByteData(2, (b) => b.setUint16(0, value, endian ?? _defaultEndian));
  void writeUint32(int value, [ Endian? endian ]) =>
    _writeByteData(4, (b) => b.setUint32(0, value, endian ?? _defaultEndian));
  void writeUint64(BigInt value, [ Endian? endian ]) =>
    writeBytes(value.toUint8List(endian ?? _defaultEndian));

  void writeInt8(int value) =>
    _writeByteData(1, (b) => b.setInt8(0, value));
  void writeInt16(int value, [ Endian? endian ]) =>
    _writeByteData(2, (b) => b.setInt16(0, value, endian ?? _defaultEndian));
  void writeInt32(int value, [ Endian? endian ]) =>
    _writeByteData(4, (b) => b.setInt16(0, value, endian ?? _defaultEndian));
  void writeInt64(int value, [ Endian? endian ]) =>
    _writeByteData(8, (b) => b.setInt16(0, value, endian ?? _defaultEndian));

  void writeFloat32(double value, [ Endian? endian ]) =>
    _writeByteData(4, (b) => b.setFloat32(0, value, endian ?? _defaultEndian));
  void writeFloat64(double value, [ Endian? endian ]) =>
    _writeByteData(8, (b) => b.setFloat64(0, value, endian ?? _defaultEndian));
}

class BytesWritter extends BaseWritter implements SizedBufferWritter {
  late final Uint8List _bytes;
  BytesWritter(int length) : _bytes = Uint8List(length);
  BytesWritter.fromUint8List(Uint8List bytes, { bool copy = true }) :
    _bytes = copy ? Uint8List.sublistView(bytes) : bytes;
  
  int _currentOffset = 0;

  int get length => _bytes.length;
  int get currentOffset => _currentOffset;
  int get remainingLength => length - currentOffset;

  @override
  void writeBytes(Uint8List bytes) {
    if (remainingLength < bytes.length) {
      throw Exception("Outflow the buffer data.");
    }
    _bytes.setAll(currentOffset, bytes);
    _currentOffset += bytes.length;
  }

  @override
  Uint8List toBytes({ bool copy = false }) =>
    copy ? Uint8List.sublistView(_bytes) : _bytes;
}