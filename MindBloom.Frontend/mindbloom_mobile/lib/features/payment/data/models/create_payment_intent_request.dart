class CreatePaymentIntentRequest {
  final int appointmentId;

  const CreatePaymentIntentRequest({required this.appointmentId});

  Map<String, dynamic> toJson() {
    return {'appointmentId': appointmentId};
  }
}
