class AppErrorMessage {
  AppErrorMessage._();

  static const String generic = 'Something went wrong. Please try again.';

  static const String offline =
      'There is no internet connection. Check your connection and try again.';

  static const String timeout = 'The request took too long. Please try again.';

  static const String serverUnavailable =
      'The server is currently unavailable. Please try again later.';

  static const String unauthorized =
      'Your session has expired. Please sign in again.';

  static const String forbidden =
      'You do not have permission to perform this action.';

  static const String notFound = 'The requested resource could not be found.';

  static String from(Object? error, {String fallback = generic}) {
    if (error == null) {
      return fallback;
    }

    final originalMessage = error.toString().trim();

    if (originalMessage.isEmpty) {
      return fallback;
    }

    final normalizedMessage = originalMessage.toLowerCase();

    if (_containsAny(normalizedMessage, const [
      'timeout',
      'timed out',
      'timeoutexception',
      'connection timeout',
      'receive timeout',
      'send timeout',
      'gateway timeout',
    ])) {
      return timeout;
    }

    if (_containsAny(normalizedMessage, const [
      'socketexception',
      'failed host lookup',
      'network is unreachable',
      'connection failed',
      'connection refused',
      'no internet',
      'internet connection',
      'network connection',
      'clientexception',
      'network error',
      'connection error',
    ])) {
      return offline;
    }

    if (_containsAny(normalizedMessage, const [
      'status code 401',
      'statuscode: 401',
      'unauthorized',
      'token expired',
      'invalid token',
      'jwt expired',
    ])) {
      return unauthorized;
    }

    if (_containsAny(normalizedMessage, const [
      'status code 403',
      'statuscode: 403',
      'forbidden',
      'access denied',
    ])) {
      return forbidden;
    }

    if (_containsAny(normalizedMessage, const [
      'status code 404',
      'statuscode: 404',
      'not found',
    ])) {
      return notFound;
    }

    if (_containsAny(normalizedMessage, const [
      'status code 500',
      'statuscode: 500',
      'status code 502',
      'statuscode: 502',
      'status code 503',
      'statuscode: 503',
      'status code 504',
      'statuscode: 504',
      'internal server error',
      'bad gateway',
      'service unavailable',
    ])) {
      return serverUnavailable;
    }

    final cleanedMessage = _removeTechnicalPrefixes(originalMessage);

    return cleanedMessage.isEmpty ? fallback : cleanedMessage;
  }

  static bool _containsAny(String message, List<String> values) {
    return values.any(message.contains);
  }

  static String _removeTechnicalPrefixes(String message) {
    var result = message.trim();

    const prefixes = <String>[
      'Exception: ',
      'AppException: ',
      'Error: ',
      'FormatException: ',
    ];

    var prefixRemoved = true;

    while (prefixRemoved) {
      prefixRemoved = false;

      for (final prefix in prefixes) {
        if (result.startsWith(prefix)) {
          result = result.substring(prefix.length).trim();

          prefixRemoved = true;
          break;
        }
      }
    }

    return result;
  }
}
