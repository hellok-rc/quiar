import "dart:typed_data";
import "dart:math" as math;
import "package:freezed_annotation/freezed_annotation.dart";
import "package:quiar/proto/quic.dart";
import "package:quiar/proto/coding.dart" as coding;
import "package:quiar/proto/config/config.dart";
import "package:quiar/proto/transport/error.dart" as transport;

part "parameters.freezed.dart";

@unfreezed
abstract class TransportParameters with _$TransportParameters {
  static const _default = TransportParameters();

  const factory TransportParameters({
    @Default(VarInt(Uint64(0))) VarInt maxIdleTimeout,
    @Default(VarInt(Uint64(65525))) VarInt maxUdpPayloadSize,
    @Default(VarInt(Uint64(0))) VarInt initialMaxData,
    @Default(VarInt(Uint64(0))) VarInt initialMaxStreamDataBidiLocal,
    @Default(VarInt(Uint64(0))) VarInt initialMaxStreamDataBidiRemote,
    @Default(VarInt(Uint64(0))) VarInt initialMaxStreamDataUni,
    @Default(VarInt(Uint64(0))) VarInt initialMaxStreamsBidi,
    @Default(VarInt(Uint64(0))) VarInt initialMaxStreamsUni,
    @Default(VarInt(Uint64(0))) VarInt ackDelayExponent,
    @Default(VarInt(Uint64(25))) VarInt maxAckDelay,
    @Default(VarInt(Uint64(2))) VarInt activeConnectionIdLimit,
    @Default(false) bool disableActiveMigration,
    VarInt? maxDatagramFrameSize,
    ConnectionId? initialSrcCid,
    @Default(false) bool greaseQuicBit,
    VarInt? minAckDelay,
    ConnectionId? originalDstCid,
    ConnectionId? retrySrcCid,
    ResetToken? statelessResetToken,
    PreferredAddress? preferredAddress,
    ReservedTransportParameter? greaseTransportParameter,
    Uint8List? writeOrder
  }) = _TransportParameters;

  static TransportParameters new_(
    TransportConfig config,
    EndpointConfig endpointConfig,
    ConnectionIdGenerator cidGen,
    ConnectionId initialSrcCid,
    ServerConfig? serverConfig,
    RngCore rng,
  ) {
    return TransportParameters(
      initialSrcCid: initialSrcCid,
      initialMaxStreamsBidi: config.maxConcurrentBidiStreams,
      initialMaxStreamsUni: config.maxConcurrentUniStreams,
      initialMaxData: config.receiveWindow,
      initialMaxStreamDataBidiLocal: config.streamReceiveWindow,
      initialMaxStreamDataBidiRemote: config.streamReceiveWindow,
      initialMaxStreamDataUni: config.streamReceiveWindow,
      maxUdpPayloadSize: endpointConfig.maxUdpPayloadSize,
      maxIdleTimeout: config.maxIdleTimeout,
      disableActiveMigration: serverConfig?.migration ?? false,
      activeConnectionIdLimit: (cidGen.cidLen() == 0 ? 2 : CidQueue.len).asVarInt,
      maxDatagramFrameSize: config.datagramReceiveBufferSize == null
        ? null : VarInt.fromInt(math.min(config.datagramReceiveBufferSize!, 65535)),
      greaseQuicBit: endpointConfig.greaseQuicBit,
      minAckDelay: VarInt.fromInt(timerGranularity.inMicroseconds),
      greaseTransportParameter: ReservedTransportParameter.random(rng),
      writeOrder: Uint8List.fromList(List.generate(
        TransportParameterId.supported.length,
        (i) => i
      ).shuffleRng(rng))
    );
  }

