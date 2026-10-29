import 'therapist_appointment_status.dart';

class UpdateAppointmentStatusRequest {
  final int appointmentId;
  final TherapistAppointmentStatus status;
  final String? reason;

  const UpdateAppointmentStatusRequest({
    required this.appointmentId,
    required this.status,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'appointmentId': appointmentId,
      'status': status.apiValue,
      if (reason != null) 'reason': reason!.trim(),
    };
  }
}
