
abstract class Controller {
  void onSent(Stopwatch since, BigInt bytes, BigInt lastPacketNumber);
}

abstract class ControllerFactory {}