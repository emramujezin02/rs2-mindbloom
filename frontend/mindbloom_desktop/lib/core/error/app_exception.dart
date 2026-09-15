class AppException implements Exception {
  final String message;

  final int? statusCode;

  final String? title;

  final String? detail;

  final Map<String, List<String>> validationErrors;

  final bool isNetworkError;

  final bool isTimeout;

  final bool isSessionExpired;

  AppException({
    required this.message,
    this.statusCode,
    this.title,
    this.detail,
    Map<String, List<String>>? validationErrors,
    this.isNetworkError = false,
    this.isTimeout = false,
    this.isSessionExpired = false,
  }) : validationErrors = validationErrors ?? const {};

  bool get hasValidationErrors {
    return validationErrors.isNotEmpty;
  }

  List<String> get allValidationMessages {
    return validationErrors.values
        .expand((messages) => messages)
        .where((message) => message.trim().isNotEmpty)
        .toList();
  }

  String? validationMessageFor(String field) {
    final normalizedField = field.trim().toLowerCase();

    for (final entry in validationErrors.entries) {
      if (entry.key.trim().toLowerCase() == normalizedField) {
        if (entry.value.isEmpty) {
          return null;
        }

        return entry.value.first;
      }
    }

    return null;
  }

  @override
  String toString() {
    return message;
  }
}
