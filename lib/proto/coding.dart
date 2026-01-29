import "dart:io";
import "dart:typed_data";

import "package:quiar/proto/quic.dart";

extension BinImpl on int {
  int get asBin {
    if (this == 0 || this == 1) return this;
    assert(!this.toString().contains(RegExp(r'[^01]')));
    int decimal = 0;
    int power = 0;
    int num = this;
    while (num > 0) {
      int lastDigit = num % 10;
      decimal += lastDigit * (1 << power);
      num = num ~/ 10;
      power++;
    }
    return decimal;
  }
}

extension AsBigInt on int {
  BigInt get asBigInt => BigInt.from(this);
}

class UnexpectedEnd implements Exception {}

extension BufferReaderExt on BufferReader {
  OrErr<Uint8List, UnexpectedEnd> tryReadFixed(int length) {
    try {
      return .ok(readFixed(length));
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<int, UnexpectedEnd> tryReadUint8() {
    try {
      return .ok(readUint8());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<int, UnexpectedEnd> tryReadUint16() {
    try {
      return .ok(readUint16());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<int, UnexpectedEnd> tryReadUint32() {
    try {
      return .ok(readUint32());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<BigInt, UnexpectedEnd> tryReadUint64() {
    try {
      return .ok(readUint64());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<int, UnexpectedEnd> tryReadInt8() {
    try {
      return .ok(readInt8());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<int, UnexpectedEnd> tryReadInt16() {
    try {
      return .ok(readInt16());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<int, UnexpectedEnd> tryReadInt32() {
    try {
      return .ok(readInt32());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<int, UnexpectedEnd> tryReadInt64() {
    try {
      return .ok(readInt64());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<double, UnexpectedEnd> tryReadFloat32() {
    try {
      return .ok(readFloat32());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<double, UnexpectedEnd> tryReadFloat64() {
    try {
      return .ok(readFloat64());
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  IpAddr _readIp(InternetAddressType type) {
    final length = switch (type) {
      .IPv4 => 4,
      .IPv6 => 16,
      _ => throw ArgumentError("!")
    };
    final bytes = readBytes(length);
    return IpAddr.fromRawAddress(bytes, type: type);
  }

  OrErr<IpAddr, UnexpectedEnd> tryReadIpv4() {
    try {
      return .ok(_readIp(.IPv4));
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }

  OrErr<IpAddr, UnexpectedEnd> tryReadIpv6() {
    try {
      return .ok(_readIp(.IPv6));
    } catch (_) {
      return .err(UnexpectedEnd());
    }
  }
}

extension SizedBufferReaderExt on SizedBufferReader {
  OrErr<VarInt, UnexpectedEnd> tryReadVar() {
    return decodeVarInt(this);
  }
}

extension BufferWritterExt on BufferWritter {
  void writeVar(BigInt x) {
    encodeVarInt(VarInt.new_(x).takeOk(), this);
  }
}