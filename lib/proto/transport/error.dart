import "package:freezed_annotation/freezed_annotation.dart";
import "package:quiar/proto/frame.dart" as frame;

part "error.freezed.dart";

@freezed
abstract class Error with _$Error implements Exception {
  const factory Error({
    required Code code,
    required frame.FrameType? frame,
    required String reason,
    required Exception? crypto
  }) = _Error;

  factory Error.new_(Code code, String reason) {
    return Error(
      code: code,
      reason: reason,
      frame: null,
      crypto: null
    );
  }

  factory Error.transport(TransportError error, String reason) {
    return Error(
      code: Code(error.value),
      reason: reason,
      frame: null,
      crypto: null
    );
  }

  bool operator ==(Object other) {
    if (other == Error) return code == (other as Error).code;
    return false;
  }

  @override
  String toString() => [
    "$code",
    this.frame == null ? "" : "in ${this.frame}",
    reason.isEmpty ? "" : ": $reason"
  ].join(" ");
}

class Code {
  static final errorPair = Map.fromEntries(
    TransportError.codePair.entries
      .map((e) => MapEntry(Code(e.key), e.value))
  );

  final int code;
  Code(this.code);
  Code.crypto(BigInt code) : code = (BigInt.from(0x100) | code).toInt();

  @override
  String toString() => [
    errorPair[this]?.name ?? "Code($code)",
    errorPair[this]?.content ?? "unknown error"
  ].join(" ");

  @override
  int get hashCode => code.hashCode;
}

@freezed
abstract class TransportError with _$TransportError {
  const TransportError._();
  const factory TransportError.noError() = _NoError;
  const factory TransportError.internalError() = _InternalError;
  const factory TransportError.connectionRefused() = _ConnectionRefused;
  const factory TransportError.flowControlError() = _FlowControlError;
  const factory TransportError.streamLimitError() = _StreamLimitError;
  const factory TransportError.streamStateError() = _StreamStateError;
  const factory TransportError.finalSizeError() = _FinalSizeError;
  const factory TransportError.frameEncodingError() = _FrameEncodingError;
  const factory TransportError.transportParameterError() = _TransportParameterError;
  const factory TransportError.connectionIdLimitError() = _ConnectionIdLimitError;
  const factory TransportError.protocolViolation() = _ProtocolViolation;
  const factory TransportError.invalidToken() = _InvalidToken;
  const factory TransportError.applicationError() = _ApplicationError;
  const factory TransportError.cryptoBufferExceeded() = _CryptoBufferExceeded;
  const factory TransportError.keyUpdateError() = _KeyUpdateError;
  const factory TransportError.aeadLimitReached() = _AeadLimitReached;
  const factory TransportError.noViablePath() = _NoViablePath;

  static const codePair = <int, TransportError>{
    0x0: .noError(),
    0x1: .internalError(),
    0x2: .connectionRefused(),
    0x3: .flowControlError(),
    0x4: .streamLimitError(),
    0x5: .streamStateError(),
    0x6: .finalSizeError(),
    0x7: .frameEncodingError(),
    0x8: .transportParameterError(),
    0x9: .connectionIdLimitError(),
    0xA: .protocolViolation(),
    0xB: .invalidToken(),
    0xC: .applicationError(),
    0xD: .cryptoBufferExceeded(),
    0xE: .keyUpdateError(),
    0xF: .aeadLimitReached(),
    0x10: .noViablePath()
  };

  int get value => codePair.entries.firstWhere((e) => e.value == this).key;

  String get content => when(
    noError: () => "the connection is being closed abruptly in the absence of any error",
    internalError: () => "the endpoint encountered an internal error and cannot continue with the connection",
    connectionRefused: () => "the server refused to accept a new connection",
    flowControlError: () => "received more data than permitted in advertised data limits",
    streamLimitError: () => "received a frame for a stream identifier that exceeded advertised the stream limit for the corresponding stream type",
    streamStateError: () => "received a frame for a stream that was not in a state that permitted that frame",
    finalSizeError: () => "received a STREAM frame or a RESET_STREAM frame containing a different final size to the one already established",
    frameEncodingError: () => "received a frame that was badly formatted",
    transportParameterError: () => "received transport parameters that were badly formatted, included an invalid value, was absent even though it is mandatory, was present though it is forbidden, or is otherwise in error",
    connectionIdLimitError: () => "the number of connection IDs provided by the peer exceeds the advertised active_connection_id_limit",
    protocolViolation: () => "detected an error with protocol compliance that was not covered by more specific error codes",
    invalidToken: () => "received an invalid Retry Token in a client Initial",
    applicationError: () => "the application or application protocol caused the connection to be closed during the handshake",
    cryptoBufferExceeded: () => "received more data in CRYPTO frames than can be buffered",
    keyUpdateError: () => "key update error",
    aeadLimitReached: () => "the endpoint has reached the confidentiality or integrity limit for the AEAD algorithm",
    noViablePath: () => "no viable network path exists"
  );

  String get name => when(
    noError: () => "NoError",
    internalError: () => "InternalError",
    connectionRefused: () => "ConnectionRefused",
    flowControlError: () => "FlowControlError",
    streamLimitError: () => "StreamLimitError",
    streamStateError: () => "StreamStateError",
    finalSizeError: () => "FinalSizeError",
    frameEncodingError: () => "FrameEncodingError",
    transportParameterError: () => "TransportParameterError",
    connectionIdLimitError: () => "ConnectionIdLimitError",
    protocolViolation: () => "ProtocolViolation",
    invalidToken: () => "InvalidToken",
    applicationError: () => "ApplicationError",
    cryptoBufferExceeded: () => "CryptoBufferExceeded",
    keyUpdateError: () => "KeyUpdateError",
    aeadLimitReached: () => "AeadLimitReached",
    noViablePath: () => "NoViablePath"
  );
}

