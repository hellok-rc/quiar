import "package:freezed_annotation/freezed_annotation.dart";

import "dart:io" show InternetAddress;
import "./util.dart";
import "./buffer.dart";
import "./varint.dart";
import "./coding.dart";

export "./config/config.dart" hide ServerConfig, ClientConfig;
export "./config/transport.dart";

export "./connection/log.dart";

export "./cid/queue.dart";
export "./cid/generator.dart";

export "./transport/error.dart" hide Error, TransportError;
export "./transport/parameters.dart";

export "./math.dart" show BMath;
export "./crypto.dart" hide ServerConfig, ClientConfig;
export "./addr.dart";
export "./rand.dart";
export "./util.dart";
export "./buffer.dart";
export "./coding.dart";
export "./shared.dart";
export "./token.dart";
export "./varint.dart";
export "./congestion.dart";
export "./frame.dart" hide FrameType;

part "quic.freezed.dart";

const DefaultSupportedVersions = [
  0x00000001,
  0xff00_001d,
  0xff00_001e,
  0xff00_001f,
  0xff00_0020,
  0xff00_0021,
  0xff00_0022,
];

@freezed
abstract class Side with _$Side {
  const Side._();
  const factory Side.client() = _ClientSide;
  const factory Side.server() = _ServerSide;

  static const sidePair = <int, Side>{
    0: .client(),
    1: .server()
  };

  int get value => sidePair.entries.firstWhere((e) => e.value == this).key;
  bool get isClient => this == .client();
  bool get isServer => this == .server();
  Side get another => sidePair[1 - value]!;
}

@freezed
abstract class Dir with _$Dir {
  const Dir._();
  const factory Dir.bi() = _BiDir;
  const factory Dir.uni() = _UniDir;

  static const sidePair = <int, Dir>{
    0: .bi(),
    1: .uni()
  };

  int get value => sidePair.entries.firstWhere((e) => e.value == this).key;

  static Stream<Dir> getStream() => Stream.fromIterable([ .bi(), .uni() ]);

  @override
  String toString() => when(
    bi: () => "bidirectional",
    uni: () => "unidirectional"
  );
}

class StreamId {
  late final Uint64 id;
  StreamId(this.id);
  StreamId.from(int v) : id = Uint64(v);
  StreamId.new_(Side initiator, Dir dir, Uint64 index) {
    id = (index << 2) | (Uint64(dir.value) << 1) | Uint64(initiator.value);
  }

  Side initiator() =>
    id & .one == 0 ? .client() : .server();

  Dir dir() =>
    id & .two == 0 ? .bi() : .uni();
  
  Uint64 index() => id >> 2;
  
  @override
  String toString() {
    final initiator = this.initiator().when(
      client: () => "client",
      server: () => "server"
    );
    final dir = this.dir().toString();
    return "$initiator $dir stream ${index()}";
  }
}

extension StreamIdToVarInt on StreamId {
  VarInt toVarInt() => VarInt(id);
}

extension VarIntToStreamId on VarInt {
  StreamId toStreamId() =>
    StreamId(inner);
}

OrErr<StreamId, UnexpectedEnd> decodeStreamId(SizedBufferReader reader) {
  final (r, e) = decodeVarInt(reader).orErr;
  if (r != null) {
    return .ok(r.toStreamId());
  }
  return .err(e!);
}

void encodeStreamId(StreamId id, SizedBufferWritter writter) {
  encodeVarInt(id.toVarInt(), writter);
}

@freezed
abstract class Transmit with _$Transmit {
  const factory Transmit({
    required InternetAddress destination,
    required BigInt size,
    required BigInt? segmentSize,
    required InternetAddress? srcIp,
  }) = _Transmit;
}

const locCidCounet = 8;
const resetTokenSize = 16;
const maxCidSize = 20;
const minInitialSize = 1200;
const initialMtu = 1200;
const maxUdpPayload = 65527;
const timerGranularity = Duration(milliseconds: 1);
const maxStreamCount = 1 << 60;