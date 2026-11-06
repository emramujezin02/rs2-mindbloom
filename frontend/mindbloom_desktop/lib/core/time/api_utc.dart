/// Parses only API fields whose contract explicitly defines a UTC instant.
/// SQL datetime2 values may omit the timezone suffix; local dates must not use this.
abstract final class ApiUtc {
  static DateTime parse(String value) {
    final text = value.trim();
    final hasTime = RegExp(r'[Tt ]\d{2}').hasMatch(text);
    final hasZone =
        hasTime &&
        RegExp(
          r'(?:Z|[+-]\d{2}(?::?\d{2})?)$',
          caseSensitive: false,
        ).hasMatch(text);
    return DateTime.parse(hasZone ? text : '${text}Z').toUtc();
  }

  static DateTime? tryParse(String value) {
    try {
      return parse(value);
    } on FormatException {
      return null;
    }
  }
}
