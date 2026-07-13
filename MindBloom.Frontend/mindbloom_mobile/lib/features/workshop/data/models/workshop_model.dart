class WorkshopModel {
  final int id;
  final String title;
  final String description;
  final DateTime startUtc;
  final DateTime endUtc;
  final String type;
  final String? onlineLink;
  final String? location;
  final int capacity;
  final int registeredCount;
  final int availableSeats;
  final double price;
  final String status;
  final int organizerUserId;
  final String organizerName;
  final int? therapistId;
  final bool isRegistered;
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final String? statusChangeReason;

  WorkshopModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startUtc,
    required this.endUtc,
    required this.type,
    required this.onlineLink,
    required this.location,
    required this.capacity,
    required this.registeredCount,
    required this.availableSeats,
    required this.price,
    required this.status,
    required this.organizerUserId,
    required this.organizerName,
    required this.therapistId,
    required this.isRegistered,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.statusChangeReason,
  });

  factory WorkshopModel.fromJson(Map<String, dynamic> json) {
    final updatedAtValue = json['updatedAtUtc'];

    return WorkshopModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startUtc: DateTime.parse(json['startUtc']),
      endUtc: DateTime.parse(json['endUtc']),
      type: json['type'] ?? '',
      onlineLink: json['onlineLink'],
      location: json['location'],
      capacity: json['capacity'] ?? 0,
      registeredCount: json['registeredCount'] ?? 0,
      availableSeats: json['availableSeats'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      status: json['status'] ?? '',
      organizerUserId: json['organizerUserId'] ?? 0,
      organizerName: json['organizerName'] ?? '',
      therapistId: json['therapistId'] as int?,
      isRegistered: json['isRegistered'] ?? false,
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      updatedAtUtc: updatedAtValue is String && updatedAtValue.isNotEmpty
          ? DateTime.tryParse(updatedAtValue)
          : null,
      statusChangeReason: json['statusChangeReason'],
    );
  }

  bool get isOnline => type.toLowerCase() == 'online';

  bool get isScheduled => status.toLowerCase() == 'scheduled';

  bool get isFull => availableSeats <= 0;

  bool get hasJoinLink => onlineLink != null && onlineLink!.trim().isNotEmpty;
}
