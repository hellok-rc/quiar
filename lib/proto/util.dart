import "dart:typed_data";

class OrErr<R, E extends Exception> {
  late final R? result;
  late final E? error;

  OrErr.ok(this.result);
  OrErr.err(this.error);

  (R?, E?) get orErr => (result, error);
  R? get okOrNull => result;
  E? get errOrNull => error;
  bool get isOk => result != null;
  bool get isErr => error != null;

  R takeOk([ String? message ]) {
    if (result == null) {
      throw Exception("the OrErr is error! $message");
    }

    return result!;
  }
}

extension Uint64ToBigInt on Uint8List {
  BigInt toU64([ Endian endian = .big ]) {
    assert(length == 8, "Uint8List for u64 must be 8 bit");
    BigInt result = BigInt.zero;

    if (endian == .big) {
      for (int i = 0; i < 8; i++) {
        result += BigInt.from(this[i]) << ((7 - i) * 8);
      }
    } else {
      for (int i = 0; i < 8; i++) {
        result += BigInt.from(this[i]) << (i * 8);
      }
    }

    return result;
  }
}

extension BigIntToUint64 on BigInt {
  Uint8List toUint8List(Endian endian) {
    if (this < .zero || this > (BigInt.one << 64) - .one) {
      throw Exception("Overflow u64");
    }

    final bytes = Uint8List(8);
    final mask = BigInt.from(0xFF);

    if (endian == .big) {
      for (int i = 0; i < 8; i++) {
        bytes[i] = ((this >> 56 - (i * 8)) & mask).toInt();
      }
    } else {
      for (int i = 0; i < 8; i++) {
        bytes[i] = ((this >> i * 8) & mask).toInt();
      }
    }

    return bytes;
  }
}