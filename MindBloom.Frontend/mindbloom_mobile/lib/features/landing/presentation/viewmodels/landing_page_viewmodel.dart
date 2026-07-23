import 'package:flutter/foundation.dart';

import '../../../article/data/models/article_model.dart';
import '../../../article/data/repositories/article_repository.dart';
import '../../../review/data/models/review_model.dart';
import '../../../review/data/repositories/review_repository.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../../../therapist/data/repositories/therapist_repository.dart';
import '../../../therapy_approach/data/models/therapy_approach_model.dart';
import '../../../therapy_approach/data/repositories/therapy_approach_repository.dart';

class LandingPageViewModel extends ChangeNotifier {
  final TherapistRepository therapistRepository;
  final ArticleRepository articleRepository;
  final ReviewRepository reviewRepository;
  final TherapyApproachRepository therapyApproachRepository;

  LandingPageViewModel({
    required this.therapistRepository,
    required this.articleRepository,
    required this.reviewRepository,
    required this.therapyApproachRepository,
  });

  bool isLoading = false;
  bool isArticlesLoading = false;
  bool isReviewsLoading = false;
  bool isTherapyApproachesLoading = false;

  String? errorMessage;
  String? therapistErrorMessage;
  String? articleErrorMessage;
  String? reviewErrorMessage;
  String? therapyApproachErrorMessage;

  List<TherapistModel> therapists = [];
  List<ArticleModel> articles = [];
  List<ReviewModel> reviews = [];
  List<TherapyApproachModel> therapyApproaches = [];

  bool get hasTherapists => therapists.isNotEmpty;

  bool get hasArticles => articles.isNotEmpty;

  bool get hasReviews => reviews.isNotEmpty;

  bool get hasTherapyApproaches => therapyApproaches.isNotEmpty;

  Future<void> loadLandingData() async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    errorMessage = null;
    therapistErrorMessage = null;
    articleErrorMessage = null;
    reviewErrorMessage = null;
    therapyApproachErrorMessage = null;

    notifyListeners();

    await Future.wait([
      _loadTherapyApproaches(),
      _loadTherapists(),
      _loadArticles(),
      _loadReviews(),
    ]);

    if (therapyApproaches.isEmpty &&
        therapists.isEmpty &&
        articles.isEmpty &&
        reviews.isEmpty &&
        (therapyApproachErrorMessage != null ||
            therapistErrorMessage != null ||
            articleErrorMessage != null ||
            reviewErrorMessage != null)) {
      errorMessage = 'Landing page data could not be loaded.';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() {
    return loadLandingData();
  }

  Future<void> retryTherapyApproaches() async {
    if (isTherapyApproachesLoading) {
      return;
    }

    therapyApproachErrorMessage = null;
    notifyListeners();

    await _loadTherapyApproaches();

    notifyListeners();
  }

  Future<void> retryArticles() async {
    if (isArticlesLoading) {
      return;
    }

    articleErrorMessage = null;
    notifyListeners();

    await _loadArticles();

    notifyListeners();
  }

  Future<void> retryReviews() async {
    if (isReviewsLoading) {
      return;
    }

    reviewErrorMessage = null;
    notifyListeners();

    await _loadReviews();

    notifyListeners();
  }

  Future<void> _loadTherapyApproaches() async {
    isTherapyApproachesLoading = true;
    therapyApproachErrorMessage = null;

    try {
      final loadedApproaches = await therapyApproachRepository
          .getPublicTherapyApproaches();

      final activeApproaches =
          loadedApproaches
              .where(
                (approach) =>
                    approach.isActive &&
                    approach.id > 0 &&
                    approach.name.trim().isNotEmpty,
              )
              .toList()
            ..sort(
              (first, second) =>
                  first.name.toLowerCase().compareTo(second.name.toLowerCase()),
            );

      therapyApproaches = activeApproaches;
    } catch (error) {
      therapyApproaches = [];
      therapyApproachErrorMessage = _normalizeError(error);
    } finally {
      isTherapyApproachesLoading = false;
    }
  }

  Future<void> _loadTherapists() async {
    try {
      final loadedTherapists = await therapistRepository.getTherapists();

      final sortedTherapists = List<TherapistModel>.from(loadedTherapists)
        ..sort((first, second) {
          return second.averageRating.compareTo(first.averageRating);
        });

      therapists = sortedTherapists.take(6).toList();
    } catch (error) {
      therapists = [];
      therapistErrorMessage = _normalizeError(error);
    }
  }

  Future<void> _loadArticles() async {
    isArticlesLoading = true;
    articleErrorMessage = null;

    try {
      final response = await articleRepository.getArticles(
        pageNumber: 1,
        pageSize: 6,
      );

      final publishedArticles =
          response.items
              .where(
                (article) =>
                    article.id > 0 &&
                    article.isPublished &&
                    article.title.trim().isNotEmpty &&
                    article.description.trim().isNotEmpty,
              )
              .toList()
            ..sort(
              (first, second) =>
                  second.publishedAtUtc.compareTo(first.publishedAtUtc),
            );

      articles = publishedArticles.take(6).toList();
    } catch (error) {
      articles = [];
      articleErrorMessage = _normalizeError(error);
    } finally {
      isArticlesLoading = false;
    }
  }

  Future<void> _loadReviews() async {
    isReviewsLoading = true;
    reviewErrorMessage = null;

    try {
      final loadedReviews = await reviewRepository.getPublicReviews(limit: 6);

      reviews = loadedReviews
          .where(
            (review) =>
                review.id > 0 &&
                review.rating >= 1 &&
                review.rating <= 5 &&
                review.comment.trim().isNotEmpty &&
                review.therapistName.trim().isNotEmpty,
          )
          .take(6)
          .toList();
    } catch (error) {
      reviews = [];
      reviewErrorMessage = _normalizeError(error);
    } finally {
      isReviewsLoading = false;
    }
  }

  String _normalizeError(Object error) {
    final message = error.toString().trim();

    if (message.startsWith('Exception:')) {
      return message.substring('Exception:'.length).trim();
    }

    return message;
  }
}