  OrErr<void, transport.Error> validateResumptionFrom(TransportParameters cached) {
    if (
      cached.activeConnectionIdLimit > activeConnectionIdLimit
      || cached.initialMaxData > initialMaxData
      || cached.initialMaxStreamDataBidiLocal > initialMaxStreamDataBidiLocal
      || cached.initialMaxStreamDataBidiRemote > initialMaxStreamDataBidiRemote
      || cached.initialMaxStreamDataUni > initialMaxStreamDataUni
      || cached.initialMaxStreamsBidi > initialMaxStreamsBidi
      || cached.initialMaxStreamsUni > initialMaxStreamsUni
      || (cached.maxDatagramFrameSize ?? const VarInt(.zero)) > (maxDatagramFrameSize ?? const VarInt(.zero))
      || cached.greaseQuicBit && !greaseQuicBit
    ) {
      return .err(.transport(
        .protocolViolation(),
        "0-RTT accepted with incompatible transport parameters"
      ));
    }
    return .ok(null);
  }

  Uint64 issueCidsLimit() {
    return BMath.min([ activeConnectionIdLimit, locCidCounet.asVarInt ]).inner;
  }

  void write(SizedBufferWritter writter) {
    final ids = writeOrder ?? Uint8List.fromList(List.generate(
      TransportParameterId.supported.length,
      (i) => i
    ));

    for (final idx in ids) {
      final id = TransportParameterId.supported[idx];
      final write_varint = (VarInt v) {
        writter.writeVar(Uint64(v.size()));
        writter.writeVar(v.inner);
      };
      final write_params = (VarInt value, VarInt def) {
        if (value == def) return;
        final v = value;
        writter.writeVar(Uint64(v.size()));
        writter.writeVar(v.inner);
      };
      id.when(
        reservedTransportParameter: () {
          if (greaseTransportParameter == null) return;
          writter.writeVar(Uint64(id.value));
          greaseTransportParameter!.write(writter);
        },
        statelessResetToken: () {
          if (statelessResetToken == null) return;
          final x = statelessResetToken!;
          writter.writeVar(Uint64(id.value));
          writter.writeVar(const Uint64(16));
          writter.writeBytes(x.token);
        },
        disableActiveMigration: () {
          if (!disableActiveMigration) return;
          writter.writeVar(Uint64(id.value));
          writter.writeVar(Uint64.zero);
        },
        maxDatagramFrameSize: () {
          if (maxDatagramFrameSize == null) return;
          writter.writeVar(Uint64(id.value));
          write_varint(maxDatagramFrameSize!);
        },
        preferredAddress: () {
          if (preferredAddress == null) return;
          final x = preferredAddress!;
          writter.writeVar(Uint64(id.value));
          writter.writeVar(Uint64(x.wireSize()));
          preferredAddress!.write(writter);
        },
        originalDestinationConnectionId: () {
          if (originalDstCid == null) return;
          final cid = originalDstCid!;
          writter.writeVar(Uint64(id.value));
          writter.writeVar(Uint64(cid.len));
          writter.writeBytes(cid.bytes);
        },
        initialSourceConnectionId: () {
          if (initialSrcCid == null) return;
          final cid = initialSrcCid!;
          writter.writeVar(Uint64(id.value));
          writter.writeVar(Uint64(cid.len));
          writter.writeBytes(cid.bytes);
        },
        retrySourceConnectionId: () {
          if (retrySrcCid == null) return;
          final cid = retrySrcCid!;
          writter.writeVar(Uint64(id.value));
          writter.writeVar(Uint64(cid.len));
          writter.writeBytes(cid.bytes);
        },
        greaseQuicBit: () => () {
          if (!greaseQuicBit) return;
          writter.writeVar(Uint64(id.value));
          writter.writeVar(Uint64.zero);
        },
        minAckDelayDraft07: () {
          if (minAckDelay == null) return;
          final x = minAckDelay!;
          writter.writeVar(Uint64(id.value));
          write_varint(x);
        },

        // 带默认值的
        maxIdleTimeout: () => write_params(maxIdleTimeout, _default.maxIdleTimeout),
        maxUdpPayloadSize: () => write_params(maxUdpPayloadSize, _default.maxUdpPayloadSize),
        initialMaxData: () => write_params(initialMaxData, _default.initialMaxData),
        initialMaxStreamDataBidiLocal: () => write_params(initialMaxStreamDataBidiLocal, _default.initialMaxStreamDataBidiLocal),
        initialMaxStreamDataBidiRemote: () => write_params(initialMaxStreamDataBidiRemote, _default.initialMaxStreamDataBidiRemote),
        initialMaxStreamDataUni: () => write_params(initialMaxStreamDataUni, _default.initialMaxStreamDataUni),
        initialMaxStreamsBidi: () => write_params(initialMaxStreamsBidi, _default.initialMaxStreamsBidi),
        initialMaxStreamsUni: () => write_params(initialMaxStreamsUni, _default.initialMaxStreamsUni),
        ackDelayExponent: () => write_params(ackDelayExponent, _default.ackDelayExponent),
        maxAckDelay: () => write_params(maxAckDelay, _default.maxAckDelay),
        activeConnectionIdLimit: () => write_params(activeConnectionIdLimit, _default.activeConnectionIdLimit),
      );
    }
  }

