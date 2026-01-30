import "dart:typed_data";
import "Dart:io" show InternetAddress;
import "package:freezed_annotation/freezed_annotation.dart";

import "package:quiar/proto/quic.dart";
import "package:quiar/proto/crypto.dart" as crypto;

part "config.freezed.dart";

@freezed
abstract class EndpointConfig with _$EndpointConfig {
  const factory EndpointConfig({
    required HmacKey resetKey,
    required VarInt maxUdpPayloadSize,
    required ConnectionIdGenerator Function() connectionIdGeneratorFactory,
    required Uint32List supportedVersions,
    required bool greaseQuicBit,
    required Duration minResetInterval,
    required Uint8List rngSeed,
  }) = _EndpointConfig;
}

@freezed
abstract class ServerConfig with _$ServerConfig {
  const factory ServerConfig({
    required TransportConfig transport,
    required crypto.ServerConfig crypto,
    required ValidationTokenConfig validationToken,
    required HandshakeTokenKey tokenKey,
    required Duration retryTokenLifetime,
    required bool migration,
    required InternetAddress? preferredAddr4,
    required InternetAddress? preferredAddr6,
    required int maxIncoming,
    required BigInt incomingBufferSize,
    required BigInt incomingBufferSizeTotal,
    required TimeSource timeSource
  }) = _ServerConfig;
}

@freezed
abstract class ValidationTokenConfig with _$ValidationTokenConfig {
  const factory ValidationTokenConfig({
    required Duration lifetime,
    required TokenLog log,
    required int sent,
  }) = _ValidationTokenConfig;
}

@freezed
abstract class ClientConfig with _$ClientConfig {
  const factory ClientConfig({
    required TransportConfig transport,
    required crypto.ClientConfig crypto,
    required TokenStore tokenStore,
    required ConnectionId Function() initialDstCidProvider,
    required int version
  }) = _ClientConfig;
}

@freezed
abstract class ConfigError with _$ConfigError implements Exception {
  const factory ConfigError.outOfBounds() = _OutOfBoundsConfigError;

  @override
  String toString() => when(
    outOfBounds: () => "value exceeds supported bounds"
  );
}

abstract class TimeSource {
  DateTime now();
}