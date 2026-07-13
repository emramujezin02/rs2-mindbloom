import 'package:flutter/material.dart';

import '../../data/models/article_model.dart';
import '../../data/repositories/article_repository.dart';

class ArticleViewModel extends ChangeNotifier {
  final ArticleRepository repository;

  ArticleViewModel({required this.repository});

  bool isLoading = false;
  bool isLoadingMore = false;
  bool isLoadingDetails = false;

  String? error;

  List<ArticleModel> articles = [];

  ArticleModel? selectedArticle;

  int pageNumber = 1;
  final int pageSize = 10;
  int totalPages = 0;

  String currentSearch = '';

  bool get hasMorePages {
    return pageNumber < totalPages;
  }

  Future<void> loadArticles({String search = ''}) async {
    isLoading = true;
    error = null;
    currentSearch = search;
    pageNumber = 1;

    notifyListeners();

    try {
      final response = await repository.getArticles(
        pageNumber: pageNumber,
        pageSize: pageSize,
        search: currentSearch,
      );

      articles = response.items;
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMorePages) {
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
      );

      articles.addAll(response.items);
      pageNumber = response.pageNumber;
      totalPages = response.totalPages;
    } catch (exception) {
      error = exception.toString();
    }

    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadArticleDetails(int articleId) async {
    isLoadingDetails = true;
    error = null;
    selectedArticle = null;

    notifyListeners();

    try {
      selectedArticle = await repository.getArticle(articleId);
    } catch (exception) {
      error = exception.toString();
    }

    isLoadingDetails = false;
    notifyListeners();
  }
}
