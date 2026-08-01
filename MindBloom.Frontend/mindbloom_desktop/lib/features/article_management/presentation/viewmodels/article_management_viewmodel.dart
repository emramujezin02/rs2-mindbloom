import 'dart:async';

import 'package:flutter/material.dart';
import '../../data/models/article_category_model.dart';
import '../../data/models/article_management_model.dart';
import '../../data/repositories/article_management_repository.dart';

class ArticleManagementViewModel extends ChangeNotifier {
  final ArticleManagementRepository repository;

  ArticleManagementViewModel({required this.repository});

  final List<ArticleManagementModel> articles = [];
  final List<ArticleCategoryModel> categories = [];

  Timer? _searchDebounce;

  bool isLoading = false;
  bool isActionLoading = false;

  String? errorMessage;

  String search = '';
  bool? publishedFilter;
  int? categoryFilter;

  int pageNumber = 1;
  int pageSize = 10;
  int totalCount = 0;
  int totalPages = 0;

  bool get canGoPrevious {
    return pageNumber > 1;
  }

  bool get canGoNext {
    return pageNumber < totalPages;
  }

  Future<void> loadCategories() async {
    try {
      final result = await repository.getCategories();

      categories
        ..clear()
        ..addAll(result);
    } catch (error) {
      errorMessage = error.toString();
    }

    notifyListeners();
  }

  Future<void> loadArticles({int? requestedPage}) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      final response = await repository.getArticles(
        pageNumber: requestedPage ?? pageNumber,
        pageSize: pageSize,
        search: search,
        isPublished: publishedFilter,
        articleCategoryId: categoryFilter,
      );

      articles
        ..clear()
        ..addAll(response.items);

      pageNumber = response.pageNumber;

      pageSize = response.pageSize;

      totalCount = response.totalCount;

      totalPages = response.totalPages;
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void updateSearch(String value) {
    search = value.trim();

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      loadArticles(requestedPage: 1);
    });
  }

  Future<void> clearSearch() async {
    _searchDebounce?.cancel();

    search = '';

    await loadArticles(requestedPage: 1);
  }

  Future<void> updateCategoryFilter(int? value) async {
    categoryFilter = value;

    await loadArticles(requestedPage: 1);
  }

  Future<void> updatePublishedFilter(bool? value) async {
    publishedFilter = value;

    await loadArticles(requestedPage: 1);
  }

  Future<void> changePageSize(int value) async {
    pageSize = value;

    await loadArticles(requestedPage: 1);
  }

  Future<void> previousPage() async {
    if (!canGoPrevious) {
      return;
    }

    await loadArticles(requestedPage: pageNumber - 1);
  }

  Future<void> nextPage() async {
    if (!canGoNext) {
      return;
    }

    await loadArticles(requestedPage: pageNumber + 1);
  }

  Future<bool> updatePublication({
    required ArticleManagementModel article,
    required bool isPublished,
  }) async {
    if (isActionLoading) {
      return false;
    }

    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.updatePublication(
        articleId: article.id,
        isPublished: isPublished,
      );

      await loadArticles(requestedPage: pageNumber);

      return true;
    } catch (error) {
      errorMessage = error.toString();

      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteArticle(int articleId) async {
    if (isActionLoading) {
      return false;
    }

    isActionLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      await repository.deleteArticle(articleId);

      final requestedPage = articles.length == 1 && pageNumber > 1
          ? pageNumber - 1
          : pageNumber;

      await loadArticles(requestedPage: requestedPage);

      return true;
    } catch (error) {
      errorMessage = error.toString();

      return false;
    } finally {
      isActionLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();

    super.dispose();
  }
}
