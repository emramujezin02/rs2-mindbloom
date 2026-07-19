import 'therapist_appointment_status.dart';

class UpdateAppointmentStatusRequest {
  final int appointmentId;
  final TherapistAppointmentStatus status;

  const UpdateAppointmentStatusRequest({
    required this.appointmentId,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {'appointmentId': appointmentId, 'status': status.apiValue};
  }
}
