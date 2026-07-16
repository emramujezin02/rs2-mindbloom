import 'admin_appointment_audit_model.dart';

class AdminAppointmentDetailsModel {
  final int id;
  final int clientId;
  final int clientUserId;
  final String clientName;
  final String clientEmail;
  final int therapistId;
  final int therapistUserId;
  final String therapistName;
  final String therapistEmail;
  final DateTime startUtc;
  final DateTime endUtc;
  final String status;
  final String type;
  final double price;
  final bool isPaid;
  final String? paymentStatus;
  final double? paymentAmount;
  final String? stripePaymentIntentId;
  final String? refundStatus;
  final String? refundReason;
  final String? meetingLink;
  final String? location;
  final String? notes;
  final bool hasMembershipUsage;
  final String? membershipUsageStatus;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final bool canAdminCancel;
  final List<AdminAppointmentAuditModel> auditHistory;

  const AdminAppointmentDetailsModel({
    required this.id,
    required this.clientId,
    required this.clientUserId,
    required this.clientName,
    required this.clientEmail,
    required this.therapistId,
    required this.therapistUserId,
    required this.therapistName,
    required this.therapistEmail,
    required this.startUtc,
    required this.endUtc,
    required this.status,
    required this.type,
    required this.price,
    required this.isPaid,
    required this.paymentStatus,
    required this.paymentAmount,
    required this.stripePaymentIntentId,
    required this.refundStatus,
    required this.refundReason,
    required this.meetingLink,
    required this.location,
    required this.notes,
    required this.hasMembershipUsage,
    required this.membershipUsageStatus,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.canAdminCancel,
    required this.auditHistory,
  });

  factory AdminAppointmentDetailsModel.fromJson(Map<String, dynamic> json) {
    final audits = json['auditHistory'];

    return AdminAppointmentDetailsModel(
      id: json['id'] ?? 0,
      clientId: json['clientId'] ?? 0,
      clientUserId: json['clientUserId'] ?? 0,
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      therapistId: json['therapistId'] ?? 0,
      therapistUserId: json['therapistUserId'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      therapistEmail: json['therapistEmail'] ?? '',
      startUtc: DateTime.parse(json['startUtc']),
      endUtc: DateTime.parse(json['endUtc']),
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      isPaid: json['isPaid'] ?? false,
      paymentStatus: json['paymentStatus'],
      paymentAmount: (json['paymentAmount'] as num?)?.toDouble(),
      stripePaymentIntentId: json['stripePaymentIntentId'],
      refundStatus: json['refundStatus'],
      refundReason: json['refundReason'],
      meetingLink: json['meetingLink'],
      location: json['location'],
      notes: json['notes'],
      hasMembershipUsage: json['hasMembershipUsage'] ?? false,
      membershipUsageStatus: json['membershipUsageStatus'],
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc']),
      canAdminCancel: json['canAdminCancel'] ?? false,
      auditHistory: audits is List
          ? audits
                .whereType<Map<String, dynamic>>()
                .map(AdminAppointmentAuditModel.fromJson)
                .toList()
          : [],
    );
  }
}
