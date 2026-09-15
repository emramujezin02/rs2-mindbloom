class AdminMembershipDetailsModel {
  final int id;

  final int clientId;

  final int clientUserId;

  final String clientName;

  final String clientEmail;

  final int therapistId;

  final int therapistUserId;

  final String therapistName;

  final String therapistEmail;

  final String planType;

  final String membershipStatus;

  final int totalSessions;

  final int remainingSessions;

  final int usedSessions;

  final int reservedSessions;

  final int consumedSessions;

  final int restoredSessions;

  final double price;

  final bool isActive;

  final DateTime? purchasedAtUtc;

  final DateTime? expiresAtUtc;

  final DateTime createdAtUtc;

  final DateTime? updatedAtUtc;

  final AdminMembershipPaymentModel? payment;

  final List<AdminMembershipUsageModel> usages;

  const AdminMembershipDetailsModel({
    required this.id,
    required this.clientId,
    required this.clientUserId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistId,
    required this.therapistUserId,
    required this.therapistName,
    required this.therapistEmail,
    required this.planType,
    required this.membershipStatus,
    required this.totalSessions,
    required this.remainingSessions,
    required this.usedSessions,
    required this.reservedSessions,
    required this.consumedSessions,
    required this.restoredSessions,
    required this.price,
    required this.isActive,
    required this.purchasedAtUtc,
    required this.expiresAtUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.payment,
    required this.usages,
  });

  factory AdminMembershipDetailsModel.fromJson(Map<String, dynamic> json) {
    final paymentJson = json['payment'];

    final rawUsages = json['usages'] as List<dynamic>? ?? const [];

    return AdminMembershipDetailsModel(
      id: json['id'] ?? 0,
      clientId: json['clientId'] ?? 0,
      clientUserId: json['clientUserId'] ?? 0,
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      therapistId: json['therapistId'] ?? 0,
      therapistUserId: json['therapistUserId'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      therapistEmail: json['therapistEmail'] ?? '',
      planType: json['planType'] ?? '',
      membershipStatus: json['membershipStatus'] ?? '',
      totalSessions: json['totalSessions'] ?? 0,
      remainingSessions: json['remainingSessions'] ?? 0,
      usedSessions: json['usedSessions'] ?? 0,
      reservedSessions: json['reservedSessions'] ?? 0,
      consumedSessions: json['consumedSessions'] ?? 0,
      restoredSessions: json['restoredSessions'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isActive: json['isActive'] ?? false,
      purchasedAtUtc: _parseDate(json['purchasedAtUtc']),
      expiresAtUtc: _parseDate(json['expiresAtUtc']),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAtUtc: _parseDate(json['updatedAtUtc']),
      payment: paymentJson is Map<String, dynamic>
          ? AdminMembershipPaymentModel.fromJson(paymentJson)
          : null,
      usages: rawUsages
          .whereType<Map<String, dynamic>>()
          .map(AdminMembershipUsageModel.fromJson)
          .toList(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}

class AdminMembershipPaymentModel {
  final int id;

  final double amount;

  final String currency;

  final String status;

  final String stripePaymentIntentId;

  final DateTime? paidAtUtc;

  final DateTime createdAtUtc;

  const AdminMembershipPaymentModel({
    required this.id,
    required this.amount,
    required this.currency,
    required this.status,
    required this.stripePaymentIntentId,
    required this.paidAtUtc,
    required this.createdAtUtc,
  });

  factory AdminMembershipPaymentModel.fromJson(Map<String, dynamic> json) {
    return AdminMembershipPaymentModel(
      id: json['id'] ?? 0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] ?? '',
      status: json['status'] ?? '',
      stripePaymentIntentId: json['stripePaymentIntentId'] ?? '',
      paidAtUtc: json['paidAtUtc'] == null
          ? null
          : DateTime.tryParse(json['paidAtUtc'].toString()),
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}

class AdminMembershipUsageModel {
  final int id;

  final int appointmentId;

  final String appointmentStatus;

  final DateTime appointmentStartUtc;

  final DateTime appointmentEndUtc;

  final String status;

  final DateTime usedAtUtc;

  final DateTime? reservedAtUtc;

  final DateTime? consumedAtUtc;

  final DateTime? restoredAtUtc;

  final String? resolutionReason;

  final DateTime createdAtUtc;

  final DateTime? updatedAtUtc;

  const AdminMembershipUsageModel({
    required this.id,
    required this.appointmentId,
    required this.appointmentStatus,
    required this.appointmentStartUtc,
    required this.appointmentEndUtc,
    required this.status,
    required this.usedAtUtc,
    required this.reservedAtUtc,
    required this.consumedAtUtc,
    required this.restoredAtUtc,
    required this.resolutionReason,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });

  factory AdminMembershipUsageModel.fromJson(Map<String, dynamic> json) {
    return AdminMembershipUsageModel(
      id: json['id'] ?? 0,
      appointmentId: json['appointmentId'] ?? 0,
      appointmentStatus: json['appointmentStatus'] ?? '',
      appointmentStartUtc:
          DateTime.tryParse(json['appointmentStartUtc']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      appointmentEndUtc:
          DateTime.tryParse(json['appointmentEndUtc']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      status: json['status'] ?? '',
      usedAtUtc:
          DateTime.tryParse(json['usedAtUtc']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      reservedAtUtc: _parseDate(json['reservedAtUtc']),
      consumedAtUtc: _parseDate(json['consumedAtUtc']),
      restoredAtUtc: _parseDate(json['restoredAtUtc']),
      resolutionReason: json['resolutionReason'],
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAtUtc: _parseDate(json['updatedAtUtc']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }
}
