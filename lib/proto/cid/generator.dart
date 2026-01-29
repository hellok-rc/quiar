import "package:quiar/proto/quic.dart";

abstract class ConnectionIdGenerator {
  ConnectionId generateCid();
  OrErr<void, InvalidCid> validate(ConnectionId cid);
  int cidLen();
  Duration? cidLifetime();
}

class InvalidCid implements Exception {
  @override
  String toString() => "The connection ID was not recognized by the [`ConnectionIdGenerator`]";
}