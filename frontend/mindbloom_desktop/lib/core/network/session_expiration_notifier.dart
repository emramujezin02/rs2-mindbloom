import 'dart:async';

class SessionExpirationNotifier {
  SessionExpirationNotifier._();

  static final StreamController<void> _controller =
      StreamController<void>.broadcast();

  static Stream<void> get stream {
    return _controller.stream;
  }

  static void notifyExpired() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }
}
