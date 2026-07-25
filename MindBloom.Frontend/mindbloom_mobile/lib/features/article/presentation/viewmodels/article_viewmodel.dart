import 'package:flutter/material.dart';

import '../../data/models/article_category_model.dart';
import '../../data/models/article_model.dart';
import '../../data/repositories/article_repository.dart';

class ArticleViewModel extends ChangeNotifier {
  final ArticleRepository repository;

  ArticleViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isLoadingDetails = false;
  bool isLoadingCategories = false;

  String? error;
  String? categoriesError;

  List<ArticleModel> articles = [];
  List<ArticleCategoryModel> categories = [];

  ArticleModel? selectedArticle;

  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;

  String currentSearch = '';

  int? selectedArticleCategoryId;

  bool get hasMorePages {
    return pageNumber < totalPages;
  }

  Future<void> loadInitialData() async {
    await loadCategories();
    await loadArticles();
  }

  Future<void> loadCategories() async {
    if (isLoadingCategories) {
      return;
    }

    isLoadingCategories = true;
    categoriesError = null;

    notifyListeners();

    try {
      categories = await repository.getCategories();
    } catch (exception) {
      categories = [];
      categoriesError = _normalizeError(exception);
    } finally {
      isLoadingCategories = false;
      notifyListeners();
    }
  }

  Future<void> loadArticles({String? search}) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    error = null;
    pageNumber = 1;

    if (search != null) {
      currentSearch = search.trim();
    }

    notifyListeners();

    try {
      final response = await repository.getArticles(
        pageNumber: pageNumber,
        pageSize: pageSize,
        search: currentSearch,
        articleCategoryId: selectedArticleCategoryId,
      );

      articles = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      articles = [];
      error = _normalizeError(exception);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoading || isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    error = null;

    notifyListeners();

    try {
      final response = await repository.getArticles(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        search: currentSearch,
        articleCategoryId: selectedArticleCategoryId,
      );

      articles.addAll(response.items);
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      error = _normalizeError(exception);
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> searchArticles(String search) async {
    currentSearch = search.trim();

    await loadArticles();
  }

  Future<void> clearSearch() async {
    currentSearch = '';

    await loadArticles();
  }

  Future<void> filterByCategory(int? categoryId) async {
    selectedArticleCategoryId = categoryId;

    await loadArticles();
  }

  Future<void> refreshArticles() async {
    await loadArticles(search: currentSearch);
  }

  Future<void> loadArticleDetails(int articleId) async {
    if (isLoadingDetails) {
      return;
    }

    isLoadingDetails = true;
    error = null;
    selectedArticle = null;

    notifyListeners();

    try {
      selectedArticle = await repository.getArticle(articleId);
    } catch (exception) {
      selectedArticle = null;
      error = _normalizeError(exception);
    } finally {
      isLoadingDetails = false;
      notifyListeners();
    }
  }

  String _normalizeError(Object exception) {
    return exception
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst('FormatException: ', '');
  }
}
