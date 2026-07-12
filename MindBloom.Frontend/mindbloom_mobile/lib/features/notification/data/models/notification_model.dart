class NotificationModel {
  final int id;

  final String title;

  final String message;

  final bool isRead;

  final DateTime createdAtUtc;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAtUtc,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      isRead: json['isRead'] ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
    );
  }
}
