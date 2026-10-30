import 'package:flutter/material.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/article_category_model.dart';
import '../../data/models/article_model.dart';
import '../../data/repositories/article_repository.dart';

class ArticleViewModel extends ChangeNotifier {
  final ArticleRepository repository;
  ArticleViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingDetails = false;
  bool isLoadingCategories = false;
  bool isLoadingRelated = false;
  String? error, detailsError, categoriesError, relatedError;
  List<ArticleModel> articles = [], relatedArticles = [];
  List<ArticleCategoryModel> categories = [];
  ArticleModel? selectedArticle;
  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;
  String currentSearch = '';
  int? selectedArticleCategoryId;
  int _listRequest = 0, _detailRequest = 0, _relatedRequest = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> loadInitialData() async {
    await Future.wait([loadCategories(), loadArticles()]);
  }

  Future<void> loadCategories() async {
    if (_disposed || isLoadingCategories) return;
    isLoadingCategories = true;
    categoriesError = null;
    _notify();
    try {
      final result = await repository.getCategories();
      if (!_disposed) categories = result;
    } catch (exception) {
      if (!_disposed) categoriesError = AppErrorMessage.from(exception);
    } finally {
      isLoadingCategories = false;
      _notify();
    }
  }

  Future<void> loadArticles({String? search}) async {
    if (search != null) currentSearch = search.trim();
    await _fetchPage(1);
  }

  Future<void> goToPage(int page) async {
    if (page < 1 || page > totalPages || page == pageNumber) return;
    await _fetchPage(page);
  }

  Future<void> _fetchPage(int page) async {
    if (_disposed) return;
    final request = ++_listRequest;
    pageNumber = page;
    articles = [];
    isLoading = true;
    error = null;
    _notify();
    try {
      final response = await repository.getArticles(
        pageNumber: page,
        pageSize: pageSize,
        search: currentSearch,
        articleCategoryId: selectedArticleCategoryId,
      );
      if (_disposed || request != _listRequest) return;
      totalPages = response.totalPages;
      // Content may have been removed since the pagination was displayed.
      if (totalPages > 0 && page > totalPages) {
        await _fetchPage(totalPages);
        return;
      }
      pageNumber = totalPages == 0 ? 1 : response.pageNumber;
      articles = response.items;
    } catch (exception) {
      if (!_disposed && request == _listRequest) {
        error = AppErrorMessage.from(
          exception,
          fallback: 'Articles could not be loaded.',
        );
      }
    } finally {
      if (!_disposed && request == _listRequest) {
        isLoading = false;
        _notify();
      }
    }
  }

  Future<void> searchArticles(String search) => loadArticles(search: search);
  Future<void> clearSearch() => loadArticles(search: '');
  Future<void> filterByCategory(int? categoryId) {
    selectedArticleCategoryId = categoryId;
    return loadArticles();
  }

  Future<void> refreshArticles() => _fetchPage(pageNumber);

  Future<void> loadArticleDetails(int articleId) async {
    if (_disposed) return;
    final request = ++_detailRequest;
    ++_relatedRequest;
    selectedArticle = null;
    relatedArticles = [];
    relatedError = null;
    isLoadingRelated = false;
    isLoadingDetails = true;
    detailsError = null;
    _notify();
    try {
      final article = await repository.getArticle(articleId);
      if (_disposed || request != _detailRequest) return;
      selectedArticle = article;
      isLoadingDetails = false;
      _notify();
      await loadRelatedArticles();
    } catch (exception) {
      if (!_disposed && request == _detailRequest) {
        detailsError = AppErrorMessage.from(exception);
      }
    } finally {
      if (!_disposed && request == _detailRequest) {
        isLoadingDetails = false;
        _notify();
      }
    }
  }

  Future<void> loadRelatedArticles() async {
    final article = selectedArticle;
    if (_disposed || article == null || article.articleCategoryId == null) {
      return;
    }
    final request = ++_relatedRequest;
    isLoadingRelated = true;
    relatedError = null;
    _notify();
    try {
      // The public endpoint filters published/non-deleted content in SQL.
      // Four candidates suffice to exclude the current article and retain three.
      final response = await repository.getArticles(
        pageNumber: 1,
        pageSize: 4,
        articleCategoryId: article.articleCategoryId,
      );
      if (_disposed || request != _relatedRequest) return;
      final ids = <int>{article.id};
      relatedArticles = response.items
          .where(
            (item) =>
                item.isPublished &&
                item.articleCategoryId == article.articleCategoryId &&
                ids.add(item.id),
          )
          .take(3)
          .toList();
    } catch (exception) {
      if (!_disposed && request == _relatedRequest) {
        relatedError = AppErrorMessage.from(exception);
      }
    } finally {
      if (!_disposed && request == _relatedRequest) {
        isLoadingRelated = false;
        _notify();
      }
    }
  }
}
