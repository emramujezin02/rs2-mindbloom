import 'admin_appointment_model.dart';

class AdminAppointmentPagedResponse {
  final List<AdminAppointmentModel> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const AdminAppointmentPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory AdminAppointmentPagedResponse.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'];

    return AdminAppointmentPagedResponse(
      items: itemsJson is List
          ? itemsJson
                .whereType<Map<String, dynamic>>()
                .map(AdminAppointmentModel.fromJson)
                .toList()
          : [],
      pageNumber: json['pageNumber'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
