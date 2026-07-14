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

  String get normalizedStatus {
    return status.trim().toLowerCase();
  }

  bool get isPending {
    return normalizedStatus == 'pending';
  }

  bool get isPaid {
    return normalizedStatus == 'paid';
  }

  bool get isFailed {
    return normalizedStatus == 'failed';
  }

  bool get isRefundPending {
    return normalizedStatus == 'refundpending';
  }

  bool get isRefunded {
    return normalizedStatus == 'refunded';
  }

  bool get isRefundFailed {
    return normalizedStatus == 'refundfailed';
  }

  bool get hasRefundProcess {
    return isRefundPending || isRefunded || isRefundFailed;
  }

  String get displayStatus {
    if (isPending) {
      return 'Pending';
    }

    if (isPaid) {
      return 'Paid';
    }

    if (isFailed) {
      return 'Failed';
    }

    if (isRefundPending) {
      return 'Refund pending';
    }

    if (isRefunded) {
      return 'Refunded';
    }

    if (isRefundFailed) {
      return 'Refund failed';
    }

    return status;
  }
}
