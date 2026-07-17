class AppointmentStatusReportItemModel {
  final String status;
  final int count;

  const AppointmentStatusReportItemModel({
    required this.status,
    required this.count,
  });

  factory AppointmentStatusReportItemModel.fromJson(Map<String, dynamic> json) {
    return AppointmentStatusReportItemModel(
      status: json['status']?.toString() ?? '',
      count: _toInt(json['count']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
