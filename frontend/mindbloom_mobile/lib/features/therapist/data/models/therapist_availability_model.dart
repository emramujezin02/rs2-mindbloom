class TherapistAvailabilityModel {
  final int id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  TherapistAvailabilityModel({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory TherapistAvailabilityModel.fromJson(Map<String, dynamic> json) {
    return TherapistAvailabilityModel(
      id: json['id'] ?? 0,
      dayOfWeek: _parseDayOfWeek(json['dayOfWeek']),
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
    );
  }

  String get dayName {
    switch (dayOfWeek) {
      case 0:
        return 'Sunday';
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return 'Unknown day';
    }
  }

  String get formattedStartTime {
    return _formatTime(startTime);
  }

  String get formattedEndTime {
    return _formatTime(endTime);
  }

  static int _parseDayOfWeek(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is String) {
      final numericValue = int.tryParse(value);

      if (numericValue != null) {
        return numericValue;
      }

      switch (value.toLowerCase()) {
        case 'sunday':
          return 0;
        case 'monday':
          return 1;
        case 'tuesday':
          return 2;
        case 'wednesday':
          return 3;
        case 'thursday':
          return 4;
        case 'friday':
          return 5;
        case 'saturday':
          return 6;
      }
    }

    return -1;
  }

  static String _formatTime(String value) {
    if (value.isEmpty) {
      return '';
    }

    final parts = value.split(':');

    if (parts.length < 2) {
      return value;
    }

    return '${parts[0]}:${parts[1]}';
  }
}
