class AppointmentModel {
  final int id;
  final int therapistId;
  final String therapistName;
  final String clientName;
  final DateTime startUtc;
  final DateTime endUtc;
  final String status;
  final String type;
  final double price;
  final String? meetingLink;
  final String? location;
  final int? paymentId;

  const AppointmentModel({
    required this.id,
    required this.therapistId,
    required this.therapistName,
    required this.clientName,
    required this.startUtc,
    required this.endUtc,
    required this.status,
    required this.type,
    required this.price,
    this.meetingLink,
    this.location,
    this.paymentId,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: _toInt(json['id']),
      therapistId: _toInt(json['therapistId']),
      therapistName: _toString(json['therapistName']),
      clientName: _readClientName(json),
      startUtc: _toDateTime(json['startUtc']),
      endUtc: _toDateTime(json['endUtc']),
      status: _toString(json['status']),
      type: _toString(json['type']),
      price: _toDouble(json['price']),
      meetingLink: _toNullableString(json['meetingLink']),
      location: _toNullableString(json['location']),
      paymentId: _toNullableInt(json['paymentId']),
    );
  }

  AppointmentModel copyWith({
    int? id,
    int? therapistId,
    String? therapistName,
    String? clientName,
    DateTime? startUtc,
    DateTime? endUtc,
    String? status,
    String? type,
    double? price,
    String? meetingLink,
    String? location,
    int? paymentId,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      therapistId: therapistId ?? this.therapistId,
      therapistName: therapistName ?? this.therapistName,
      clientName: clientName ?? this.clientName,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc ?? this.endUtc,
      status: status ?? this.status,
      type: type ?? this.type,
      price: price ?? this.price,
      meetingLink: meetingLink ?? this.meetingLink,
      location: location ?? this.location,
      paymentId: paymentId ?? this.paymentId,
    );
  }

  bool get isUpcoming {
    final normalizedStatus = status.trim().toLowerCase();

    final isInactive =
        normalizedStatus == 'completed' ||
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'rejected';

    return startUtc.toLocal().isAfter(DateTime.now()) && !isInactive;
  }

  bool get canBeCancelled {
    final normalizedStatus = status.trim().toLowerCase();

    return normalizedStatus == 'pending' || normalizedStatus == 'accepted';
  }

  bool get isOnline {
    return type.trim().toLowerCase() == 'online';
  }

  static String _readClientName(Map<String, dynamic> json) {
    final directName = _toString(json['clientName']);

    if (directName.isNotEmpty) {
      return directName;
    }

    final fullName = _toString(json['clientFullName']);

    if (fullName.isNotEmpty) {
      return fullName;
    }

    final firstName = _toString(json['clientFirstName']);

    final lastName = _toString(json['clientLastName']);

    final combinedName = '$firstName $lastName'.trim();

    if (combinedName.isNotEmpty) {
      return combinedName;
    }

    return 'Client';
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

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
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

  static String _toString(dynamic value) {
    return value?.toString().trim() ?? '';
  }

  static String? _toNullableString(dynamic value) {
    final stringValue = value?.toString().trim();

    if (stringValue == null || stringValue.isEmpty) {
      return null;
    }

    return stringValue;
  }

  static DateTime _toDateTime(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');

    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
