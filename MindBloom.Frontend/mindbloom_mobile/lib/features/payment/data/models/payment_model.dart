class PaymentModel {
  final int id;
  final int appointmentId;
  final String therapistName;
  final double amount;
  final String status;
  final DateTime createdAtUtc;

  const PaymentModel({
    required this.id,
    required this.appointmentId,
    required this.therapistName,
    required this.amount,
    required this.status,
    required this.createdAtUtc,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final createdAtValue = json['createdAtUtc'];

    return PaymentModel(
      id: json['id'] ?? 0,
      appointmentId: json['appointmentId'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? '',
      createdAtUtc: createdAtValue is String
          ? DateTime.parse(createdAtValue)
          : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  bool get isPaid {
    return status.trim().toLowerCase() == 'paid';
  }

  bool get isRefunded {
    return status.trim().toLowerCase() == 'refunded';
  }
}
