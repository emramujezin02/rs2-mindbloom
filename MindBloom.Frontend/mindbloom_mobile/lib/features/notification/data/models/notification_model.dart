enum NotificationActionType {
  none,
  appointment,
  payment,
  chat,
  membership,
  workshop,
  review,
  therapistProfile,
}

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAtUtc;
  final NotificationActionType actionType;
  final int? appointmentId;
  final int? resourceId;
  final bool isActionAvailable;
  final String? unavailableReason;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAtUtc,
    required this.actionType,
    required this.appointmentId,
    required this.resourceId,
    required this.isActionAvailable,
    required this.unavailableReason,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: _toInt(json['id']),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      isRead: json['isRead'] == true,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      actionType: _parseActionType(json['actionType']?.toString()),
      appointmentId: _toNullableInt(json['appointmentId']),
      resourceId: _toNullableInt(json['resourceId']),
      isActionAvailable: json['isActionAvailable'] != false,
      unavailableReason: _nullableText(json['unavailableReason']),
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      isRead: isRead ?? this.isRead,
      createdAtUtc: createdAtUtc,
      actionType: actionType,
      appointmentId: appointmentId,
      resourceId: resourceId,
      isActionAvailable: isActionAvailable,
      unavailableReason: unavailableReason,
    );
  }

  static NotificationActionType _parseActionType(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'appointment':
        return NotificationActionType.appointment;

      case 'payment':
        return NotificationActionType.payment;

      case 'chat':
        return NotificationActionType.chat;

      case 'membership':
        return NotificationActionType.membership;

      case 'workshop':
        return NotificationActionType.workshop;

      case 'review':
        return NotificationActionType.review;

      case 'therapistprofile':
        return NotificationActionType.therapistProfile;

      default:
        return NotificationActionType.none;
    }
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

    final parsed = _toInt(value);

    return parsed > 0 ? parsed : null;
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }
}
