import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/features/article/data/repositories/article_repository.dart';
import 'package:mindbloom_mobile/features/article/data/services/article_api_service.dart';
import 'package:mindbloom_mobile/features/landing/presentation/viewmodels/landing_page_viewmodel.dart';
import 'package:mindbloom_mobile/features/review/data/repositories/review_repository.dart';
import 'package:mindbloom_mobile/features/review/data/services/review_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/data/repositories/therapist_repository.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/repositories/therapy_approach_repository.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/services/therapy_approach_api_service.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  test('API parses therapist page metadata and card data', () async {
    final client = _LandingApiClient(
      _page([_therapist(1, 4.5)], totalCount: 20),
    );
    final page = await TherapistApiService(
      apiClient: client,
    ).getTherapists(page: 1, pageSize: 6);
    expect(page.pageNumber, 1);
    expect(page.pageSize, 6);
    expect(page.totalCount, 20);
    expect(page.hasNextPage, isTrue);
    final therapist = page.items.single;
    expect(therapist.fullName, 'Therapist 1');
    expect(therapist.specialization, 'Psychotherapy');
    expect(therapist.averageRating, 4.5);
    expect(therapist.totalReviews, 2);
    expect(therapist.profileImageUrl, '/uploads/therapist-1.jpg');
  });

  test(
    'slider requests only page one with six items even when more pages exist',
    () async {
      final client = _LandingApiClient(
        _page([
          for (var id = 1; id <= 6; id++) _therapist(id, id / 2),
        ], totalCount: 40),
      );
      final model = _viewModel(client);
      addTearDown(model.dispose);

      await model.loadLandingData();

      final therapistRequests = client.requests
          .where((uri) => uri.path == '/Therapists')
          .toList();
      expect(therapistRequests, hasLength(1));
      expect(therapistRequests.single.queryParameters, {
        'Page': '1',
        'PageSize': '6',
      });
      expect(model.therapists, hasLength(6));
      expect(model.therapists.first.id, 6);
      expect(model.therapists.last.id, 1);
      expect(model.therapistErrorMessage, isNull);
      expect(model.isLoading, isFalse);
    },
  );

  test('empty first page leaves slider empty without an API error', () async {
    final model = _viewModel(_LandingApiClient(_page([])));
    addTearDown(model.dispose);
    await model.loadLandingData();
    expect(model.therapists, isEmpty);
    expect(model.therapistErrorMessage, isNull);
    expect(model.isLoading, isFalse);
  });

  test(
    'API failure is reported and does not trigger loading another page',
    () async {
      final client = _LandingApiClient(_page([]), failTherapists: true);
      final model = _viewModel(client);
      addTearDown(model.dispose);
      await model.loadLandingData();
      expect(model.therapists, isEmpty);
      expect(model.therapistErrorMessage, isNotNull);
      expect(model.isLoading, isFalse);
      expect(
        client.requests.where((uri) => uri.path == '/Therapists'),
        hasLength(1),
      );
    },
  );

  test('API rejects the old unpaginated array response', () async {
    final client = _LandingApiClient([]);
    await expectLater(
      TherapistApiService(apiClient: client).getTherapists(),
      throwsFormatException,
    );
  });
}

LandingPageViewModel _viewModel(_LandingApiClient client) =>
    LandingPageViewModel(
      therapistRepository: TherapistRepository(
        therapistApiService: TherapistApiService(apiClient: client),
      ),
      articleRepository: ArticleRepository(
        apiService: ArticleApiService(apiClient: client),
      ),
      reviewRepository: ReviewRepository(
        apiService: ReviewApiService(apiClient: client),
      ),
      therapyApproachRepository: TherapyApproachRepository(
        apiService: TherapyApproachApiService(apiClient: client),
      ),
    );

Map<String, dynamic> _therapist(int id, double rating) => {
  'id': id,
  'fullName': 'Therapist $id',
  'specialization': 'Psychotherapy',
  'averageRating': rating,
  'totalReviews': 2,
  'profileImageUrl': '/uploads/therapist-$id.jpg',
};

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  int totalCount = 0,
}) => {
  'items': items,
  'pageNumber': 1,
  'pageSize': 6,
  'totalCount': totalCount,
  'totalPages': (totalCount / 6).ceil(),
  'hasPreviousPage': false,
  'hasNextPage': totalCount > 6,
};

class _LandingApiClient extends ApiClient {
  final dynamic therapistResponse;
  final bool failTherapists;
  final requests = <Uri>[];

  _LandingApiClient(this.therapistResponse, {this.failTherapists = false})
    : super(sessionStorage: SessionStorageService());

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    final uri = Uri.parse(endpoint);
    requests.add(uri);
    if (uri.path == '/Therapists') {
      if (failTherapists) throw StateError('API unavailable');
      return therapistResponse;
    }
    if (uri.path == '/Articles') return _page([]);
    return <dynamic>[];
  }
}
