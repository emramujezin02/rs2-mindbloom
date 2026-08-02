import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/models/therapy_approach_model.dart';
import '../../data/models/therapist_specialization_model.dart';
import '../../data/repositories/reference_data_repository.dart';
import '../../data/models/article_category_reference_model.dart';
import '../../../../core/error/app_error_helper.dart';

class ReferenceDataManagementViewModel extends ChangeNotifier {
  final ReferenceDataRepository repository;

  ReferenceDataManagementViewModel({required this.repository});

  final List<TherapistSpecializationModel> specializations = [];
  final List<TherapyApproachModel> therapyApproaches = [];
  bool isLoading = false;

  bool isActionLoading = false;
  String therapyApproachSearch = '';

  bool? therapyApproachActiveFilter;

  int therapyApproachPageNumber = 1;

  int therapyApproachPageSize = 10;

  int therapyApproachTotalCount = 0;

  int therapyApproachTotalPages = 0;

  final List<ArticleCategoryReferenceModel> articleCategories = [];

  String articleCategorySearch = '';

  bool? articleCategoryActiveFilter;

  int articleCategoryPageNumber = 1;

  int articleCategoryPageSize = 10;

  int articleCategoryTotalCount = 0;

  int articleCategoryTotalPages = 0;

  String? errorMessage;

  String search = '';

  bool? activeFilter;

  int pageNumber = 1;

  int pageSize = 10;

  int totalCount = 0;

  int totalPages = 0;

  Timer? _searchDebounce;

  bool get canGoPrevious {
    return pageNumber > 1;
  }

  bool get canGoNext {
    return pageNumber < totalPages;
  }

  Future<void> loadSpecializations({int? requestedPage}) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final response = await repository.getTherapistSpecializations(
        pageNumber: requestedPage ?? pageNumber,
        pageSize: pageSize,
        search: search,
        isActive: activeFilter,
      );

      specializations
        ..clear()
        ..addAll(response.items);

      pageNumber = response.pageNumber;
      pageSize = response.pageSize;
      totalCount = response.totalCount;
      totalPages = response.totalPages;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  void updateSearch(String value) {
    search = value.trim();

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      loadSpecializations(requestedPage: 1);
    });
  }

  Future<void> loadArticleCategories({int? requestedPage}) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final response = await repository.getArticleCategories(
        pageNumber: requestedPage ?? articleCategoryPageNumber,
        pageSize: articleCategoryPageSize,
        search: articleCategorySearch,
        isActive: articleCategoryActiveFilter,
      );

      articleCategories
        ..clear()
        ..addAll(response.items);

      articleCategoryPageNumber = response.pageNumber;
      articleCategoryPageSize = response.pageSize;
      articleCategoryTotalCount = response.totalCount;
      articleCategoryTotalPages = response.totalPages;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> createArticleCategory({
    required String name,
    String? description,
    required bool isActive,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.createArticleCategory(
        name: name,
        description: description,
        isActive: isActive,
      );

      await loadArticleCategories(requestedPage: 1);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateArticleCategory({
    required int id,
    required String name,
    String? description,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateArticleCategory(
        id: id,
        name: name,
        description: description,
      );

      await loadArticleCategories(requestedPage: articleCategoryPageNumber);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateArticleCategoryStatus({
    required ArticleCategoryReferenceModel category,
    required bool isActive,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateArticleCategoryStatus(
        id: category.id,
        isActive: isActive,
      );

      await loadArticleCategories(requestedPage: articleCategoryPageNumber);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> deleteArticleCategory(int id) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.deleteArticleCategory(id);

      final requestedPage =
          articleCategories.length == 1 && articleCategoryPageNumber > 1
          ? articleCategoryPageNumber - 1
          : articleCategoryPageNumber;

      await loadArticleCategories(requestedPage: requestedPage);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<void> loadTherapyApproaches({int? requestedPage}) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final response = await repository.getTherapyApproaches(
        pageNumber: requestedPage ?? therapyApproachPageNumber,
        pageSize: therapyApproachPageSize,
        search: therapyApproachSearch,
        isActive: therapyApproachActiveFilter,
      );

      therapyApproaches
        ..clear()
        ..addAll(response.items);

      therapyApproachPageNumber = response.pageNumber;

      therapyApproachPageSize = response.pageSize;

      therapyApproachTotalCount = response.totalCount;

      therapyApproachTotalPages = response.totalPages;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);
    } finally {
      isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> createTherapyApproach({
    required String name,
    String? description,
    required bool isActive,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.createTherapyApproach(
        name: name,
        description: description,
        isActive: isActive,
      );

      await loadTherapyApproaches(requestedPage: 1);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateTherapyApproach({
    required int id,
    required String name,
    String? description,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateTherapyApproach(
        id: id,
        name: name,
        description: description,
      );

      await loadTherapyApproaches(requestedPage: therapyApproachPageNumber);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateTherapyApproachStatus({
    required TherapyApproachModel approach,
    required bool isActive,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateTherapyApproachStatus(
        id: approach.id,
        isActive: isActive,
      );

      await loadTherapyApproaches(requestedPage: therapyApproachPageNumber);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> deleteTherapyApproach(int id) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.deleteTherapyApproach(id);

      final requestedPage =
          therapyApproaches.length == 1 && therapyApproachPageNumber > 1
          ? therapyApproachPageNumber - 1
          : therapyApproachPageNumber;

      await loadTherapyApproaches(requestedPage: requestedPage);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<void> clearSearch() async {
    _searchDebounce?.cancel();

    search = '';

    await loadSpecializations(requestedPage: 1);
  }

  Future<void> updateActiveFilter(bool? value) async {
    activeFilter = value;

    await loadSpecializations(requestedPage: 1);
  }

  Future<void> changePageSize(int value) async {
    pageSize = value;

    await loadSpecializations(requestedPage: 1);
  }

  Future<void> previousPage() async {
    if (!canGoPrevious || isLoading) {
      return;
    }

    await loadSpecializations(requestedPage: pageNumber - 1);
  }

  Future<void> nextPage() async {
    if (!canGoNext || isLoading) {
      return;
    }

    await loadSpecializations(requestedPage: pageNumber + 1);
  }

  Future<bool> createSpecialization({
    required String name,
    String? description,
    required bool isActive,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.createTherapistSpecialization(
        name: name,
        description: description,
        isActive: isActive,
      );

      await loadSpecializations(requestedPage: 1);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateSpecialization({
    required int id,
    required String name,
    String? description,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateTherapistSpecialization(
        id: id,
        name: name,
        description: description,
      );

      await loadSpecializations(requestedPage: pageNumber);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> updateStatus({
    required TherapistSpecializationModel specialization,
    required bool isActive,
  }) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updateTherapistSpecializationStatus(
        id: specialization.id,
        isActive: isActive,
      );

      await loadSpecializations(requestedPage: pageNumber);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  Future<bool> deleteSpecialization(int id) async {
    if (isActionLoading) {
      return false;
    }
    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.deleteTherapistSpecialization(id);

      final requestedPage = specializations.length == 1 && pageNumber > 1
          ? pageNumber - 1
          : pageNumber;

      await loadSpecializations(requestedPage: requestedPage);

      return true;
    } catch (exception) {
      errorMessage = AppErrorHelper.message(exception);

      return false;
    } finally {
      isActionLoading = false;

      notifyListeners();
    }
  }

  void clearError() {
    if (errorMessage == null) {
      return;
    }

    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
