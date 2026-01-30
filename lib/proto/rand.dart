import "dart:typed_data";
import "dart:math" show Random;
import "util.dart" show Uint64;

// 兼容 Rust 的底层
abstract class RngBase {
  int nextU32();
  Uint64 nextU64();
  void fillBytes(Uint8List bytes);
}

// 生成一个范围随机值
// 返回 null 代表未实现
abstract class BaseGenerator {
  // [min, max)
  T? generate<T>(RngBase rng, [ T? min, T? max ]);
}

class StandardGenerator implements BaseGenerator {
  static const i64max = 0x7FFFFFFFFFFFFFFF;
  static const u32max = 0xFFFFFFFF;
  static const u32bmax = Uint64(u32max);
  static final u64max = (Uint64.one << 64) - .one;
  Random get random {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  T? generate<T>(_, [ T? min, T? max ]) {
    switch (T) {
      case int:
        final (min_, max_) = (min ?? 0, max ?? i64max) as (int, int);
        final value = random.nextInt(max_ - min_) + min_;
        return value as T;
      case bool:
        if (min != null || max != null) return null;
        return random.nextBool() as T;
      case double:
        if (min != null || max != null) return null;
        return random.nextDouble() as T;
      case Uint64:
        // 视为 u64
        final (min_, max_) = (min ?? Uint64.zero, max ?? u64max) as (Uint64, Uint64);
        if (min_ < .zero || max_ > u64max) return null;
        // 采用高位低位组合进行随机数生成
        final range = max_ - min_;
        final (rh, rl) = (
          (range & const Uint64(u32max) << 32) >> 32,
          range & const Uint64(u32max)
        );
        final Uint64 oh = random.nextBool()
          ? .zero
          : Uint64(rh.asInt == 0 ? 0 : random.nextInt(rh.asInt));
        final int olMax = (rh == oh)
          ? rl.asInt
          : u32max;
        final ol = Uint64(olMax == 0 ? 0 : random.nextInt(olMax));
        final result = min_ + ((oh << 32) | ol);
        return result as T;
      default:
        return null;
    }
  }
}

abstract class RngCore extends RngBase {
  T random<T>();
  Iterable<T> randomIter<T>();
  T randomRange<T>(T min, T max);
  bool randomBool();
  bool randomRatio(double ratio);

}

class Rng implements RngCore {
  late final BaseGenerator generator;
  Rng([ BaseGenerator? g ]) : generator = g ?? StandardGenerator();

  T _genOrThrow<T>([ T? min, T? max ]) {
    final result = generator.generate<T>(this, min, max);
    if (result == null) {
      throw UnimplementedError("There is no implementation of a random generator for this type");
    }
    return result;
  }

  @override
  void fillBytes(Uint8List bytes) {
    final iter = Iterable.generate(bytes.length, (_) => _genOrThrow<int>(0, 0xFF));
    bytes.setAll(0, iter);
  }

  @override
  int nextU32() => _genOrThrow<int>(0, 0xFFFFFFFF);

  @override
  Uint64 nextU64() => _genOrThrow<Uint64>();

  @override
  T random<T>() => _genOrThrow<T>();

  @override
  Iterable<T> randomIter<T>() sync* {
    while (true) {
      yield _genOrThrow<T>();
    }
  }

  @override
  T randomRange<T>(T min, T max) => _genOrThrow<T>(min, max);
  
  @override
  bool randomBool() => _genOrThrow<bool>();

  @override
  bool randomRatio(double ratio) => _genOrThrow<double>() < ratio;
}

// 对列表实现 Fisher-Yates 洗牌算法
extension RngShuffleList<T> on List<T> {
  // inPlace 为 true 时修改原列表
  List<T> shuffleRng(RngCore rng, {bool inPlace = true}) {
    final list = inPlace ? this : List<T>.from(this);
    final length = list.length;
    for (int i = length - 1; i > 0; i--) {
      final j = rng.randomRange<int>(0, i + 1);
      final temp = list[i];
      list[i] = list[j];
      list[j] = temp;
    }
    return list;
  }
}