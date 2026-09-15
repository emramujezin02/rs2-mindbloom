class CancelAppointmentRequest {
  final String reason;

  CancelAppointmentRequest({required this.reason});

  Map<String, dynamic> toJson() {
    return {'reason': reason};
  }
}
