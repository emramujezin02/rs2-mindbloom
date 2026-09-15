class TherapistMapData {
  final String therapistName;
  final String address;
  final double latitude;
  final double longitude;

  const TherapistMapData({
    required this.therapistName,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  bool get hasValidCoordinates {
    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        (latitude != 0 || longitude != 0);
  }
}
