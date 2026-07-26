class AppException implements Exception {
  final String message;

  final int? statusCode;

  final Map<String, List<String>> fieldErrors;

  const AppException({
    required this.message,
    this.statusCode,
    this.fieldErrors = const {},
  });

  String? fieldError(String fieldName) {
    final normalizedRequested = _normalizeFieldName(fieldName);

    for (final entry in fieldErrors.entries) {
      if (_normalizeFieldName(entry.key) == normalizedRequested) {
        if (entry.value.isNotEmpty) {
          return entry.value.first;
        }
      }
    }

    return null;
  }

  List<String> get allValidationMessages {
    return fieldErrors.values
        .expand((messages) => messages)
        .where((message) => message.trim().isNotEmpty)
        .toList();
  }

  static String _normalizeFieldName(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toLowerCase();
  }

  @override
  String toString() => message;
}
