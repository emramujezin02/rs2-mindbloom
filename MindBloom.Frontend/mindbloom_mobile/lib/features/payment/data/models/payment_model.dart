class PaymentModel {
  final int id;
  final String therapistName;
  final double amount;
  final String status;
  final DateTime createdAtUtc;

  PaymentModel({
    required this.id,
    required this.therapistName,
    required this.amount,
    required this.status,
    required this.createdAtUtc,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      amount: (json['amount'] as num).toDouble(),
      status: json['status'] ?? '',
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
    );
  }
}
