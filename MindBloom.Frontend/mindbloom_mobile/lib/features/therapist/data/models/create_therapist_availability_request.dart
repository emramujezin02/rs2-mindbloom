class CreateTherapistAvailabilityRequest {
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  const CreateTherapistAvailabilityRequest({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {'dayOfWeek': dayOfWeek, 'startTime': startTime, 'endTime': endTime};
  }
}
