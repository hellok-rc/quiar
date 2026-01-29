import "dart:typed_data";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:quiar/proto/quic.dart";

part "crypto.freezed.dart";

abstract class Session {
  // 从 ConnectionId 创建密钥列表
  Keys initialKeys(ConnectionId dstCid, Side side);

  // 获取握手协商内容，如果已握手返回 null
  Object? handshakeData();

  // 获取对方 identity
  Object? peerIdentity();

  // 0-RTT 密钥
  // Client 可用于确认握手完成前是否可用密钥发送数据
  // 如果是新密钥返回 null
  (HeaderKey, PacketKey)? earlyCrypto();

  // 对方是否接受 0-RTT 密钥加密的数据
  bool? earlyDataAccepted();

  // 读取握手数据
  OrErr<bool, TransportError> readHandshake(Uint8List bytes);

  // QUIC 传输参数
  OrErr<TransportParameters?, TransportError> transportParameters();

  // 写入握手数据
  Keys? writeHandshake(Uint8List bytes);

  // 获取下次密钥更新的密钥
  KeyPair<PacketKey>? next1RttKeys();

  OrErr<void, ExportKeyingMaterialError> exportKeyingMaterial(
    Uint8List output,
    Uint8List label,
    Uint8List context
  );
}

@freezed
abstract class KeyPair<T> with _$KeyPair {
  const factory KeyPair({
    required T local,
    required T remote
  }) = _KeyPair;
}

@freezed
abstract class Keys with _$Keys {
  const factory Keys({
    required KeyPair<HeaderKey> header,
    required KeyPair<PacketKey> packet
  }) = _Keys;
}

abstract class ClientConfig {
  OrErr<Session, ConnectError> startSession(
    int version,
    String serverName,
    TransportParameters params
  );
}

abstract class ServerConfig {
  OrErr<Keys, UnsupportedVersion> initialKeys(int version, ConnectionId dstCid);
  Uint8List retryTag(int version, ConnectionId origDstCid, Uint8List packet);
  Session startSession(
    int version,
    TransportParameters params
  );
}

abstract class PacketKey {
  void encrypt(BigInt packet, Uint8List bytes, int headerLen);
  OrErr<void, CryptoError> decrypt(BigInt packet, Uint8List header, SizedBufferWritter payload);
  int tagLen();
  BigInt confidentialityLimit();
  BigInt integrityLimit();
}

abstract class HeaderKey {
  void decrypt(int pnOffset, Uint8List packet);
  void encrypt(int pnOffset, Uint8List packet);
  int sampleSize();
}

abstract class HmacKey {
  void sign(Uint8List data, Uint8List signatureOut);
  BigInt signatureLen();
  OrErr<void, CryptoError> verify(Uint8List data, Uint8List signature);
}

class ExportKeyingMaterialError implements Exception {
  @override
  String toString() => "Requested output length is too large";
}

abstract class HandshakeTokenKey {
  AeadKey aeadFromHkdf(Uint8List randomBytes);
}

abstract class AeadKey {
  OrErr<void, CryptoError> seal(Uint8List data, Uint8List additionalData);
  OrErr<Uint8List, CryptoError> open(
    Uint8List data,
    Uint8List additionalData
  );
}

class CryptoError implements Exception {
  @override
  String toString() => "Generic crypto errors";
}

class UnsupportedVersion implements Exception {
  @override
  String toString() => "Error indicating that the specified QUIC version is not supported";
}

extension UnsupportedVersionToConnectError on UnsupportedVersion {

}