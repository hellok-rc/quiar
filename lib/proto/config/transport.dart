import "package:freezed_annotation/freezed_annotation.dart";
import "package:quiar/proto/quic.dart";

part "transport.freezed.dart";

@freezed
abstract class TransportConfig with _$TransportConfig {
  const factory TransportConfig({
    required VarInt maxConcurrentBidiStreams,
    required VarInt maxConcurrentUniStreams,
    required VarInt maxIdleTimeout,
    required VarInt streamReceiveWindow,
    required VarInt receiveWindow,
    required Uint64 sendWindow,
    required bool sendFairness,
    required int packetThreshold,
    required double timeThreshold,
    required Duration initialRtt,
    required int initialMtu,
    required int minMtu,
    required MtuDiscoveryConfig? mtuDiscoveryConfig,
    required bool padToMtu,
    required AckFrequencyConfig? ackFrequencyConfig,
    required int persistentCongestionThreshold,
    required Duration? keepAliveInterval,
    required int cryptoBufferSize,
    required bool allowSpin,
    required int? datagramReceiveBufferSize,
    required int datagramSendBufferSize,
    // Develop use
    bool? deterministicPacketNumbers,
    required ControllerFactory congestionControllerFactory,
    required bool enableSegmentationOffload,
    required QlogSink qlogSink
  }) = _TransportConfig;
}

@freezed
abstract class AckFrequencyConfig with _$AckFrequencyConfig {
  const factory AckFrequencyConfig({
    required int ackElicitingThreshold,
    required Duration? maxAckDelay,
    required int reorderingThreshold,
  }) = _AckFrequencyConfig;
}

@freezed
abstract class MtuDiscoveryConfig with _$MtuDiscoveryConfig {
  const factory MtuDiscoveryConfig({
    required Duration interval,
    required int upperBound,
    required int minimumChange,
    required Duration blackHoleCooldown
  }) = _MtuDiscoveryConfig;
}