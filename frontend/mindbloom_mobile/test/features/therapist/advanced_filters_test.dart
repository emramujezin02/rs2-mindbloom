import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/features/favorite/data/repositories/favorite_repository.dart';
import 'package:mindbloom_mobile/features/favorite/data/services/favorite_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_filter_request.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_list_arguments.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_profile_model.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/update_therapist_profile_request.dart';
import 'package:mindbloom_mobile/features/therapist/data/repositories/therapist_repository.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/pages/therapist_list_page.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/pages/therapist_edit_profile_page.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/viewmodels/therapist_profile_viewmodel.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/repositories/therapy_approach_repository.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/services/therapy_approach_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/viewmodels/therapist_list_viewmodel.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/widgets/therapist_location_dropdown.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  testWidgets(
    'profile form sends selected location and children and preserves office address',
    (tester) async {
      final api = _Api();
      final profile = TherapistProfileModel.fromJson(_profileJson);
      final model = TherapistProfileViewModel(
        repository: TherapistRepository(
          therapistApiService: TherapistApiService(apiClient: api),
        ),
        therapyApproachRepository: TherapyApproachRepository(
          apiService: TherapyApproachApiService(apiClient: api),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TherapistEditProfilePage(
                      profile: profile,
                      viewModel: model,
                    ),
                  ),
                ),
                child: const Text('Edit profile'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit profile'));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<int>>(
            find.widgetWithText(DropdownButtonFormField<int>, 'Lokacija'),
          )
          .onChanged!(42);
      await tester.pumpAndSettle();
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Radim s djecom'),
          )
          .onChanged!(true);
      await tester.pumpAndSettle();
      final button = find.widgetWithText(ElevatedButton, 'Save changes');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(api.updates.single['locationId'], 42);
      expect(api.updates.single['worksWithChildren'], isTrue);
      expect(api.updates.single['city'], 'Town 1');
      expect(api.updates.single['country'], 'C');
      expect(api.updates.single['address'], 'Preserved address');
      expect(tester.takeException(), isNull);
    },
  );
  test('experience ranges are exclusive and cover every supported year', () {
    for (var year = 0; year <= 70; year++) {
      expect(
        TherapistExperienceRange.values
            .skip(1)
            .where((x) => x.minimum! <= year && x.maximum! >= year),
        hasLength(1),
      );
    }
  });
  test(
    'query and next page preserve all filters; unchecked checkboxes omit restrictions',
    () {
      const request = TherapistFilterRequest(
        locationId: 42,
        therapyApproachId: 7,
        minExperienceYears: 3,
        maxExperienceYears: 5,
        offersOnline: true,
        worksWithChildren: true,
      );
      final first = request.toQueryParameters();
      final next = request.copyWith(pageNumber: 2).toQueryParameters();
      expect(next, {...first, 'pageNumber': '2'});
      expect(first, containsPair('locationId', '42'));
      expect(first, containsPair('worksWithChildren', 'true'));
      expect(
        const TherapistFilterRequest().toQueryParameters().keys,
        isNot(contains('offersOnline')),
      );
      expect(
        const TherapistFilterRequest().toQueryParameters().keys,
        isNot(contains('worksWithChildren')),
      );
    },
  );
  test(
    'profile parsing and copies preserve location and children; update JSON carries both',
    () {
      final profile = TherapistProfileModel.fromJson({
        'locationId': 42,
        'worksWithChildren': true,
      });
      expect(profile.copyWith(city: 'Town').locationId, 42);
      expect(profile.copyWith(city: 'Town').worksWithChildren, isTrue);
      final request = UpdateTherapistProfileRequest(
        locationId: 42,
        worksWithChildren: true,
        biography: 'Test',
        specialization: 'Test',
        experienceYears: 5,
        hourlyRate: 50,
        location: 'Town',
        country: 'C',
        city: 'Town',
        address: 'Preserved',
        offersOnline: true,
        offersInPerson: false,
        languages: ['Bosnian'],
        therapyApproachIds: [7],
      );
      expect(request.toJson(), containsPair('locationId', 42));
      expect(request.toJson(), containsPair('worksWithChildren', true));
      expect(request.toJson()['address'], 'Preserved');
    },
  );
  test('list pagination and reset keep backend filters consistent', () async {
    final api = _Api();
    final model = _model(api);
    addTearDown(model.dispose);
    await model.searchTherapists(
      locationId: 42,
      therapyApproachId: 7,
      minExperienceYears: 3,
      maxExperienceYears: 5,
      offersOnline: true,
      worksWithChildren: true,
    );
    await model.loadMore();
    final requests = api.searches;
    expect(requests, hasLength(2));
    expect(requests.last.queryParameters, {
      ...requests.first.queryParameters,
      'pageNumber': '2',
    });
    expect(model.therapists.map((x) => x.id), [1, 2]);
    await model.searchTherapists();
    expect(api.searches.last.queryParameters, {
      'pageNumber': '1',
      'pageSize': '10',
    });
  });
  test(
    'a filter changed during loading is applied after the active request',
    () async {
      final pending = Completer<void>();
      final api = _Api()..pending = pending;
      final model = _model(api);
      addTearDown(model.dispose);
      final load = model.searchTherapists(locationId: 42);
      await model.searchTherapists(locationId: 43, worksWithChildren: true);
      pending.complete();
      await load;
      expect(api.searches, hasLength(2));
      expect(api.searches.last.queryParameters['locationId'], '43');
      expect(api.searches.last.queryParameters['worksWithChildren'], 'true');
    },
  );
  test('search and lookup errors are visible and retryable', () async {
    final api = _Api()..fail = true;
    final model = _model(api);
    addTearDown(model.dispose);
    await model.searchTherapists();
    expect(model.errorMessage, isNotNull);
    await model.loadFilterOptions();
    expect(model.optionsError, isNotNull);
    api.fail = false;
    await model.searchTherapists();
    await model.loadFilterOptions();
    expect(model.errorMessage, isNull);
    expect(model.optionsError, isNull);
  });
  testWidgets(
    'initial approach, dropdowns, radio and checkboxes send combined filters and reset',
    (tester) async {
      final api = _Api();
      final model = _model(api);
      await tester.pumpWidget(
        MaterialApp(
          home: TherapistListPage(
            viewModel: model,
            arguments: const TherapistListArguments(
              therapyApproachId: 7,
              therapyApproachName: 'Approach',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Approach'), findsWidgets);
      final location = tester.widget<DropdownButtonFormField<int>>(
        find.widgetWithText(DropdownButtonFormField<int>, 'Lokacija'),
      );
      location.onChanged!(42);
      await tester.pumpAndSettle();
      tester
          .widget<RadioGroup<TherapistExperienceRange>>(
            find.byType(RadioGroup<TherapistExperienceRange>),
          )
          .onChanged(TherapistExperienceRange.developing);
      await tester.pumpAndSettle();
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Online seanse'),
          )
          .onChanged!(true);
      await tester.pumpAndSettle();
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Psihoterapija za djecu'),
          )
          .onChanged!(true);
      await tester.pumpAndSettle();
      expect(
        api.searches.last.queryParameters,
        containsPair('therapyApproachId', '7'),
      );
      expect(
        api.searches.last.queryParameters,
        containsPair('locationId', '42'),
      );
      expect(
        api.searches.last.queryParameters,
        containsPair('minExperienceYears', '3'),
      );
      expect(
        api.searches.last.queryParameters,
        containsPair('maxExperienceYears', '5'),
      );
      expect(
        api.searches.last.queryParameters,
        containsPair('offersOnline', 'true'),
      );
      expect(
        api.searches.last.queryParameters,
        containsPair('worksWithChildren', 'true'),
      );
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Reset all'))
          .onPressed!();
      await tester.pumpAndSettle();
      expect(api.searches.last.queryParameters, {
        'pageNumber': '1',
        'pageSize': '10',
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'location dropdown loads bounded pages and supports an empty result',
    (tester) async {
      final api = _Api()..locationPages = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TherapistLocationDropdown(
              value: null,
              service: TherapistApiService(apiClient: api),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byType(DropdownButtonFormField<int>),
          )
          .onChanged!(-1);
      await tester.pumpAndSettle();
      expect(api.locations.map((x) => x.queryParameters['pageNumber']), [
        '1',
        '2',
      ]);
      expect(
        api.locations.every((x) => x.queryParameters['pageSize'] == '50'),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.emptyLocations = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TherapistLocationDropdown(
              value: null,
              service: TherapistApiService(apiClient: api),
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nema aktivnih lokacija.'), findsOneWidget);
    },
  );
}

TherapistListViewModel _model(_Api api) => TherapistListViewModel(
  therapistRepository: TherapistRepository(
    therapistApiService: TherapistApiService(apiClient: api),
  ),
  favoriteRepository: FavoriteRepository(
    apiService: FavoriteApiService(apiClient: api),
  ),
);

class _Api extends ApiClient {
  final updates = <Map<String, dynamic>>[];
  _Api() : super(sessionStorage: SessionStorageService());
  final searches = <Uri>[], locations = <Uri>[];
  bool fail = false, locationPages = false, emptyLocations = false;
  Completer<void>? pending;
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    if (fail) throw StateError('Test API unavailable');
    final uri = Uri.parse(endpoint);
    if (uri.path == '/Therapists/profile') return _profileJson;
    if (uri.path == '/TherapyApproaches/public') {
      return [
        {'id': 7, 'name': 'Approach', 'isActive': true},
      ];
    }
    if (uri.path == '/Therapists/search') {
      searches.add(uri);
      final wait = pending;
      pending = null;
      if (wait != null) await wait.future;
      final page = int.parse(uri.queryParameters['pageNumber']!);
      return {
        'items': [
          {
            'id': page,
            'fullName': 'Therapist $page',
            'locationId': 42,
            'worksWithChildren': true,
          },
        ],
        'pageNumber': page,
        'pageSize': 10,
        'totalCount': 20,
      };
    }
    if (uri.path.contains('locations/active')) {
      expect(requiresAuth, isFalse);
      locations.add(uri);
      final page = int.parse(uri.queryParameters['pageNumber']!);
      return {
        'items': emptyLocations
            ? []
            : [
                {
                  'id': page == 1 ? 42 : 43,
                  'name': 'Town $page',
                  'country': 'C',
                  'region': 'R',
                  'isActive': true,
                },
              ],
        'pageNumber': page,
        'pageSize': 50,
        'totalCount': locationPages ? 51 : 1,
        'totalPages': locationPages ? 2 : 1,
        'hasNextPage': locationPages && page == 1,
      };
    }
    if (uri.path.contains('therapy-approaches')) {
      return [
        {'id': 7, 'name': 'Approach'},
      ];
    }
    if (uri.path.contains('therapist-specializations')) {
      return [
        {'id': 1, 'name': 'Specialization'},
      ];
    }
    return false;
  }

  @override
  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    updates.add(Map<String, dynamic>.from(body as Map));
    return null;
  }
}

final _profileJson = <String, dynamic>{
  'therapistId': 1,
  'userId': 1,
  'biography': 'Existing biography with enough detail.',
  'specialization': 'Psychotherapy',
  'experienceYears': 5,
  'hourlyRate': 50,
  'location': 'Legacy location',
  'country': 'Old country',
  'city': 'Old city',
  'address': 'Preserved address',
  'offersOnline': true,
  'offersInPerson': false,
  'languages': ['Bosnian'],
  'therapyApproaches': [
    {'id': 7, 'name': 'Approach', 'isActive': true},
  ],
};
