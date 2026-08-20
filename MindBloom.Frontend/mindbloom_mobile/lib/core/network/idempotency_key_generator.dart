import 'dart:math';

class IdempotencyKeyGenerator {
  IdempotencyKeyGenerator._();

  static final Random _random = Random.secure();

  static String generate() {
    final timestamp = DateTime.now().toUtc().microsecondsSinceEpoch;

    final randomPart = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

    return '$timestamp-$randomPart';
  }
}
