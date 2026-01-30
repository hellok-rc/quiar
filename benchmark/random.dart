import "package:benchmark_harness/benchmark_harness.dart";
import "package:quiar/proto/util.dart";
import "package:quiar/proto/rand.dart";

const count = 1000;

class Uint64RandomBenchmark extends BenchmarkBase {
  Uint64RandomBenchmark() : super("Uint64Random");

  static void main() {
    Uint64RandomBenchmark().report();
  }

  @override
  void run() {
    final rng = Rng();
    for (int i = 0; i <= count; i++) {
      print(rng.random<Uint64>());
    }
  }

  @override
  void setup() {}
  
  @override
  void teardown() {}
}