import "dart:typed_data";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:quiar/proto/quic.dart";

import "dart:io" show InternetAddress;

part "shared.freezed.dart";

@freezed
abstract class ConnectionEvent with _$ConnectionEvent {
  const factory ConnectionEvent.datagram({
    required Stopwatch now,
    required InternetAddress remote,
    // rqeuired 
  }) = _DatagramEvent;

  const factory ConnectionEvent.newIdentifiers() = _NewIdentifiersEvent;
}

@freezed
abstract class EndpointEvent with _$EndpointEvent {
  const factory EndpointEvent.drained() = _DrainedEvent;

  const factory EndpointEvent.resetToken(
    InternetAddress target,
    ResetToken token,
  ) = _ResetTokenEvent;

  const factory EndpointEvent.needIdentifiers(
    Stopwatch since,
    BigInt id
  ) = _NeedIdentifiersEvent;

  const factory EndpointEvent.retireConnectionId(
    Stopwatch since,
    BigInt id,
    bool nnedIssue,
  ) = _RetireConnectionIdEvent;
}

class ConnectionId {
  late int len;
  late final Uint8List bytes;
  ConnectionId({ required this.len, required this.bytes });
  ConnectionId.new_(Uint8List bytes) {
    assert(bytes.length <= maxCidSize);
    this.len = bytes.length;
    this.bytes = Uint8List(maxCidSize)
      ..setAll(0, bytes);
  }

  ConnectionId.fromBuffer(SizedBufferReader reader, int len) {
    assert(len <= maxCidSize);
    this.len = len;
    this.bytes = Uint8List(maxCidSize)
      ..setAll(0, reader.readFixed(len));
  }

  static ConnectionId? decodeLong(SizedBufferReader reader) {
    final len = reader.readUint8();
    if (len > maxCidSize || reader.remainingLength < len) {
      return null;
    }
    return ConnectionId.fromBuffer(reader, len); 
  }

  encodeLong(SizedBufferWritter writter) {
    writter.writeUint8(len);
    writter.writeBytes(bytes);
  }
}

@freezed
abstract class EcnCodepoint with _$EcnCodepoint {
  const EcnCodepoint._();
  const factory EcnCodepoint.ect0() = _Ect0Code;
  const factory EcnCodepoint.ect1() = _Ect1Code;
  const factory EcnCodepoint.ce() = _CeCode;

  static const codePair = <int, EcnCodepoint>{
    2: .ect0(),
    1: .ect1(),
    3: .ce()
  };

  int get value => codePair.entries.firstWhere((e) => e.value == this).key;

  static EcnCodepoint? fromBits(int x) => codePair[x];

  bool isCe() => whenOrNull(ce: () => true) ?? false;
}

@freezed
abstract class IssuedCid with _$IssuedCid {
  const factory IssuedCid({
    required BigInt sequence,
    required ConnectionId id,
    required ResetToken resetToken
  }) = _IssuedCid;
}