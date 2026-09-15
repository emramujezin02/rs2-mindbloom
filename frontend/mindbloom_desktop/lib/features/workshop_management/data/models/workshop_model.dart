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
  final DateTime createdAtUtc;
  final DateTime? updatedAtUtc;
  final String? statusChangeReason;
  final String? imageUrl;
  final String? therapistName;

  final DateTime registrationDeadlineUtc;

  const WorkshopModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startUtc,
    required this.therapistName,
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
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.statusChangeReason,
    required this.imageUrl,
    required this.registrationDeadlineUtc,
  });

  factory WorkshopModel.fromJson(Map<String, dynamic> json) {
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
      price: (json['price'] as num?)?.toDouble() ?? 0,
      status: json['status'] ?? '',
      therapistName: json['therapistName']?.toString(),
      organizerUserId: json['organizerUserId'] ?? 0,
      organizerName: json['organizerName'] ?? '',
      therapistId: json['therapistId'],
      imageUrl: json['imageUrl']?.toString(),

      registrationDeadlineUtc: DateTime.parse(json['registrationDeadlineUtc']),
      createdAtUtc: DateTime.parse(json['createdAtUtc']),
      updatedAtUtc: json['updatedAtUtc'] == null
          ? null
          : DateTime.parse(json['updatedAtUtc']),
      statusChangeReason: json['statusChangeReason'],
    );
  }

  bool get isScheduled {
    return status.toLowerCase() == 'scheduled';
  }

  bool get isCancelled {
    return status.toLowerCase() == 'cancelled';
  }

  bool get isCompleted {
    return status.toLowerCase() == 'completed';
  }

  bool get isOnline {
    return type.toLowerCase() == 'online';
  }

  bool get isInactive {
    return status.toLowerCase() == 'inactive';
  }

  Duration get duration {
    return endUtc.difference(startUtc);
  }

  String get presenterName {
    final therapist = therapistName?.trim() ?? '';

    if (therapist.isNotEmpty) {
      return therapist;
    }

    return organizerName;
  }
}
