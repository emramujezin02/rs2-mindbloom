import 'package:mindbloom_desktop/features/users/data/models/update_admin_user_request.dart';

import '../../../../core/network/api_client.dart';
import '../models/admin_users_paged_response.dart';
import '../models/admin_user_details_model.dart';

class AdminUsersApiService {
  final ApiClient apiClient;

  AdminUsersApiService({required this.apiClient});

  Future<AdminUsersPagedResponse> getUsers({
    required int pageNumber,
    required int pageSize,
    String? search,
    String? role,
    bool? isBlocked,
    DateTime? registeredFrom,
    DateTime? registeredTo,
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

    if (registeredFrom != null) {
      queryParameters['registeredFrom'] = registeredFrom
          .toUtc()
          .toIso8601String();
    }

    if (registeredTo != null) {
      queryParameters['registeredTo'] = registeredTo.toUtc().toIso8601String();
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

  Future<AdminUserDetailsModel> getUserDetails(int userId) async {
    final response = await apiClient.get('/Admin/users/$userId');

    if (response is! Map<String, dynamic>) {
      throw Exception('Invalid user details response.');
    }

    return AdminUserDetailsModel.fromJson(response);
  }

  Future<void> sendPasswordReset(int userId) async {
    await apiClient.post('/Admin/users/$userId/send-password-reset');
  }

  Future<void> updateUser(int userId, UpdateAdminUserRequest request) async {
    await apiClient.put('/Admin/users/$userId', body: request.toJson());
  }
}
