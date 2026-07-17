class AppointmentPaymentReportModel {
  final int totalPaymentRecords;
  final int paidPaymentsCount;
  final int unpaidAppointmentsCount;
  final int refundRequestedCount;
  final int refundedPaymentsCount;
  final int failedRefundsCount;
  final double grossRevenue;
  final double refundedAmount;
  final double netRevenue;

  const AppointmentPaymentReportModel({
    required this.totalPaymentRecords,
    required this.paidPaymentsCount,
    required this.unpaidAppointmentsCount,
    required this.refundRequestedCount,
    required this.refundedPaymentsCount,
    required this.failedRefundsCount,
    required this.grossRevenue,
    required this.refundedAmount,
    required this.netRevenue,
  });

  factory AppointmentPaymentReportModel.fromJson(Map<String, dynamic> json) {
    return AppointmentPaymentReportModel(
      totalPaymentRecords: _toInt(json['totalPaymentRecords']),
      paidPaymentsCount: _toInt(json['paidPaymentsCount']),
      unpaidAppointmentsCount: _toInt(json['unpaidAppointmentsCount']),
      refundRequestedCount: _toInt(json['refundRequestedCount']),
      refundedPaymentsCount: _toInt(json['refundedPaymentsCount']),
      failedRefundsCount: _toInt(json['failedRefundsCount']),
      grossRevenue: _toDouble(json['grossRevenue']),
      refundedAmount: _toDouble(json['refundedAmount']),
      netRevenue: _toDouble(json['netRevenue']),
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

  static double _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
