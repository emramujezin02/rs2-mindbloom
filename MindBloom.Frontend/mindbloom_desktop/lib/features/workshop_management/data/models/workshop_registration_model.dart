class WorkshopRegistrationModel {
  final int id;
  final int workshopId;
  final int clientId;
  final int clientUserId;
  final String clientName;
  final String clientEmail;
  final String status;
  final DateTime registeredAtUtc;
  final DateTime? cancelledAtUtc;

  const WorkshopRegistrationModel({
    required this.id,
    required this.workshopId,
    required this.clientId,
    required this.clientUserId,
    required this.clientName,
    required this.clientEmail,
    required this.status,
    required this.registeredAtUtc,
    required this.cancelledAtUtc,
  });

  factory WorkshopRegistrationModel.fromJson(Map<String, dynamic> json) {
    return WorkshopRegistrationModel(
      id: json['id'] ?? 0,
      workshopId: json['workshopId'] ?? 0,
      clientId: json['clientId'] ?? 0,
      clientUserId: json['clientUserId'] ?? 0,
      clientName: json['clientName'] ?? '',
      clientEmail: json['clientEmail'] ?? '',
      status: json['status'] ?? '',
      registeredAtUtc: DateTime.parse(json['registeredAtUtc']),
      cancelledAtUtc: json['cancelledAtUtc'] == null
          ? null
          : DateTime.parse(json['cancelledAtUtc']),
    );
  }
}