  static OrErr<TransportParameters, Error> read(Side side, SizedBufferReader reader) {
    final params = TransportParameters();

    final got = Set<TransportParameterId>();
    while (reader.remainingLength != 0) {
      VarInt idx, len;
      try {
        idx = reader.tryReadVar().takeOk();
        len = reader.tryReadVar().takeOk();
      } catch (_) {
        return .err(.malformed);
      }
      if (len.inner.asInt < reader.remainingLength) {
        return .err(.malformed);
      }

      final id = TransportParameterId.idPair[idx.inner.asInt];
      if (id == null) {
        // 忽略未知的传输参数
        reader.readFixed(len.inner.asInt);
        continue;
      }

      Error? throwErr2;
      final parse_params = (void Function(VarInt) setter) {
        final _value = reader.tryReadVar();
        if (_value.isErr) return throwErr2 = .malformed;
        final value = _value.takeOk();
        if (len != value.size() || got.contains(id)) return throwErr2 = .malformed;
        setter(value);
        got.add(id);
      };

      final skip = () {
        reader.readFixed(len.inner.asInt);
      };
      
      final throwErr = id.when<Error?>(
        originalDestinationConnectionId: () {
          final _cid = decodeCid(len.inner.asInt, params.originalDstCid, reader);
          if (_cid.isErr) return _cid.error;
          params.originalDstCid = _cid.takeOk();
          return null;
        },
        statelessResetToken: () {
          if (len.inner != const Uint64(16) || params.statelessResetToken != null) {
            return .malformed;
          }
          final tok = Uint8List(maxCidSize);
          tok.setAll(0, reader.readBytes(tok.length));
          params.statelessResetToken = ResetToken(tok);
          return null;
        },
        disableActiveMigration: () {
          if (len.inner != .zero || params.disableActiveMigration) {
            return .malformed;
          }
          params.disableActiveMigration = true;
          return null;
        },
        preferredAddress: () {
          if (params.preferredAddress != null) {
            return .malformed;
          }
          final _x = PreferredAddress.read(reader);
          if (_x.isErr) return _x.error;
          params.preferredAddress = _x.takeOk();
          return null;
        },
        initialSourceConnectionId: () {
          final _cid = decodeCid(len.inner.asInt, params.initialSrcCid, reader);
          if (_cid.isErr) return _cid.error;
          params.initialSrcCid = _cid.takeOk();
          return null;
        },
        retrySourceConnectionId: () {
          final _cid = decodeCid(len.inner.asInt, params.retrySrcCid, reader);
          if (_cid.isErr) return _cid.error;
          params.retrySrcCid = _cid.takeOk();
          return null;
        },
        maxDatagramFrameSize: () {
          if (len.inner > const Uint64(8) || params.maxDatagramFrameSize != null) {
            return .malformed;
          }
          final _x = reader.tryReadVar();
          if (_x.isErr) return .malformed;
          params.maxDatagramFrameSize = _x.takeOk();
          return null;
        },
        greaseQuicBit: () {
          if (len != 0) {
            return .malformed;
          }
          params.greaseQuicBit = true;
          return null;
        },
        minAckDelayDraft07: () {
          final _x = reader.tryReadVar();
          if (_x.isErr) return .malformed;
          params.minAckDelay = _x.takeOk();
          return null;
        },

        // 带默认值
        maxIdleTimeout: () => parse_params((v) => params.maxIdleTimeout = v),
        maxUdpPayloadSize: () => parse_params((v) => params.maxUdpPayloadSize = v),
        initialMaxData: () => parse_params((v) => params.initialMaxData = v),
        initialMaxStreamDataBidiLocal: () => parse_params((v) => params.initialMaxStreamDataBidiLocal = v),
        initialMaxStreamDataBidiRemote: () => parse_params((v) => params.initialMaxStreamDataBidiRemote = v),
        initialMaxStreamDataUni: () => parse_params((v) => params.initialMaxStreamDataUni = v),
        initialMaxStreamsBidi: () => parse_params((v) => params.initialMaxStreamsBidi = v),
        initialMaxStreamsUni: () => parse_params((v) => params.initialMaxStreamsUni = v),
        ackDelayExponent: () => parse_params((v) => params.ackDelayExponent = v),
        maxAckDelay: () => parse_params((v) => params.maxAckDelay = v),
        activeConnectionIdLimit: () => parse_params((v) => params.activeConnectionIdLimit = v),

        // 跳过
        reservedTransportParameter: () => skip()
      );

      if (throwErr2 != null) {
        return .err(throwErr2);
      }

      if (throwErr != null) {
        return .err(throwErr);
      }
    }

    if (
      params.ackDelayExponent.inner > const Uint64(20)
      || params.maxAckDelay.inner >= const Uint64(1 << 14)
      || params.activeConnectionIdLimit.inner < const Uint64(2)
      || params.maxUdpPayloadSize.inner < const Uint64(1200)
      || params.initialMaxStreamDataUni.inner > const Uint64(maxStreamCount)
      || params.initialMaxStreamsUni.inner > const Uint64(maxCidSize)
      || params.minAckDelay == null
        ? false
        : (params.minAckDelay! > params.maxAckDelay * const VarInt(Uint64(1_000)))
      || (
        side.isServer
        && (
          params.originalDstCid != null
          || params.preferredAddress != null
          || params.retrySrcCid != null
          || params.statelessResetToken != null
        ))
      || params.preferredAddress == null
        ? false
        : params.preferredAddress!.connectionId.bytes.isEmpty
    ) {
      return .err(.illegalValue);
    }

    return .ok(params);
  }
}

