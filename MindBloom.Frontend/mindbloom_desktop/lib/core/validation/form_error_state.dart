class FormErrorState {
  String? generalError;

  final Map<String, String> fieldErrors = {};

  bool get hasGeneralError {
    return generalError != null && generalError!.trim().isNotEmpty;
  }

  void setGeneralError(String? value) {
    final normalized = value?.trim();

    generalError = normalized == null || normalized.isEmpty ? null : normalized;
  }

  void setFieldErrors(Map<String, String> errors) {
    fieldErrors
      ..clear()
      ..addAll(errors);
  }

  String? fieldError(String field) {
    final normalized = field.trim().toLowerCase();

    for (final entry in fieldErrors.entries) {
      if (entry.key.trim().toLowerCase() == normalized) {
        return entry.value;
      }
    }

    return null;
  }

  void clearField(String field) {
    final normalized = field.trim().toLowerCase();

    final keysToRemove = fieldErrors.keys
        .where((key) => key.trim().toLowerCase() == normalized)
        .toList();

    for (final key in keysToRemove) {
      fieldErrors.remove(key);
    }

    generalError = null;
  }

  void clear() {
    generalError = null;
    fieldErrors.clear();
  }
}
