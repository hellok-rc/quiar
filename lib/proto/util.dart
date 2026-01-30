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

class Uint64 {
  final int _low;
  final int _high;

  static const int _u32mask = 0xFFFFFFFF;
  static const int _u64max = 0xFFFFFFFFFFFFFFFF;

  @pragma("vm:prefer-inline")
  static int _mask32(int value) => value & 0xFFFFFFFF;

  @pragma("vm:prefer-inline")
  const Uint64._raw(this._low, this._high)
      : assert(_low >= 0 && _low <= _u32mask),
        assert(_high >= 0 && _high <= _u32mask);

  @pragma("vm:prefer-inline")
  const Uint64(int value) :
    _low = (value & _u64max) & _u32mask,
    _high = ((value & _u64max) >> 32) & _u32mask;

  static const zero = Uint64._raw(0, 0);
  static const one = Uint64._raw(1, 0);
  static const two = Uint64._raw(2, 0);

  @pragma("vm:prefer-inline")
  factory Uint64.fromBigInt(BigInt value) {
    final masked = value & BigInt.from(_u64max);
    final low = _mask32((masked & BigInt.from(_u32mask)).toInt());
    final high = _mask32((masked >> 32).toInt());
    return Uint64._raw(low, high);
  }

  @pragma("vm:prefer-inline")
  factory Uint64.fromBytes(Uint8List bytes, Endian endian) {
    final bd = ByteData.view(bytes.buffer);
    final u32_0 = bd.getUint32(0, endian);
    final u32_4 = bd.getUint32(4, endian);
    return endian == Endian.big
        ? Uint64._raw(u32_4, u32_0)
        : Uint64._raw(u32_0, u32_4);
  }

  @pragma("vm:prefer-inline")
  BigInt get asBigInt => (BigInt.from(_high) << 32) | .from(_low);

  @pragma("vm:prefer-inline")
  int get asInt {
    if (_high != 0) throw Exception('Uint64 exceeds int64 range');
    return _low;
  }

  @pragma("vm:prefer-inline")
  Uint8List toBytes(Endian endian) {
    final bytes = Uint8List(8);
    final bd = ByteData.view(bytes.buffer);
    if (endian == Endian.big) {
      bd.setUint32(0, _high, Endian.big);
      bd.setUint32(4, _low, Endian.big);
    } else {
      bd.setUint32(0, _low, Endian.little);
      bd.setUint32(4, _high, Endian.little);
    }
    return bytes;
  }

  @pragma("vm:prefer-inline")
  Never _throwOverflow([String? msg]) =>
      throw Exception('Uint64 overflow${msg == null ? "" : ": $msg"}');

  @pragma("vm:prefer-inline")
  Uint64 operator +(Uint64 other) {
    final low = _low + other._low;
    final carry = low > _u32mask ? 1 : 0;
    final high = _high + other._high + carry;
    if (high > _u32mask) _throwOverflow('addition');
    return Uint64._raw(_mask32(low), _mask32(high));
  }

  @pragma("vm:prefer-inline")
  Uint64 operator -(Uint64 other) {
    final low = _low - other._low;
    final borrow = low < 0 ? 1 : 0;
    final adjLow = borrow == 1 ? (low + _u32mask + 1) : low;
    final high = _high - other._high - borrow;
    final adjHigh = high < 0 ? (high + _u32mask + 1) : high;
    return Uint64._raw(_mask32(adjLow), _mask32(adjHigh));
  }

  @pragma("vm:prefer-inline")
  Uint64 operator *(Uint64 other) {
    final a1 = _high, a0 = _low;
    final b1 = other._high, b0 = other._low;
    final p0 = a0 * b0;
    final p1 = a1 * b0;
    final p2 = a0 * b1;
    final p3 = a1 * b1;
    if (p3 != 0) _throwOverflow('multiplication');
    final low = _mask32(p0);
    final mid = (p0 >> 32) + p1 + p2;
    final high = _mask32(mid >> 32);
    if (high > _u32mask) _throwOverflow('multiplication');
    return Uint64._raw(low, high);
  }

  @pragma("vm:prefer-inline")
  Uint64 operator <<(int shift) {
    if (shift <= 0) return this;
    if (shift >= 64) return Uint64.zero;
    int low, high;
    if (shift <= 32) {
      low = _mask32(_low << shift);
      high = _mask32((_high << shift) | (_low >> (32 - shift)));
      if ((_high & (0xFFFFFFFF << (32 - shift))) != 0) {
        _throwOverflow('left shift');
      }
    } else {
      if (_high != 0 || (_low & (0xFFFFFFFF << (64 - shift))) != 0) {
        _throwOverflow('left shift');
      }
      low = 0;
      high = _mask32(_low << (shift - 32));
    }
    return Uint64._raw(low, high);
  }

