import 'package:flutter/foundation.dart';

final Stopwatch _startupStopwatch = Stopwatch()..start();

int _nextHttpRequestId = 0;
int _nextRefreshRequestId = 0;

int nextHttpRequestId() {
  return ++_nextHttpRequestId;
}

int nextRefreshRequestId() {
  return ++_nextRefreshRequestId;
}

void logStartup(String message) {
  logDebug('MOBILE STARTUP', message);
}

void logHttp(int requestId, String message) {
  logDebug('MOBILE HTTP #$requestId', message);
}

void logRefresh(int requestId, String message) {
  logDebug('MOBILE REFRESH #$requestId', message);
}

void logRouter(String message) {
  logDebug('ROUTER', message);
}

void logWidget(String message) {
  logDebug('MOBILE WIDGET', message);
}

void logDebug(String category, String message) {
  if (!kDebugMode) {
    return;
  }

  debugPrint(
    '[$category +${_startupStopwatch.elapsedMilliseconds}ms] $message '
    'at=${DateTime.now().toIso8601String()}',
  );
}