@freezed
abstract class PreferredAddress with _$PreferredAddress {
  const factory PreferredAddress({
    SocketAddr? addr4,
    SocketAddr? addr6,
    required ConnectionId connectionId,
    required ResetToken statelessResetToken
  }) = _PreferredAddress;

  int wireSize() => 4 + 2 + 16 + 2 + 1 + connectionId.len + 16;

  void write(SizedBufferWritter writter) {
    writter.writeBytes((addr4?.ip ?? .anyIPv4).rawAddress);
    writter.writeUint16(addr4?.port ?? 0);
    writter.writeBytes((addr6?.ip ?? .anyIPv6).rawAddress);
    writter.writeUint16(addr6?.port ?? 0);
    writter.writeUint8(connectionId.len);
    writter.writeBytes(Uint8List.view(connectionId.bytes.buffer, 0, connectionId.len));
    writter.writeBytes(statelessResetToken.token);
  }

  static OrErr<PreferredAddress, Error> read(SizedBufferReader reader) {
    IpAddr ip4, ip6;
    int port4, port6, cidLen;
    try {
      ip4 = reader.tryReadIpv4().takeOk();
      port4 = reader.tryReadUint16().takeOk();
      ip6 = reader.tryReadIpv6().takeOk();
      port6 = reader.tryReadUint16().takeOk();
      cidLen = reader.tryReadUint8().takeOk();
    } catch (_) {
      return .err(.malformed);
    }
    if (reader.remainingLength < cidLen || cidLen > maxCidSize) {
      return .err(.malformed);
    }
    final stage = Uint8List(maxCidSize);
    stage.setAll(0, reader.readFixed(cidLen));
    final cid = ConnectionId.new_(Uint8List.view(stage.buffer, 0, cidLen));
    if (reader.remainingLength < 16) {
      return .err(.malformed);
    }
    final token = Uint8List(resetTokenSize);
    token.setAll(0, reader.readFixed(resetTokenSize));
    final addr4 = ip4 == .anyIPv4 && port4 == 0 ? null : SocketAddr.v4(ip4, port4);
    final addr6 = ip6 == .anyIPv6 && port6 == 0 ? null : SocketAddr.v4(ip6, port6);
    if (addr4 == null && addr6 == null) {
      return .err(.illegalValue);
    }
    return .ok(PreferredAddress(
      connectionId: cid,
      statelessResetToken: ResetToken(token),
      addr4: addr4,
      addr6: addr6
    ));
  }
}

