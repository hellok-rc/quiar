import "dart:typed_data";

import "package:quiar/proto/quic.dart";

class VarIntBoundsExceeded implements Exception {
  @override
  String toString() => "VarIntBoundsExceeded: value too large for varint encoding";
}

// QUIC 变长整数
class VarInt {
  static const max = VarInt(Uint64((1 << 62) - 1));
  static const maxSize = VarInt(Uint64(8));
  final Uint64 _value;
  const VarInt(this._value);
  VarInt.fromInt(int value) : _value = Uint64(value);
  
  static OrErr<VarInt, VarIntBoundsExceeded> fromUint64(Uint64 v) {
    if (v < Uint64.one << 62) {
      return .ok(VarInt(v));
    }

    return .err(VarIntBoundsExceeded());
  }

  Uint64 get inner => _value;
  
  int size() {
    if (_value < Uint64.one << 6) {
      return 1;
    } else if (_value < Uint64.one << 14) {
      return 2;
    } else if (_value < Uint64.one << 30) {
      return 4;
    } else if (_value < Uint64.one << 62) {
      return 8;
    }
    
    throw ArgumentError.value(_value, "VarInt", "malformed VarInt");
  }

  @override
  String toString() => _value.toString();

  VarInt operator +(VarInt other) => VarInt.fromUint64(_value + other._value).takeOk();
  VarInt operator -(VarInt other) => VarInt.fromUint64(_value - other._value).takeOk();
  VarInt operator *(VarInt other) => VarInt.fromUint64(_value * other._value).takeOk();
  VarInt operator ~/(VarInt other) => VarInt.fromUint64(_value ~/ other._value).takeOk();
  VarInt operator %(VarInt other) => VarInt.fromUint64(_value % other._value).takeOk();
  VarInt operator ^(VarInt other) => VarInt.fromUint64(_value ^ other._value).takeOk();
  VarInt operator |(VarInt other) => VarInt.fromUint64(_value | other._value).takeOk();
  VarInt operator &(VarInt other) => VarInt.fromUint64(_value | other._value).takeOk();
  VarInt operator <<(int shift) => VarInt.fromUint64(_value << shift).takeOk();
  VarInt operator >>(int shift) => VarInt.fromUint64(_value >> shift).takeOk();
  VarInt operator ~() => VarInt.fromUint64(~_value).takeOk();
  bool operator ==(Object other) {
    if (other is VarInt) return _value == other._value;
    return false;
  }
  bool operator >(VarInt other) => _value > other._value;
  bool operator <(VarInt other) => _value < other._value;
  bool operator >=(VarInt other) => _value >= other._value;
  bool operator <=(VarInt other) => _value <= other._value;
}

extension IntToVarInt on int {
  VarInt get asVarInt => VarInt(Uint64(this));
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

  Uint64 x;
  if (tag == 00.asBin) {
    // 1-bit Uint8
    x = Uint64(buffer[0]);
  } else if (tag == 01.asBin) {
    // 2-bit Uint16
    if (reader.remainingLength < 1) return .err(UnexpectedEnd());
    final n = sliceByteData(2).getUint16(0, .big);
    x = Uint64(n);
  } else if (tag == 10.asBin) {
    // 4-bit Uint32
    if (reader.remainingLength < 3) return .err(UnexpectedEnd());
    final n = sliceByteData(4).getUint32(0, .big);
    x = Uint64(n);
  } else if (tag == 11.asBin) {
    // 8-bit Uint64
    if (reader.remainingLength < 7) return .err(UnexpectedEnd());
    buffer.setAll(1, reader.readFixed(7));
    x = Uint64.fromBytes(buffer, .big);
  } else {
    throw Exception("!");
  }

  return .ok(VarInt(x));
}

void encodeVarInt(VarInt varInt, BufferWritter writter) {
  final x = varInt.inner;
  if (x < Uint64.one << 6) {
    writter.writeUint8(x.asInt);
  } else if (x < Uint64.one << 14) {
    writter.writeUint16((01.asBin << 14) | x.asInt);
  } else if (x < Uint64.one << 30) {
    writter.writeUint32((10.asBin << 30) | x.asInt);
  } else if (x < Uint64.one << 62) {
    writter.writeUint64((Uint64(11.asBin) << 62) | x);
  } else {
    throw Exception("!");
  }
}