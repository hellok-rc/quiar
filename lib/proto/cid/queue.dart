import "package:freezed_annotation/freezed_annotation.dart";
import "package:quiar/proto/quic.dart";

part "queue.freezed.dart";

typedef CidData = (ConnectionId, ResetToken?);

@freezed
abstract class CidQueue with _$CidQueue {
  static const len = 5;

  const factory CidQueue({
    required List<CidData?> buffer,
    required int cursor,
    required BigInt offset,
  }) = _CidQueue;
}