enum Error implements Comparable<Error>, Exception {
  illegalValue("parameter had illegal value"),
  malformed("parameters were malformed");

  const Error(this.content);
  final String content;

  @override
  int compareTo(Error other) => index - other.index;
}

extension ToTransportError on Error {
  transport.Error get asTransportError => switch (this) {
    .illegalValue => .transport(.transportParameterError(), "illegal value"),
    .malformed => .transport(.transportParameterError(), "malformed")
  };
}

@freezed
abstract class ReservedTransportParameter with _$ReservedTransportParameter {
  static const maxPayloadLen = 16;

  const factory ReservedTransportParameter({
    required VarInt id,
    required Uint8List payload,
    required int payloadLen
  }) = _ReservedTransportParameter;

  static ReservedTransportParameter random(RngCore rng) {
    final id = generateReservedId(rng);
    final payloadLen = rng.randomRange<int>(0, maxPayloadLen);
    final payload = Uint8List(payloadLen);
    rng.fillBytes(payload);
    return ReservedTransportParameter(
      id: id,
      payload: payload,
      payloadLen: payloadLen
    );
  }

  void write(BufferWritter writter) {
    writter.writeVar(id.inner);
    writter.writeVar(Uint64(payloadLen));
    writter.writeBytes(Uint8List.view(payload.buffer, 0, payloadLen));
  }

  static VarInt generateReservedId(RngCore rng) {
    final rand = rng.randomRange<Uint64>(.zero, (Uint64.one << 62) - const Uint64(27));
    final id = rand - (rand % const Uint64(31)) + const Uint64(27);
    assert(id % const Uint64(31) == const Uint64(27), "generated id does not have the form of 31 * N + 27");
    return VarInt.fromUint64(id)
      .takeOk("generated id does fit into range of allowed transport parameter IDs: [0; 2^62)");
  }
}

