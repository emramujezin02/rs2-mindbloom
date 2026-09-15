import 'admin_payment_model.dart';

class AdminPaymentPagedResponse {
  final List<AdminPaymentModel> items;

  final int pageNumber;

  final int pageSize;

  final int totalCount;

  final int totalPages;

  const AdminPaymentPagedResponse({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory AdminPaymentPagedResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? [];

    return AdminPaymentPagedResponse(
      items: rawItems
          .map(
            (item) => AdminPaymentModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
      pageNumber: json['pageNumber'] ?? 1,
      pageSize: json['pageSize'] ?? 10,
      totalCount: json['totalCount'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
    );
  }
}
