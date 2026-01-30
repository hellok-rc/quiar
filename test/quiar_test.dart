// import "package:quiar/proto/quic.dart";
import "package:quiar/proto/util.dart";
import "package:quiar/proto/rand.dart";
import "dart:core";

void main() {
  // BigInt.from(Uint8List(3))
  // ByteData.view(Uint8List(8).buffer).;
  // print("${110011.asBin} ${int.parse('110011', radix: 2)}");
  // print(Uint64(22244442) - Uint64(2));
  // final n = int.parse('110011', radix: 2);
  // print(n & 1);
  // print(n & 2);
  // print(n & 3);
  final rng = Rng();
  final counts = Map<int, int>();
  for (int i = 0; i < 10000_0000; i++) {
    final res = rng.randomRange<Uint64>(Uint64.zero, Uint64(0x7FFFFFFFFFFFFFFF));
    final len = res.toString().length;
    counts[len] = (counts[len] ?? 0) + 1;
  }
  final c = counts.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  c.forEach((e) => print("${e.key} 位出现 ${e.value} 次"));
}
