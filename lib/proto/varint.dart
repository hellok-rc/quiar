import "dart:typed_data";

import "package:quiar/proto/quic.dart";

class VarIntBoundsExceeded implements Exception {
  @override
  String toString() => "VarIntBoundsExceeded: value too large for varint encoding";
}

// QUIC 变长整数
class VarInt {
  static final max = VarInt((1 << 62) - 1);
  static final maxSize = VarInt(8);
  static final _bitsContrast = [
    (1, BigInt.one << 6),
    (2, BigInt.one << 14),
    (4, BigInt.one << 30),
    (8, BigInt.one << 62)
  ];

  final BigInt _value;
  VarInt(int v) : _value = BigInt.from(v);

  static OrErr<VarInt, VarIntBoundsExceeded> new_(BigInt v) {
    if (v < BigInt.one << 62) {
      return .ok(VarInt.newUnchecked(v));
    }

    return .err(VarIntBoundsExceeded());
  }

  VarInt.newUnchecked(this._value);

  BigInt get inner => _value;

  int size() {
    for (final (bits, width) in _bitsContrast) {
      if (_value < width) return bits;
    }
    
    throw ArgumentError.value(_value, "VarInt", "malformed VarInt");
  }

  @override
  String toString() => _value.toString();
}

extension IntToVarInt on int {
  VarInt get asVarInt => VarInt(this);
}

OrErr<VarInt, UnexpectedEnd> decodeVarInt(SizedBufferReader reader) {
  final buffer = Uint8List(8);
  buffer[0] = reader.readUint8();
  final tag = buffer[0] >> 6;
  buffer[0] &= 0011_1111.asBin;

  final sliceByteData = (int l) {
    buffer.setAll(1, reader.readFixed(l - 1));
    return ByteData.view(buffer.buffer, 0, l);
  };

  BigInt x;
  if (tag == 00.asBin) {
    // 1-bit Uint8
    x = BigInt.from(buffer[0]);
  } else if (tag == 01.asBin) {
    // 2-bit Uint16
    if (reader.remainingLength < 1) return .err(UnexpectedEnd());
    final n = sliceByteData(2).getUint16(0, .big);
    x = BigInt.from(n);
  } else if (tag == 10.asBin) {
    // 4-bit Uint32
    if (reader.remainingLength < 3) return .err(UnexpectedEnd());
    final n = sliceByteData(4).getUint32(0, .big);
    x = BigInt.from(n);
  } else if (tag == 11.asBin) {
    // 8-bit Uint64
    if (reader.remainingLength < 7) return .err(UnexpectedEnd());
    buffer.setAll(1, reader.readFixed(7));
    x = buffer.toU64();
  } else {
    throw Exception("!");
  }

  return .ok(VarInt.newUnchecked(x));
}

void encodeVarInt(VarInt varInt, BufferWritter writter) {
  final x = varInt.inner;
  if (x < BigInt.one << 6) {
    writter.writeUint8(x.toInt());
  } else if (x < BigInt.one << 14) {
    writter.writeUint16((01.asBin << 14) | x.toInt());
  } else if (x < BigInt.one << 30) {
    writter.writeUint32((10.asBin << 30) | x.toInt());
  } else if (x < BigInt.one << 62) {
    writter.writeUint64((BigInt.from(11.asBin) << 62) | x);
  } else {
    throw Exception("!");
  }
}