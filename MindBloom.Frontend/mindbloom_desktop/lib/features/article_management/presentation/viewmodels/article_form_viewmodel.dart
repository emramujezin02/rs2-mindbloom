import 'package:flutter/material.dart';
import 'package:mindbloom_desktop/features/article_management/data/models/article_from_request.dart';

import '../../data/models/article_management_model.dart';
import '../../data/repositories/article_management_repository.dart';

class ArticleFormViewModel extends ChangeNotifier {
  final ArticleManagementRepository repository;

  ArticleFormViewModel({required this.repository});

  ArticleManagementModel? article;

  bool isLoading = false;
  bool isSaving = false;

  String? errorMessage;

  Future<bool> loadArticle(int articleId) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      article = await repository.getArticle(articleId);

      return true;
    } catch (error) {
      errorMessage = error.toString();

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveArticle({
    int? articleId,
    required String title,
    required String description,
    required String content,
    required String imageUrl,
    required bool isPublished,
  }) async {
    if (isSaving) {
      return false;
    }

    isSaving = true;
    errorMessage = null;

    notifyListeners();

    try {
      final request = ArticleFormRequest(
        title: title,
        description: description,
        content: content,
        imageUrl: imageUrl.trim().isEmpty ? null : imageUrl.trim(),
        isPublished: isPublished,
      );

      if (articleId == null) {
        article = await repository.createArticle(request);
      } else {
        article = await repository.updateArticle(articleId, request);
      }

      return true;
    } catch (error) {
      errorMessage = error.toString();

      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
