import "util.dart" show Uint64;
import "varint.dart" show VarInt;

bool _largeThan<T>(T a, T b) {
  final type = T.runtimeType;
  if (type is int) {
    return (a as int) > (b as int);
  } else if (type is Uint64) {
    return (a as Uint64) > (b as Uint64);
  } else if (type is VarInt) {
    return (a as VarInt) > (b as VarInt);
  } else if (type is double) {
    return (a as double) > (b as double);
  } else {
    throw UnimplementedError("Cannot comparate $type");
  }
}

class BMath {
  static T min<T>(List<T> list) {
    if (list.isEmpty) throw ArgumentError("List must have more than 1 item");
    if (list.length == 1) return list.first;
    T value = list.first;
    for (int i = 1; i < list.length; i++) {
      final item = list[i];
      if (_largeThan<T>(item, value)) {
        value = item;
      }
    }
    return value;
  }
}

final bmath = BMath;