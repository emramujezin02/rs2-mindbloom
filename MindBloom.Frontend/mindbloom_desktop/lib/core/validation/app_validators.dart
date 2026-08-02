class AppValidators {
  AppValidators._();

  static String normalize(String? value) {
    return value?.trim() ?? '';
  }

  static double? parseDecimal(String? value) {
    final normalized = normalize(value).replaceAll(',', '.');

    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  static int? parseInteger(String? value) {
    final normalized = normalize(value);

    if (normalized.isEmpty) {
      return null;
    }

    return int.tryParse(normalized);
  }

  static String? required(String? value, {required String fieldName}) {
    if (normalize(value).isEmpty) {
      return '$fieldName je obavezno polje.';
    }

    return null;
  }

  static String? textLength(
    String? value, {
    required String fieldName,
    int? minLength,
    int? maxLength,
    bool required = true,
  }) {
    final normalized = normalize(value);

    if (normalized.isEmpty) {
      return required ? '$fieldName je obavezno polje.' : null;
    }

    if (minLength != null && normalized.length < minLength) {
      return '$fieldName mora sadržavati najmanje '
          '$minLength znakova.';
    }

    if (maxLength != null && normalized.length > maxLength) {
      return '$fieldName može sadržavati najviše '
          '$maxLength znakova.';
    }

    return null;
  }

  static String? email(String? value, {bool required = true}) {
    final normalized = normalize(value);

    if (normalized.isEmpty) {
      return required ? 'Email je obavezno polje.' : null;
    }

    if (normalized.length > 254) {
      return 'Email može sadržavati najviše 254 znaka.';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(normalized)) {
      return 'Unesite ispravnu email adresu.';
    }

    return null;
  }

  static String? phone(String? value, {bool required = false}) {
    final normalized = normalize(value);

    if (normalized.isEmpty) {
      return required ? 'Broj telefona je obavezno polje.' : null;
    }

    if (normalized.length > 30) {
      return 'Broj telefona može sadržavati najviše 30 znakova.';
    }

    final phoneRegex = RegExp(r'^\+?[0-9\s()\-\/]{6,30}$');

    if (!phoneRegex.hasMatch(normalized)) {
      return 'Unesite ispravan broj telefona.';
    }

    return null;
  }

  static String? price(
    String? value, {
    required String fieldName,
    bool allowZero = false,
  }) {
    final parsed = parseDecimal(value);

    if (parsed == null) {
      return 'Unesite ispravnu vrijednost za $fieldName.';
    }

    if (allowZero) {
      if (parsed < 0) {
        return '$fieldName ne može biti negativna vrijednost.';
      }
    } else if (parsed <= 0) {
      return '$fieldName mora biti veća od 0.';
    }

    return null;
  }

  static String? percentage(
    String? value, {
    required String fieldName,
    double minimum = 0,
    double maximum = 100,
  }) {
    final parsed = parseDecimal(value);

    if (parsed == null) {
      return 'Unesite ispravan postotak.';
    }

    if (parsed < minimum || parsed > maximum) {
      return '$fieldName mora biti između '
          '${_formatNumber(minimum)} i '
          '${_formatNumber(maximum)}.';
    }

    return null;
  }

  static String? positiveInteger(
    String? value, {
    required String fieldName,
    int minimum = 1,
    int? maximum,
  }) {
    final parsed = parseInteger(value);

    if (parsed == null) {
      return '$fieldName mora biti cijeli broj.';
    }

    if (parsed < minimum) {
      return '$fieldName mora biti najmanje $minimum.';
    }

    if (maximum != null && parsed > maximum) {
      return '$fieldName može biti najviše $maximum.';
    }

    return null;
  }

  static String? integerRange(
    String? value, {
    required String fieldName,
    required int minimum,
    required int maximum,
  }) {
    final parsed = parseInteger(value);

    if (parsed == null) {
      return '$fieldName mora biti cijeli broj.';
    }

    if (parsed < minimum || parsed > maximum) {
      return '$fieldName mora biti između '
          '$minimum i $maximum.';
    }

    return null;
  }

  static String? httpUrl(
    String? value, {
    required String fieldName,
    bool required = true,
    int? maxLength,
  }) {
    final normalized = normalize(value);

    if (normalized.isEmpty) {
      return required ? '$fieldName je obavezno polje.' : null;
    }

    if (maxLength != null && normalized.length > maxLength) {
      return '$fieldName može sadržavati najviše '
          '$maxLength znakova.';
    }

    final uri = Uri.tryParse(normalized);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme.toLowerCase() != 'http' &&
            uri.scheme.toLowerCase() != 'https')) {
      return 'Unesite ispravnu HTTP ili HTTPS adresu.';
    }

    return null;
  }

  static String? dateRange({
    required DateTime? from,
    required DateTime? to,
    String fromName = 'Datum od',
    String toName = 'Datum do',
  }) {
    if (from == null) {
      return '$fromName je obavezan.';
    }

    if (to == null) {
      return '$toName je obavezan.';
    }

    if (from.isAfter(to)) {
      return '$fromName ne može biti nakon polja $toName.';
    }

    return null;
  }

  static String? endAfterStart({
    required DateTime start,
    required DateTime end,
    String startName = 'Početak',
    String endName = 'Završetak',
  }) {
    if (!end.isAfter(start)) {
      return '$endName mora biti nakon polja $startName.';
    }

    return null;
  }

  static String? futureDate(DateTime? value, {required String fieldName}) {
    if (value == null) {
      return '$fieldName je obavezan.';
    }

    if (!value.isAfter(DateTime.now())) {
      return '$fieldName mora biti u budućnosti.';
    }

    return null;
  }

  static String? maxLength(
    String? value, {
    required String fieldName,
    required int maximum,
  }) {
    final normalized = normalize(value);

    if (normalized.length > maximum) {
      return '$fieldName može sadržavati najviše '
          '$maximum znakova.';
    }

    return null;
  }

  static String? uniqueText(
    String? value, {
    required String fieldName,
    required Iterable<String> existingValues,
    String? currentValue,
  }) {
    final normalized = normalize(value).toLowerCase();

    if (normalized.isEmpty) {
      return null;
    }

    final normalizedCurrent = normalize(currentValue).toLowerCase();

    final duplicate = existingValues.any((existing) {
      final normalizedExisting = normalize(existing).toLowerCase();

      if (normalizedCurrent.isNotEmpty &&
          normalizedExisting == normalizedCurrent) {
        return false;
      }

      return normalizedExisting == normalized;
    });

    if (duplicate) {
      return '$fieldName već postoji.';
    }

    return null;
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}
