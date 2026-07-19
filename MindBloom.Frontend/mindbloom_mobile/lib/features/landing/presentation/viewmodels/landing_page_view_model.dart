import 'package:flutter/foundation.dart';

import '../../../article/data/models/article_model.dart';
import '../../../article/data/repositories/article_repository.dart';
import '../../../review/data/models/review_model.dart';
import '../../../review/data/repositories/review_repository.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../../../therapist/data/repositories/therapist_repository.dart';

class LandingPageViewModel extends ChangeNotifier {
  final TherapistRepository therapistRepository;
  final ArticleRepository articleRepository;
  final ReviewRepository reviewRepository;

  LandingPageViewModel({
    required this.therapistRepository,
    required this.articleRepository,
    required this.reviewRepository,
  });

  bool isLoading = false;

  String? errorMessage;
  String? therapistErrorMessage;
  String? articleErrorMessage;
  String? reviewErrorMessage;

  List<TherapistModel> therapists = [];
  List<ArticleModel> articles = [];
  List<ReviewModel> reviews = [];

  bool get hasTherapists => therapists.isNotEmpty;

  bool get hasArticles => articles.isNotEmpty;

  bool get hasReviews => reviews.isNotEmpty;

  Future<void> loadLandingData() async {
    if (isLoading) {
      return;
    }

    isLoading = true;

    errorMessage = null;
    therapistErrorMessage = null;
    articleErrorMessage = null;
    reviewErrorMessage = null;

    notifyListeners();

    await Future.wait([_loadTherapists(), _loadArticles()]);

    await _loadReviews();

    if (therapists.isEmpty &&
        articles.isEmpty &&
        reviews.isEmpty &&
        (therapistErrorMessage != null ||
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
    try {
      final response = await articleRepository.getArticles(
        pageNumber: 1,
        pageSize: 6,
      );

      articles = response.items.take(6).toList();
    } catch (error) {
      articles = [];
      articleErrorMessage = _normalizeError(error);
    }
  }

  Future<void> _loadReviews() async {
    reviews = [];

    if (therapists.isEmpty) {
      return;
    }

    try {
      final therapistsForReviews = therapists.take(5).toList();

      final results = await Future.wait(
        therapistsForReviews.map((therapist) async {
          try {
            return await reviewRepository.getTherapistReviews(therapist.id);
          } catch (_) {
            return <ReviewModel>[];
          }
        }),
      );

      final loadedReviews =
          results
              .expand((therapistReviews) => therapistReviews)
              .where(
                (review) =>
                    review.rating > 0 && review.comment.trim().isNotEmpty,
              )
              .toList()
            ..sort((first, second) {
              return second.createdAtUtc.compareTo(first.createdAtUtc);
            });

      reviews = loadedReviews.take(6).toList();
    } catch (error) {
      reviews = [];
      reviewErrorMessage = _normalizeError(error);
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
