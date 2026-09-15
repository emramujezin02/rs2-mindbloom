import 'package:flutter/material.dart';
import 'package:mindbloom_desktop/features/article_management/data/models/article_form_request.dart';
import '../../data/models/article_category_model.dart';
import '../../data/models/article_management_model.dart';
import '../../data/repositories/article_management_repository.dart';
import '../../../../core/error/app_error_helper.dart';

class ArticleFormViewModel extends ChangeNotifier {
  final ArticleManagementRepository repository;

  ArticleFormViewModel({required this.repository});

  ArticleManagementModel? article;
  final List<ArticleCategoryModel> categories = [];

  bool isLoading = false;
  bool isSaving = false;
  bool isUploadingImage = false;

  String? errorMessage;

  Future<bool> loadArticle(int articleId) async {
    isLoading = true;
    errorMessage = null;

    notifyListeners();

    try {
      article = await repository.getArticle(articleId);

      return true;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loadCategories() async {
    try {
      final result = await repository.getCategories();

      categories
        ..clear()
        ..addAll(result);

      notifyListeners();

      return true;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      notifyListeners();

      return false;
    }
  }

  Future<String?> uploadImage(String filePath) async {
    if (isUploadingImage) {
      return null;
    }

    isUploadingImage = true;
    errorMessage = null;

    notifyListeners();

    try {
      return await repository.uploadArticleImage(filePath);
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      return null;
    } finally {
      isUploadingImage = false;

      notifyListeners();
    }
  }

  Future<bool> saveArticle({
    int? articleId,
    required String title,
    required String description,
    required String content,
    required String imageUrl,
    required int articleCategoryId,
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
        articleCategoryId: articleCategoryId,
      );

      if (articleId == null) {
        article = await repository.createArticle(request);
      } else {
        article = await repository.updateArticle(articleId, request);
      }

      return true;
    } catch (error) {
      errorMessage = AppErrorHelper.message(error);

      return false;
    } finally {
      isSaving = false;
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
}