@freezed
abstract class TransportParameterId with _$TransportParameterId {
  const TransportParameterId._();
  const factory TransportParameterId.originalDestinationConnectionId() = _TpiOriginalDestinationConnectionId;
  const factory TransportParameterId.maxIdleTimeout() = _TpiMaxIdleTimeout;
  const factory TransportParameterId.statelessResetToken() = _TpiStatelessResetToken;
  const factory TransportParameterId.maxUdpPayloadSize() = _TpiMaxUdpPayloadSize;
  const factory TransportParameterId.initialMaxData() = _TpiInitialMaxData;
  const factory TransportParameterId.initialMaxStreamDataBidiLocal() = _TpiInitialMaxStreamDataBidiLocal;
  const factory TransportParameterId.initialMaxStreamDataBidiRemote() = _TpiInitialMaxStreamDataBidiRemote;
  const factory TransportParameterId.initialMaxStreamDataUni() = _TpiInitialMaxStreamDataUni;
  const factory TransportParameterId.initialMaxStreamsBidi() = _TpiInitialMaxStreamsBidi;
  const factory TransportParameterId.initialMaxStreamsUni() = _TpiInitialMaxStreamsUni;
  const factory TransportParameterId.ackDelayExponent() = _TpiAckDelayExponent;
  const factory TransportParameterId.maxAckDelay() = _TpiMaxAckDelay;
  const factory TransportParameterId.disableActiveMigration() = _TpiDisableActiveMigration;
  const factory TransportParameterId.preferredAddress() = _TpiPreferredAddress;
  const factory TransportParameterId.activeConnectionIdLimit() = _TpiActiveConnectionIdLimit;
  const factory TransportParameterId.initialSourceConnectionId() = _TpiInitialSourceConnectionId;
  const factory TransportParameterId.retrySourceConnectionId() = _TpiRetrySourceConnectionId;
  const factory TransportParameterId.reservedTransportParameter() = _TpiReservedTransportParameter;
  const factory TransportParameterId.maxDatagramFrameSize() = _TpiMaxDatagramFrameSize;
  const factory TransportParameterId.greaseQuicBit() = _TpiGreaseQuicBit;
  const factory TransportParameterId.minAckDelayDraft07() = _TpiMinAckDelayDraft07;

  static const idPair = <int, TransportParameterId>{
    0x00: .originalDestinationConnectionId(),
    0x01: .maxIdleTimeout(),
    0x02: .statelessResetToken(),
    0x03: .maxUdpPayloadSize(),
    0x04: .initialMaxData(),
    0x05: .initialMaxStreamDataBidiLocal(),
    0x06: .initialMaxStreamDataBidiRemote(),
    0x07: .initialMaxStreamDataUni(),
    0x08: .initialMaxStreamsBidi(),
    0x09: .initialMaxStreamsUni(),
    0x0A: .ackDelayExponent(),
    0x0B: .maxAckDelay(),
    0x0C: .disableActiveMigration(),
    0x0D: .preferredAddress(),
    0x0E: .activeConnectionIdLimit(),
    0x0F: .initialSourceConnectionId(),
    0x10: .retrySourceConnectionId(),
    0x1B: .reservedTransportParameter(),
    0x20: .maxDatagramFrameSize(),
    0x2AB2: .greaseQuicBit(),
    0xFF04DE1B: .minAckDelayDraft07()
  };

  static const List<TransportParameterId> supported = [
    .maxIdleTimeout(),
    .maxUdpPayloadSize(),
    .initialMaxData(),
    .initialMaxStreamDataBidiLocal(),
    .initialMaxStreamDataBidiRemote(),
    .initialMaxStreamDataUni(),
    .initialMaxStreamsBidi(),
    .initialMaxStreamsUni(),
    .ackDelayExponent(),
    .maxAckDelay(),
    .activeConnectionIdLimit(),
    .reservedTransportParameter(),
    .statelessResetToken(),
    .disableActiveMigration(),
    .maxDatagramFrameSize(),
    .preferredAddress(),
    .originalDestinationConnectionId(),
    .initialSourceConnectionId(),
    .retrySourceConnectionId(),
    .greaseQuicBit(),
    .minAckDelayDraft07(),
  ];

  int get value => idPair.entries.firstWhere((e) => e.value == this).key;
}

OrErr<ConnectionId, Error> decodeCid(int len, ConnectionId? value, SizedBufferReader reader) {
  if (len > maxCidSize || value != null || reader.remainingLength < len) {
    return .err(.malformed);
  }
  return .ok(ConnectionId.fromBuffer(reader, len));
}