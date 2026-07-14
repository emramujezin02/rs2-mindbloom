class PaymentReceiptModel {
  final int paymentId;
  final int appointmentId;

  final String therapistName;
  final String clientName;

  final double amount;
  final String status;

  final DateTime paymentDateUtc;

  final DateTime appointmentStartUtc;
  final DateTime appointmentEndUtc;

  final String invoiceNumber;

  PaymentReceiptModel({
    required this.paymentId,
    required this.appointmentId,
    required this.therapistName,
    required this.clientName,
    required this.amount,
    required this.status,
    required this.paymentDateUtc,
    required this.appointmentStartUtc,
    required this.appointmentEndUtc,
    required this.invoiceNumber,
  });

  factory PaymentReceiptModel.fromJson(Map<String, dynamic> json) {
    return PaymentReceiptModel(
      paymentId: json["paymentId"],
      appointmentId: json["appointmentId"],
      therapistName: json["therapistName"],
      clientName: json["clientName"],
      amount: (json["amount"] as num).toDouble(),
      status: json["status"],
      paymentDateUtc: DateTime.parse(json["paymentDateUtc"]),
      appointmentStartUtc: DateTime.parse(json["appointmentStartUtc"]),
      appointmentEndUtc: DateTime.parse(json["appointmentEndUtc"]),
      invoiceNumber: json["invoiceNumber"],
    );
  }
}
