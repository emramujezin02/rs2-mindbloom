class AdminAppointmentModel {
  final int id;
  final String clientName;
  final String clientEmail;
  final String therapistName;
  final String therapistEmail;
  final DateTime startUtc;
  final DateTime endUtc;
  final String status;
  final String type;
  final double price;
  final bool isPaid;
  final String? paymentStatus;
  final DateTime createdAtUtc;
  final bool canAdminCancel;

  const AdminAppointmentModel({
    required this.id,
    required this.clientName,
    required this.clientEmail,
    required this.therapistName,
    required this.therapistEmail,
    required this.startUtc,
    required this.endUtc,
    required this.status,
    required this.type,
    required this.price,
    required this.isPaid,
    required this.paymentStatus,
    required this.createdAtUtc,
    required this.canAdminCancel,
  });

  factory AdminAppointmentModel.fromJson(Map<String, dynamic> json) {
    return AdminAppointmentModel(
      id: json['id'] ?? 0,
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      therapistName: json['therapistName'] ?? '',
      therapistEmail: json['therapistEmail'] ?? '',
      startUtc: DateTime.parse(json['startUtc']),
      endUtc: DateTime.parse(json['endUtc']),
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      isPaid: json['isPaid'] ?? false,
      paymentStatus: json['paymentStatus'],
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      canAdminCancel: json['canAdminCancel'] ?? false,
    );
  }
}
