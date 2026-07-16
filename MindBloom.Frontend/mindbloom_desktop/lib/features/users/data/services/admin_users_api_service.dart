import '../../../../core/network/api_client.dart';
import '../models/admin_users_paged_response.dart';

class AdminUsersApiService {
  final ApiClient apiClient;

  AdminUsersApiService({required this.apiClient});

  Future<AdminUsersPagedResponse> getUsers({
    required int pageNumber,
    required int pageSize,
    String? search,
    String? role,
    bool? isBlocked,
  }) async {
    final queryParameters = <String, String>{
      'pageNumber': pageNumber.toString(),
      'pageSize': pageSize.toString(),
    };

    final normalizedSearch = search?.trim() ?? '';

    final normalizedRole = role?.trim() ?? '';

    if (normalizedSearch.isNotEmpty) {
      queryParameters['search'] = normalizedSearch;
    }

    if (normalizedRole.isNotEmpty) {
      queryParameters['role'] = normalizedRole;
    }

    if (isBlocked != null) {
      queryParameters['isBlocked'] = isBlocked.toString();
    }

    final uri = Uri(path: '/Admin/users', queryParameters: queryParameters);

    final response = await apiClient.get(uri.toString());

    if (response is! Map<String, dynamic>) {
      throw Exception('The server returned invalid user data.');
    }

    return AdminUsersPagedResponse.fromJson(response);
  }

  Future<void> updateUserStatus({
    required int userId,
    required bool isBlocked,
  }) async {
    await apiClient.put(
      '/Admin/users/$userId/status',
      body: {'isBlocked': isBlocked},
    );
  }
}
