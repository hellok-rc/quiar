import "package:benchmark_harness/benchmark_harness.dart";
import "uint64.dart" show generateBase;

final calcs = <(String, void Function(BigInt, BigInt))>[
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

class BigIntBenchmark extends BenchmarkBase {
  BigIntBenchmark() : super("BigInt${calcs[calcIndex].$1}");

  static void main() {
    for (int i = 0; i < calcs.length; i++) {
      BigIntBenchmark().report();
    }
  }

  late final BigInt baseA, baseB; 

  @override
  void run() {
    for (int i = 0; i <= count; i++) {
      calcs[calcIndex].$2(baseA, baseB);
    }
  }

  @override
  void setup() {
    baseA = generateBase().asBigInt;
    baseB = generateBase().asBigInt;
  }

  @override
  void teardown() {
    calcIndex += 1;
  }
}