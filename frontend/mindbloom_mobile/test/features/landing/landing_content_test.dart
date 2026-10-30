import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/app/router/app_router.dart';
import 'package:mindbloom_mobile/features/appointment/data/models/appointment_model.dart';
import 'package:mindbloom_mobile/features/review/presentation/pages/create_review_page.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/features/article/data/repositories/article_repository.dart';
import 'package:mindbloom_mobile/features/article/data/services/article_api_service.dart';
import 'package:mindbloom_mobile/features/article/presentation/pages/article_details_page.dart';
import 'package:mindbloom_mobile/features/article/presentation/viewmodels/article_viewmodel.dart';
import 'package:mindbloom_mobile/features/landing/presentation/pages/landing_page.dart';
import 'package:mindbloom_mobile/features/landing/presentation/viewmodels/landing_page_viewmodel.dart';
import 'package:mindbloom_mobile/features/review/data/models/create_review_request.dart';
import 'package:mindbloom_mobile/features/review/data/models/update_review_request.dart';
import 'package:mindbloom_mobile/features/review/data/models/review_model.dart';
import 'package:mindbloom_mobile/features/review/data/repositories/review_repository.dart';
import 'package:mindbloom_mobile/features/review/data/services/review_api_service.dart';
import 'package:mindbloom_mobile/features/review/presentation/pages/edit_review_page.dart';
import 'package:mindbloom_mobile/features/review/presentation/viewmodels/create_review_viewmodel.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_list_arguments.dart';
import 'package:mindbloom_mobile/features/therapist/data/repositories/therapist_repository.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/repositories/therapy_approach_repository.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/services/therapy_approach_api_service.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  test(
    'new reviews default to no consent; edits explicitly withdraw or preserve it',
    () {
      expect(
        CreateReviewRequest(
          appointmentId: 1,
          rating: 5,
          comment: 'Useful',
        ).toJson()['shareAuthorDemographics'],
        false,
      );
      expect(
        const UpdateReviewRequest(
          rating: 5,
          comment: 'Useful',
        ).toJson().containsKey('shareAuthorDemographics'),
        false,
      );
      expect(
        const UpdateReviewRequest(
          rating: 5,
          comment: 'Useful',
          shareAuthorDemographics: false,
        ).toJson()['shareAuthorDemographics'],
        false,
      );
    },
  );

  for (final consent in [true, false]) {
    testWidgets(
      'edit review submits consent=$consent without changing comment',
      (tester) async {
        final api = _Api();
        final model = CreateReviewViewModel(
          repository: ReviewRepository(
            apiService: ReviewApiService(apiClient: api),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: EditReviewPage(
              viewModel: model,
              review: ReviewModel.fromJson({
                ..._review,
                'shareAuthorDemographics': !consent,
              }),
            ),
          ),
        );
        final checkbox = find.byKey(const Key('review-demographics-consent'));
        await tester.ensureVisible(checkbox);
        await tester.tap(checkbox);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Save changes'));
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(api.saved?['shareAuthorDemographics'], consent);
        expect(api.saved?['comment'], _review['comment']);
        expect(api.writes, 1);
      },
    );
  }

  testWidgets(
    'new review consent is optional and explicitly sent after choosing it',
    (tester) async {
      final api = _Api();
      final model = CreateReviewViewModel(
        repository: ReviewRepository(
          apiService: ReviewApiService(apiClient: api),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CreateReviewPage(
            viewModel: model,
            appointment: AppointmentModel.fromJson({
              'id': 7,
              'therapistName': 'Test Therapist',
              'status': 'Completed',
              'startUtc': '2026-10-29T10:00:00Z',
              'endUtc': '2026-10-29T11:00:00Z',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final checkbox = find.byKey(const Key('review-demographics-consent'));
      expect(tester.widget<CheckboxListTile>(checkbox).value, false);
      await tester.enterText(find.byType(TextFormField), 'A helpful session.');
      await tester.ensureVisible(checkbox);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Submit review'));
      await tester.tap(find.text('Submit review'));
      await tester.pumpAndSettle();
      expect(api.saved?['shareAuthorDemographics'], true);
      expect(api.saved?['appointmentId'], 7);
      expect(api.writes, 1);
    },
  );

  testWidgets(
    'article and therapist actions keep separate explicit IDs and support back navigation',
    (tester) async {
      final api = _Api();
      RouteSettings? lastRoute;
      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(viewModel: _landing(api)),
          onGenerateRoute: (settings) {
            lastRoute = settings;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => settings.name == AppRouter.articleDetails
                  ? ArticleDetailsPage(
                      articleId: settings.arguments! as int,
                      viewModel: ArticleViewModel(
                        repository: ArticleRepository(
                          apiService: ArticleApiService(apiClient: api),
                        ),
                      ),
                    )
                  : Scaffold(appBar: AppBar(title: const Text('Therapists'))),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cognitive Behavioral Therapy'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('approach-article-1')),
      );
      await tester.tap(find.byKey(const ValueKey('approach-article-1')));
      await tester.pumpAndSettle();
      expect(lastRoute?.arguments, 91);
      expect(lastRoute?.name, AppRouter.articleDetails);
      expect(find.text('Verified CBT article'), findsWidgets);
      expect(api.articleIds, [91]);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('approach-therapists-1')),
      );
      await tester.tap(find.byKey(const ValueKey('approach-therapists-1')));
      await tester.pumpAndSettle();
      final args = lastRoute?.arguments as TherapistListArguments;
      expect(args.therapyApproachId, 1);
      expect(args.therapyApproachName, 'Cognitive Behavioral Therapy');
      expect(lastRoute?.name, AppRouter.therapists);
    },
  );

  testWidgets(
    'missing article disables only learn-more; all four approaches remain visible',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(viewModel: _landing(_Api(linked: false))),
        ),
      );
      await tester.pumpAndSettle();
      for (var id = 1; id <= 4; id++) {
        final button = find.byKey(ValueKey('approach-article-$id'));
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        expect(
          tester
              .widget<TextButton>(
                find.byKey(ValueKey('approach-therapists-$id')),
              )
              .onPressed,
          isNotNull,
        );
      }
    },
  );

  for (final demographics in [
    <String, dynamic>{'authorGender': 'Female', 'authorAge': 30},
    <String, dynamic>{'authorGender': 'Female'},
    <String, dynamic>{'authorAge': 30},
    <String, dynamic>{},
  ]) {
    testWidgets(
      'small screen review safely renders available demographics $demographics',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: LandingPage(
              viewModel: _landing(_Api(demographics: demographics)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Therapist: Test Therapist'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('30 years old'),
          demographics.containsKey('authorAge') ? findsOneWidget : findsNothing,
        );
        expect(
          find.textContaining('Female'),
          demographics.containsKey('authorGender')
              ? findsOneWidget
              : findsNothing,
        );
        expect(find.text('A helpful session.'), findsOneWidget);
        expect(find.text('null'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'landing section error offers retry without navigating to unrelated content',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LandingPage(viewModel: _landing(_Api(failApproaches: true))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('approach-article-1')), findsNothing);
      expect(find.text('Section could not be loaded'), findsWidgets);
    },
  );
}

const _review = {
  'id': 1,
  'rating': 5,
  'clientInitials': 'A. M.',
  'therapistName': 'Test Therapist',
  'comment': 'A helpful session.',
  'createdAtUtc': '2026-10-30T12:00:00Z',
};
LandingPageViewModel _landing(_Api api) => LandingPageViewModel(
  therapistRepository: TherapistRepository(
    therapistApiService: TherapistApiService(apiClient: api),
  ),
  articleRepository: ArticleRepository(
    apiService: ArticleApiService(apiClient: api),
  ),
  reviewRepository: ReviewRepository(
    apiService: ReviewApiService(apiClient: api),
  ),
  therapyApproachRepository: TherapyApproachRepository(
    apiService: TherapyApproachApiService(apiClient: api),
  ),
);

class _Api extends ApiClient {
  final bool linked;
  final bool failApproaches;
  final Map<String, dynamic> demographics;
  final articleIds = <int>[];
  Map<String, dynamic>? saved;
  int writes = 0;
  _Api({
    this.linked = true,
    this.failApproaches = false,
    this.demographics = const {},
  }) : super(sessionStorage: SessionStorageService());
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    final path = Uri.parse(endpoint).path;
    if (path.startsWith('/Reviews/eligibility/')) {
      return {'appointmentId': 7, 'canReview': true, 'message': 'Allowed'};
    }
    if (path.contains('therapy-approaches') ||
        path.contains('TherapyApproaches')) {
      if (failApproaches) throw StateError('Unavailable');
      return [
        for (var id = 1; id <= 4; id++)
          {
            'id': id,
            'name': [
              'Cognitive Behavioral Therapy',
              'Gestalt Therapy',
              'Person-Centered Therapy',
              'Acceptance and Commitment Therapy',
            ][id - 1],
            'description': 'Education',
            'isActive': true,
            if (linked) 'featuredArticleId': id + 90,
          },
      ];
    }
    if (path == '/Reviews/public') {
      return [
        {..._review, ...demographics},
      ];
    }
    if (path.startsWith('/Articles/')) {
      expect(requiresAuth, false);
      articleIds.add(int.parse(path.split('/').last));
      return {
        'id': 91,
        'title': 'Verified CBT article',
        'content': 'An educational introduction.',
        'description': 'Summary',
        'createdAtUtc': '2026-10-30T12:00:00Z',
      };
    }
    return {
      'items': [],
      'totalCount': 0,
      'pageNumber': 1,
      'pageSize': 6,
      'totalPages': 0,
    };
  }

  @override
  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    saved = body as Map<String, dynamic>?;
    writes++;
    return {};
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    saved = body as Map<String, dynamic>?;
    writes++;
    return {};
  }
}
