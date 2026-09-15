class TherapistProfileAvailabilityModel {
  final int id;
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  const TherapistProfileAvailabilityModel({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory TherapistProfileAvailabilityModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return TherapistProfileAvailabilityModel(
      id: _readInt(json['id']),
      dayOfWeek: _readDayOfWeek(json['dayOfWeek']),
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
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
        return 'Unknown';
    }
  }

  String get formattedTime {
    return '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _readDayOfWeek(dynamic value) {
    if (value is int) {
      return value;
    }

    final parsedNumber = int.tryParse(value?.toString() ?? '');

    if (parsedNumber != null) {
      return parsedNumber;
    }

    switch (value?.toString().toLowerCase()) {
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
      default:
        return 0;
    }
  }

  static String _formatTime(String value) {
    if (value.isEmpty) {
      return '';
    }

    final parts = value.split(':');

    if (parts.length < 2) {
      return value;
    }

    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
}
