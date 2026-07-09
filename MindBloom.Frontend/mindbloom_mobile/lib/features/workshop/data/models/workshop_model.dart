class WorkshopModel {
  final int id;
  final String title;
  final String description;
  final DateTime startDate;
  final int availableSeats;

  WorkshopModel({
    required this.id,
    required this.title,
    required this.description,
    required this.startDate,
    required this.availableSeats,
  });

  factory WorkshopModel.fromJson(Map<String, dynamic> json) {
    return WorkshopModel(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      startDate: DateTime.parse(json['startDate']),
      availableSeats: json['availableSeats'] ?? 0,
    );
  }
}
