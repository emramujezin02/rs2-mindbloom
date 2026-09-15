import '../../../../core/network/api_client.dart';
import '../models/therapy_approach_model.dart';

class TherapyApproachApiService {
  final ApiClient apiClient;

  TherapyApproachApiService({required this.apiClient});

  Future<List<TherapyApproachModel>> getPublicTherapyApproaches() async {
    final response = await apiClient.get('/TherapyApproaches/public');

    final dynamic items;

    if (response is List) {
      items = response;
    } else if (response is Map<String, dynamic>) {
      items = response['items'] ?? response['data'] ?? [];
    } else {
      throw const FormatException(
        'The server returned an invalid therapy approaches response.',
      );
    }

    if (items is! List) {
      throw const FormatException(
        'The server returned an invalid therapy approaches list.',
      );
    }

    return items
        .whereType<Map>()
        .map(
          (item) =>
              TherapyApproachModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .where(
          (approach) =>
              approach.id > 0 && approach.name.isNotEmpty && approach.isActive,
        )
        .toList();
  }
}
