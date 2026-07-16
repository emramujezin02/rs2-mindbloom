import '../models/admin_users_paged_response.dart';
import '../services/admin_users_api_service.dart';

class AdminUsersRepository {
  final AdminUsersApiService apiService;

  AdminUsersRepository({required this.apiService});

  Future<AdminUsersPagedResponse> getUsers({
    required int pageNumber,
    required int pageSize,
    String? search,
    String? role,
    bool? isBlocked,
  }) {
    return apiService.getUsers(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      role: role,
      isBlocked: isBlocked,
    );
  }

  Future<void> updateUserStatus({
    required int userId,
    required bool isBlocked,
  }) {
    return apiService.updateUserStatus(userId: userId, isBlocked: isBlocked);
  }
}
