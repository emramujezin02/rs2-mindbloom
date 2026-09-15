class ReportTherapistOptionModel {
  final int id;

  final String fullName;

  final String specialization;

  const ReportTherapistOptionModel({
    required this.id,
    required this.fullName,
    required this.specialization,
  });

  factory ReportTherapistOptionModel.fromJson(Map<String, dynamic> json) {
    return ReportTherapistOptionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,

      fullName: json['fullName']?.toString() ?? '',

      specialization: json['specialization']?.toString() ?? '',
    );
  }
}
