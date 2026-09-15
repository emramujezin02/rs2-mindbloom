enum TherapistAppointmentStatus {
  pending(0, 'Pending'),
  accepted(1, 'Accepted'),
  rejected(2, 'Rejected'),
  completed(3, 'Completed'),
  cancelled(4, 'Cancelled');

  final int apiValue;
  final String label;

  const TherapistAppointmentStatus(this.apiValue, this.label);

  static TherapistAppointmentStatus? fromName(String value) {
    final normalizedValue = value.trim().toLowerCase();

    for (final status in TherapistAppointmentStatus.values) {
      if (status.label.toLowerCase() == normalizedValue) {
        return status;
      }
    }

    return null;
  }
}
