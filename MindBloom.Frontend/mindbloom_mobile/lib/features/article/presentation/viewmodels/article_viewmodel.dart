import 'package:flutter/material.dart';

import '../../data/models/article_model.dart';
import '../../data/repositories/article_repository.dart';

class ArticleViewModel extends ChangeNotifier {
  final ArticleRepository repository;

  ArticleViewModel({required this.repository});

  bool isLoading = false;
  String? error;

  List<ArticleModel> articles = [];

  Future<void> loadArticles() async {
    isLoading = true;
    error = null;

    notifyListeners();

    try {
      articles = await repository.getArticles();
    } catch (e) {
      error = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }
}
