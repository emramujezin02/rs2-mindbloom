import 'package:mindbloom_desktop/features/users/data/models/update_admin_user_request.dart';

import '../models/admin_users_paged_response.dart';
import '../services/admin_users_api_service.dart';
import '../models/admin_user_details_model.dart';

class AdminUsersRepository {
  final AdminUsersApiService apiService;

  AdminUsersRepository({required this.apiService});

  Future<AdminUsersPagedResponse> getUsers({
    required int pageNumber,
    required int pageSize,
    String? search,
    String? role,
    bool? isBlocked,
    DateTime? registeredFrom,
    DateTime? registeredTo,
  }) {
    return apiService.getUsers(
      pageNumber: pageNumber,
      pageSize: pageSize,
      search: search,
      role: role,
      isBlocked: isBlocked,
      registeredFrom: registeredFrom,
      registeredTo: registeredTo,
    );
  }

  Future<void> updateUserStatus({
    required int userId,
    required bool isBlocked,
  }) {
    return apiService.updateUserStatus(userId: userId, isBlocked: isBlocked);
  }

  Future<AdminUserDetailsModel> getUserDetails(int userId) {
    return apiService.getUserDetails(userId);
  }

  Future<void> sendPasswordReset(int userId) {
    return apiService.sendPasswordReset(userId);
  }

  Future<void> updateUser(int userId, UpdateAdminUserRequest request) {
    return apiService.updateUser(userId, request);
  }
}
