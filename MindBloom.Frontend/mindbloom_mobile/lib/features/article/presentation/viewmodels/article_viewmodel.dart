import 'package:flutter/material.dart';

import '../../../../core/widgets/app_error_message.dart';
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
  String? loadMoreError;
  String? detailsError;
  String? categoriesError;

  List<ArticleModel> articles = [];
  List<ArticleCategoryModel> categories = [];

  ArticleModel? selectedArticle;

  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;

  String currentSearch = '';
  int? selectedArticleCategoryId;

  bool get hasMorePages => pageNumber < totalPages;

  Future<void> loadInitialData() async {
    await Future.wait([loadCategories(), loadArticles()]);
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
      categoriesError = null;
    } catch (exception) {
      categoriesError = AppErrorMessage.from(
        exception,
        fallback: 'Kategorije članaka nije moguće učitati.',
      );
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
    loadMoreError = null;
    pageNumber = 1;

    if (search != null) {
      currentSearch = search.trim();
    }

    notifyListeners();

    try {
      final response = await repository.getArticles(
        pageNumber: 1,
        pageSize: pageSize,
        search: currentSearch,
        articleCategoryId: selectedArticleCategoryId,
      );

      articles = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      error = null;
      loadMoreError = null;
    } catch (exception) {
      error = AppErrorMessage.from(
        exception,
        fallback: 'Članke nije moguće učitati.',
      );
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
    loadMoreError = null;
    notifyListeners();

    try {
      final response = await repository.getArticles(
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
        search: currentSearch,
        articleCategoryId: selectedArticleCategoryId,
      );

      final existingIds = articles.map((article) => article.id).toSet();

      articles.addAll(
        response.items.where((article) => !existingIds.contains(article.id)),
      );

      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
      loadMoreError = null;
    } catch (exception) {
      loadMoreError = AppErrorMessage.from(
        exception,
        fallback: 'Dodatne članke nije moguće učitati.',
      );
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> retryLoadMore() => loadMore();

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

  Future<void> refreshArticles() {
    return loadArticles(search: currentSearch);
  }

  Future<void> loadArticleDetails(int articleId) async {
    if (isLoadingDetails) {
      return;
    }

    isLoadingDetails = true;
    detailsError = null;
    notifyListeners();

    try {
      selectedArticle = await repository.getArticle(articleId);
      detailsError = null;
    } catch (exception) {
      detailsError = AppErrorMessage.from(
        exception,
        fallback: 'Detalje članka nije moguće učitati.',
      );
    } finally {
      isLoadingDetails = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (error == null) return;
    error = null;
    notifyListeners();
  }

  void clearLoadMoreError() {
    if (loadMoreError == null) return;
    loadMoreError = null;
    notifyListeners();
  }

  void clearDetailsError() {
    if (detailsError == null) return;
    detailsError = null;
    notifyListeners();
  }
}
