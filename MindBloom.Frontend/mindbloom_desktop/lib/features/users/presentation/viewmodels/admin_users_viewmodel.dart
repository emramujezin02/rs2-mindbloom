import 'package:flutter/foundation.dart';
import 'package:mindbloom_desktop/features/users/data/models/update_admin_user_request.dart';

import '../../data/models/admin_user_model.dart';
import '../../data/repositories/admin_users_repository.dart';
import '../../data/models/admin_user_details_model.dart';
import '../../../../core/error/app_error_helper.dart';

class AdminUsersViewModel extends ChangeNotifier {
  final AdminUsersRepository repository;

  AdminUsersViewModel({required this.repository});

  bool isLoading = false;

  bool isUpdatingStatus = false;

  int? updatingUserId;

  String? errorMessage;

  List<AdminUserModel> users = [];

  AdminUserDetailsModel? selectedUser;

  bool isLoadingUserDetails = false;

  bool isSendingPasswordReset = false;

  bool isUpdatingUser = false;

  int? passwordResetUserId;

  int pageNumber = 1;

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  String currentSearch = '';

  String? currentRole;

  bool? currentIsBlocked;

  DateTime? currentRegisteredFrom;

  DateTime? currentRegisteredTo;

  bool get hasPreviousPage => pageNumber > 1;

  bool get hasNextPage => pageNumber < totalPages;

  Future<void> loadUsers({
    int? page,
    String? search,
    String? role,
    bool? isBlocked,
    DateTime? registeredFrom,
    DateTime? registeredTo,
    bool preserveFilters = true,
  }) async {
    if (isLoading) {
      return;
    }

    if (!preserveFilters) {
      currentSearch = search?.trim() ?? '';

      currentRole = _normalizeNullableText(role);

      currentIsBlocked = isBlocked;

      currentRegisteredFrom = registeredFrom;
      currentRegisteredTo = registeredTo;
    } else {
      if (search != null) {
        currentSearch = search.trim();
      }

      if (role != null) {
        currentRole = _normalizeNullableText(role);
      }

      if (registeredFrom != null) {
        currentRegisteredFrom = registeredFrom;
      }

      if (registeredTo != null) {
        currentRegisteredTo = registeredTo;
      }
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await repository.getUsers(
        pageNumber: page ?? pageNumber,
        pageSize: pageSize,
        search: currentSearch,
        role: currentRole,
        isBlocked: currentIsBlocked,
        registeredFrom: currentRegisteredFrom,
        registeredTo: currentRegisteredTo,
      );

      users = result.items;

      pageNumber = result.pageNumber == 0 ? 1 : result.pageNumber;

      pageSize = result.pageSize == 0 ? pageSize : result.pageSize;

      totalCount = result.totalCount;

      totalPages = result.totalPages;
    } catch (error) {
      errorMessage = _cleanError(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilters({
    required String search,
    String? role,
    bool? isBlocked,
    DateTime? registeredFrom,
    DateTime? registeredTo,
  }) {
    currentSearch = search.trim();

    currentRole = _normalizeNullableText(role);

    currentIsBlocked = isBlocked;

    currentRegisteredFrom = registeredFrom;

    currentRegisteredTo = registeredTo;

    return loadUsers(page: 1);
  }

  Future<void> clearFilters() {
    currentSearch = '';

    currentRole = null;

    currentIsBlocked = null;

    currentRegisteredFrom = null;

    currentRegisteredTo = null;

    return loadUsers(page: 1);
  }

  Future<void> goToPreviousPage() {
    if (!hasPreviousPage) {
      return Future.value();
    }

    return loadUsers(page: pageNumber - 1);
  }

  Future<void> goToNextPage() {
    if (!hasNextPage) {
      return Future.value();
    }

    return loadUsers(page: pageNumber + 1);
  }

  Future<void> changePageSize(int newPageSize) {
    pageSize = newPageSize;

    return loadUsers(page: 1);
  }

  Future<bool> updateUserStatus({
    required AdminUserModel user,
    required bool isBlocked,
  }) async {
    if (isUpdatingStatus) {
      return false;
    }

    isUpdatingStatus = true;

    updatingUserId = user.id;

    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateUserStatus(userId: user.id, isBlocked: isBlocked);

      final index = users.indexWhere((item) => item.id == user.id);

      if (index >= 0) {
        users[index] = users[index].copyWith(isBlocked: isBlocked);
      }

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      return false;
    } finally {
      isUpdatingStatus = false;

      updatingUserId = null;

      notifyListeners();
    }
  }

  String? _normalizeNullableText(String? value) {
    final normalized = value?.trim() ?? '';

    return normalized.isEmpty ? null : normalized;
  }

  String _cleanError(Object error) {
    return AppErrorHelper.message(error);
  }

  Future<bool> loadUserDetails(int userId) async {
    if (isLoadingUserDetails) {
      return false;
    }

    isLoadingUserDetails = true;

    errorMessage = null;

    notifyListeners();

    try {
      selectedUser = await repository.getUserDetails(userId);

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      return false;
    } finally {
      isLoadingUserDetails = false;

      notifyListeners();
    }
  }

  Future<bool> sendPasswordReset(int userId) async {
    if (isSendingPasswordReset) {
      return false;
    }

    isSendingPasswordReset = true;

    passwordResetUserId = userId;

    errorMessage = null;

    notifyListeners();

    try {
      await repository.sendPasswordReset(userId);

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      return false;
    } finally {
      isSendingPasswordReset = false;

      passwordResetUserId = null;

      notifyListeners();
    }
  }

  Future<bool> updateUser(int userId, UpdateAdminUserRequest request) async {
    if (isUpdatingUser) {
      return false;
    }

    isUpdatingUser = true;
    errorMessage = null;
    notifyListeners();

    try {
      await repository.updateUser(userId, request);

      await loadUsers();

      await loadUserDetails(userId);

      return true;
    } catch (error) {
      errorMessage = _cleanError(error);

      return false;
    } finally {
      isUpdatingUser = false;
      notifyListeners();
    }
  }
}
