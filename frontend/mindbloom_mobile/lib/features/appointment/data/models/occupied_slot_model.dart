import '../../../../core/time/appointment_time_zone.dart';

class OccupiedSlotModel {
  final DateTime startUtc;
  final DateTime endUtc;

  OccupiedSlotModel({required this.startUtc, required this.endUtc});

  factory OccupiedSlotModel.fromJson(Map<String, dynamic> json) {
    return OccupiedSlotModel(
      startUtc: AppointmentTimeZone.parseUtc(json['startUtc']),
      endUtc: AppointmentTimeZone.parseUtc(json['endUtc']),
    );
  }
}
