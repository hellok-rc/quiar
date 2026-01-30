import "dart:math";
import "package:quiar/proto/util.dart";
import "package:benchmark_harness/benchmark_harness.dart";

Uint64 generateBase() {
  return Uint64(Random().nextInt(4294967296));
}

final calcs = <(String, void Function(Uint64, Uint64))>[
  ("Add", (a, b) => a + b),
  ("Sub", (a, b) => a - b),
  ("Mult", (a, b) => a * b),
  ("Div", (a, b) => a ~/ b),
  ("Pos", (a, b) => a | b),
  ("And", (a, b) => a & b),
  ("Xor", (a, b) => a ^ b),
  ("NonPos", (a, _) => ~a),
  ("LargeThan", (a, b) => a > b),
  ("Assign", (a, b) => a == b)
];
int calcIndex = 0;

const count = 1000;

class Uint64Benchmark extends BenchmarkBase {
  Uint64Benchmark() : super("Uint64${calcs[calcIndex].$1}");

  static void main() {
    for (int i = 0; i < calcs.length; i++) {
      Uint64Benchmark().report();
    }
  }

  late final Uint64 baseA, baseB; 

  @override
  void run() {
    for (int i = 0; i <= count; i++) {
      calcs[calcIndex].$2(baseA, baseB);
    }
  }

  @override
  void setup() {
    baseA = generateBase();
    baseB = generateBase();
  }

  @override
  void teardown() {
    calcIndex += 1;
  }
}