class AppointmentRevenueReportItemModel {
  final int appointmentId;
  final String clientName;
  final String therapistName;
  final DateTime startUtc;
  final DateTime endUtc;
  final String appointmentStatus;
  final String appointmentType;
  final double price;
  final String paymentStatus;
  final double paidAmount;
  final double refundedAmount;

  const AppointmentRevenueReportItemModel({
    required this.appointmentId,
    required this.clientName,
    required this.therapistName,
    required this.startUtc,
    required this.endUtc,
    required this.appointmentStatus,
    required this.appointmentType,
    required this.price,
    required this.paymentStatus,
    required this.paidAmount,
    required this.refundedAmount,
  });

  factory AppointmentRevenueReportItemModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return AppointmentRevenueReportItemModel(
      appointmentId: (json['appointmentId'] as num?)?.toInt() ?? 0,
      clientName: json['clientName']?.toString() ?? '',
      therapistName: json['therapistName']?.toString() ?? '',
      startUtc: DateTime.parse(json['startUtc'].toString()).toUtc(),
      endUtc: DateTime.parse(json['endUtc'].toString()).toUtc(),
      appointmentStatus: json['appointmentStatus']?.toString() ?? '',
      appointmentType: json['appointmentType']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      paymentStatus: json['paymentStatus']?.toString() ?? 'Unpaid',
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0,
      refundedAmount: (json['refundedAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}