  @pragma("vm:prefer-inline")
  Uint64 operator >>(int shift) {
    if (shift <= 0) return this;
    if (shift >= 64) return Uint64.zero;
    int low, high;
    if (shift <= 32) {
      high = _mask32(_high >> shift);
      low = _mask32((_low >> shift) | (_high << (32 - shift)));
    } else {
      high = 0;
      low = _mask32(_high >> (shift - 32));
    }
    return Uint64._raw(low, high);
  }

  @pragma("vm:prefer-inline")
  Uint64 operator &(Uint64 other) =>
      Uint64._raw(_low & other._low, _high & other._high);

  @pragma("vm:prefer-inline")
  Uint64 operator |(Uint64 other) =>
      Uint64._raw(_low | other._low, _high | other._high);

  @pragma("vm:prefer-inline")
  Uint64 operator ^(Uint64 other) =>
      Uint64._raw(_low ^ other._low, _high ^ other._high);

  @pragma("vm:prefer-inline")
  Uint64 operator ~() =>
      Uint64._raw(_mask32(~_low), _mask32(~_high));

  @pragma("vm:prefer-inline")
  (Uint64, Uint64) _divMod(Uint64 divisor) {
    if (divisor._high == 0 && divisor._low == 0) {
      throw UnsupportedError('Division by zero');
    }
    if (this < divisor) return (Uint64.zero, this);
    if (this == divisor) return (Uint64.one, Uint64.zero);
    int dividendHigh = _high, dividendLow = _low;
    var divHigh = divisor._high, divLow = divisor._low;
    int quotHigh = 0, quotLow = 0;
    int shift = 0;
    while (true) {
      final nextHigh = divHigh << 1 | (divLow >> 31);
      final nextLow = _mask32(divLow << 1);
      if (nextHigh > dividendHigh || (nextHigh == dividendHigh && nextLow > dividendLow)) {
        break;
      }
      shift++;
      divHigh = nextHigh;
      divLow = nextLow;
    }
    while (shift >= 0) {
      bool canSub = dividendHigh > divHigh || (dividendHigh == divHigh && dividendLow >= divLow);
      if (canSub) {
        int subLow = dividendLow - divLow;
        int borrow = subLow < 0 ? 1 : 0;
        subLow = borrow == 1 ? (subLow + _u32mask + 1) : subLow;
        int subHigh = dividendHigh - divHigh - borrow;
        subHigh = subHigh < 0 ? (subHigh + _u32mask + 1) : subHigh;
        dividendHigh = _mask32(subHigh);
        dividendLow = _mask32(subLow);
        if (shift < 32) {
          quotLow |= 1 << shift;
        } else {
          quotHigh |= 1 << (shift - 32);
        }
      }
      divLow = _mask32((divLow >> 1) | (divHigh << 31));
      divHigh = _mask32(divHigh >> 1);
      shift--;
    }
    final quotient = Uint64._raw(_mask32(quotLow), _mask32(quotHigh));
    final remainder = Uint64._raw(_mask32(dividendLow), _mask32(dividendHigh));
    return (quotient, remainder);
  }

  @pragma("vm:prefer-inline")
  Uint64 operator ~/(Uint64 other) => _divMod(other).$1;

  @pragma("vm:prefer-inline")
  Uint64 operator %(Uint64 other) => _divMod(other).$2;

  @pragma("vm:prefer-inline")
  bool operator ==(Object other) =>
      other is Uint64 && other._low == _low && other._high == _high;

  @pragma("vm:prefer-inline")
  bool operator >(Uint64 other) =>
      _high > other._high || (_high == other._high && _low > other._low);

  @pragma("vm:prefer-inline")
  bool operator <(Uint64 other) =>
      _high < other._high || (_high == other._high && _low < other._low);

  @pragma("vm:prefer-inline")
  bool operator >=(Uint64 other) => !(this < other);

  @pragma("vm:prefer-inline")
  bool operator <=(Uint64 other) => !(this > other);

  @override
  @pragma("vm:prefer-inline")
  int get hashCode => (_high << 32) ^ _low;

  @override
  String toString() => asBigInt.toString();
}