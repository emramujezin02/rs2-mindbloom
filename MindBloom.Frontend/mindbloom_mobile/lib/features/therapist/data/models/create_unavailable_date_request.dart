class CreateUnavailableDateRequest {
  final DateTime startUtc;
  final DateTime endUtc;
  final String reason;

  const CreateUnavailableDateRequest({
    required this.startUtc,
    required this.endUtc,
    required this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'startUtc': startUtc.toUtc().toIso8601String(),
      'endUtc': endUtc.toUtc().toIso8601String(),
      'reason': reason.trim(),
    };
  }
}
