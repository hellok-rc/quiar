import "dart:typed_data";
import "package:quiar/proto/quic.dart";

abstract class TokenLog {
  OrErr<void, TokenReuseError> checkAndInsert(
    BigInt nonce,
    DateTime issued,
    Duration lifetime,
  );
}

class TokenReuseError implements Exception {
  @override
  String toString() => "Error for when a validation token may have been reused";
}

class NoneTokenLog implements Exception {
  @override
  String toString() => "Null implementation of [`TokenLog`], which never accepts tokens";
}

abstract class TokenStore {
  void insert(String serverName, Uint8List token);
  Uint8List? take(String serverName);
}

// 重置Token
// 用于通知断开连接
class ResetToken {
  late final Uint8List token;
  ResetToken(this.token);

  ResetToken.new_(HmacKey key, ConnectionId id) {
    final signature = Uint8List(key.signatureLen().toInt());
    key.sign(id.bytes, signature);
    token = Uint8List(resetTokenSize);
    token.setAll(0, Uint8List.view(signature.buffer, 0, resetTokenSize));
  }
}