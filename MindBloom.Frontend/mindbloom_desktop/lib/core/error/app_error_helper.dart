import 'app_exception.dart';

class AppErrorHelper {
  AppErrorHelper._();

  static String message(Object error) {
    if (error is AppException) {
      return _messageFromAppException(error);
    }

    final value = error.toString().trim();

    if (value.startsWith('Exception: ')) {
      return value.substring('Exception: '.length);
    }

    if (value.startsWith('FormatException: ')) {
      return value.substring('FormatException: '.length);
    }

    if (value.isEmpty) {
      return 'Došlo je do neočekivane greške.';
    }

    return value;
  }

  static String? fieldMessage(Object error, String field) {
    if (error is! AppException) {
      return null;
    }

    final backendMessage = error.validationMessageFor(field);

    if (backendMessage == null) {
      return null;
    }

    return _translateCommonMessage(backendMessage);
  }

  static Map<String, String> fieldMessages(Object error) {
    if (error is! AppException) {
      return const {};
    }

    final result = <String, String>{};

    for (final entry in error.validationErrors.entries) {
      if (entry.value.isEmpty) {
        continue;
      }

      result[entry.key] = _translateCommonMessage(entry.value.first);
    }

    return result;
  }

  static String _messageFromAppException(AppException exception) {
    if (exception.hasValidationErrors) {
      final messages = exception.allValidationMessages
          .map(_translateCommonMessage)
          .toSet()
          .toList();

      if (messages.isNotEmpty) {
        return messages.join('\n');
      }
    }

    final detail = exception.detail?.trim();

    if (detail != null && detail.isNotEmpty && !_isGenericDetail(detail)) {
      return _translateCommonMessage(detail);
    }

    final message = exception.message.trim();

    if (message.isNotEmpty) {
      return _translateCommonMessage(message);
    }

    return _fallbackForStatusCode(exception.statusCode);
  }

  static bool _isGenericDetail(String value) {
    final normalized = value.toLowerCase();

    return normalized == 'one or more validation errors occurred.' ||
        normalized == 'an unexpected server error occurred.';
  }

  static String _fallbackForStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Podaci zahtjeva nisu ispravni. Provjerite unesene vrijednosti.';
      case 401:
        return 'Vaša sesija je istekla. Prijavite se ponovo.';
      case 403:
        return 'Nemate dozvolu za ovu akciju.';
      case 404:
        return 'Traženi podatak nije pronađen.';
      case 409:
        return 'Akcija se ne može izvršiti zbog postojećih podataka ili poslovnog pravila.';
      case 500:
        return 'Došlo je do greške na serveru. Pokušajte ponovo.';
      default:
        return 'Zahtjev nije mogao biti izvršen.';
    }
  }

  static String _translateCommonMessage(String value) {
    final message = value.trim();

    if (message.isEmpty) {
      return 'Zahtjev nije mogao biti izvršen.';
    }

    const exactTranslations = <String, String>{
      'Validation failed': 'Validacija nije uspjela.',
      'One or more validation errors occurred.':
          'Jedno ili više polja nije ispravno.',
      'Bad request': 'Zahtjev nije ispravan.',
      'Resource not found': 'Traženi podatak nije pronađen.',
      'Business rule violation':
          'Akcija nije dozvoljena prema poslovnim pravilima.',
      'Unauthorized': 'Niste prijavljeni.',
      'Authentication is required.': 'Potrebna je prijava.',
      'Invalid operation': 'Ova akcija trenutno nije dozvoljena.',
      'Request cancelled': 'Zahtjev je otkazan.',
      'The request was cancelled.': 'Zahtjev je otkazan.',
      'Internal server error': 'Greška na serveru.',
      'An unexpected server error occurred.':
          'Došlo je do neočekivane greške na serveru.',
      'Your session has expired. Please log in again.':
          'Vaša sesija je istekla. Prijavite se ponovo.',
    };

    final exact = exactTranslations[message];

    if (exact != null) {
      return exact;
    }

    return message;
  }
}
