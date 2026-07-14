class AppointmentModel {
  final int id;
  final int therapistId;
  final String therapistName;
  final DateTime startUtc;
  final DateTime endUtc;
  final String status;
  final String type;
  final String? meetingLink;
  final String? location;
  final int? paymentId;

  AppointmentModel({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.startUtc,
    required this.endUtc,
    required this.status,
    required this.type,
    this.meetingLink,
    this.location,
    this.paymentId,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] ?? 0,
      therapistId: json['therapistId'] ?? 0,
      therapistName: json['therapistName'] ?? '',
      startUtc: DateTime.parse(json['startUtc']),
      endUtc: DateTime.parse(json['endUtc']),
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      meetingLink: json['meetingLink'],
      location: json['location'],
      paymentId: json["paymentId"],
    );
  }
}
