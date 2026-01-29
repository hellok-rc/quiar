
import "dart:io";

typedef IpAddr = InternetAddress;
class SocketAddr {
  late final InternetAddressType type;
  late final IpAddr ip;
  late final int port;
  SocketAddr.v4(this.ip, this.port) : type = .IPv4 {
    assert(ip.type == type);
  }
  SocketAddr.v6(this.ip, this.port) : type = .IPv6 {
    assert(ip.type == type);
  }
}