import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/features/onboarding/data/models/save_client_onboarding_request.dart';
import 'package:mindbloom_mobile/features/onboarding/data/repositories/client_onboarding_repository.dart';
import 'package:mindbloom_mobile/features/onboarding/data/services/client_onboarding_api_service.dart';
import 'package:mindbloom_mobile/features/onboarding/presentation/pages/client_onboarding_page.dart';
import 'package:mindbloom_mobile/features/onboarding/presentation/viewmodels/client_onboarding_viewmodel.dart';
import 'package:mindbloom_mobile/features/recommendation/data/models/therapist_recommendation_request.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/therapist_profile_model.dart';
import 'package:mindbloom_mobile/features/therapist/data/models/update_therapist_profile_request.dart';
import 'package:mindbloom_mobile/features/therapist/data/services/therapist_api_service.dart';
import 'package:mindbloom_mobile/features/therapist/data/repositories/therapist_repository.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/viewmodels/therapist_profile_viewmodel.dart';
import 'package:mindbloom_mobile/features/therapist/presentation/widgets/therapist_specialization_dropdown.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/repositories/therapy_approach_repository.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/services/therapy_approach_api_service.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  test(
    'profile viewmodel forwards selected reference and reloads its persisted ID',
    () async {
      final api = _Api();
      final model = TherapistProfileViewModel(
        repository: TherapistRepository(
          therapistApiService: TherapistApiService(apiClient: api),
        ),
        therapyApproachRepository: TherapyApproachRepository(
          apiService: TherapyApproachApiService(apiClient: api),
        ),
      );
      final saved = await model.saveProfile(
        specializationId: 9,
        specialization: '',
        biography: 'Keep biography',
        experienceYears: '5',
        hourlyRate: '50',
        location: 'City',
        country: 'Country',
        city: 'City',
        address: 'Keep address',
        locationId: 42,
        worksWithChildren: true,
        offersOnline: true,
        offersInPerson: false,
        languages: ['English'],
        therapyApproachIds: [3],
      );
      expect(saved, isTrue);
      expect(api.saved!['specializationId'], 9);
      expect(api.saved!['locationId'], 42);
      expect(api.saved!['worksWithChildren'], isTrue);
      expect(model.profile!.specializationId, 9);
      model.dispose();
    },
  );
  test(
    'recommendation request preserves missing versus explicitly empty selection',
    () {
      expect(
        const TherapistRecommendationRequest().toJson().containsKey(
          'preferredSpecializationIds',
        ),
        isFalse,
      );
      expect(
        const TherapistRecommendationRequest(
          preferredSpecializationIds: [],
        ).toJson()['preferredSpecializationIds'],
        isEmpty,
      );
      expect(
        const TherapistRecommendationRequest(
          preferredSpecializationIds: [7, 9],
        ).toJson()['preferredSpecializationIds'],
        [7, 9],
      );
    },
  );

  test(
    'profile models preserve reference ID and unrelated location/children values',
    () {
      final profile = TherapistProfileModel.fromJson({
        'specializationId': 7,
        'specialization': 'Chosen',
        'locationId': 42,
        'worksWithChildren': true,
      });
      expect(profile.specializationId, 7);
      final body = UpdateTherapistProfileRequest(
        specializationId: 9,
        locationId: profile.locationId,
        worksWithChildren: profile.worksWithChildren,
        biography: 'Keep',
        specialization: profile.specialization,
        experienceYears: 5,
        hourlyRate: 50,
        location: 'City',
        country: 'C',
        city: 'City',
        address: 'Keep address',
        offersOnline: true,
        offersInPerson: false,
        languages: ['English'],
        therapyApproachIds: [3],
      ).toJson();
      expect(body['specializationId'], 9);
      expect(body['locationId'], 42);
      expect(body['worksWithChildren'], isTrue);
      expect(body['address'], 'Keep address');
    },
  );

  testWidgets(
    'onboarding reloads multiple saved IDs, retains changes between steps and sends actual IDs',
    (tester) async {
      final api = _Api();
      final model = _model(api);
      var completed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ClientOnboardingPage(
            viewModel: model,
            onCompleted: () => completed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var step = 0; step < 5; step++) {
        await _continue(tester);
      }
      final first = find.byKey(const ValueKey('onboarding-specialization-7'));
      final second = find.byKey(const ValueKey('onboarding-specialization-9'));
      expect(tester.widget<CheckboxListTile>(first).value, isTrue);
      tester.widget<CheckboxListTile>(second).onChanged!(true);
      await tester.pumpAndSettle();
      tester.widget<Stepper>(find.byType(Stepper)).onStepCancel!();
      await tester.pumpAndSettle();
      await _continue(tester);
      expect(tester.widget<CheckboxListTile>(second).value, isTrue);
      await _continue(tester);
      tester.widget<Stepper>(find.byType(Stepper)).onStepContinue!();
      await tester.pumpAndSettle();
      expect(api.saved!['preferredSpecializationIds'], [7, 9]);
      expect(api.saved!['preferredLanguages'], ['English']);
      expect(api.saved!['preferredDays'], [1, 3, 5]);
      expect(completed, isTrue);
      expect(api.lookupRequiresAuth, isFalse);
    },
  );

  test(
    'lookup loads complete existing unpaged catalogue, including items beyond first 100',
    () async {
      final api = _Api()
        ..options = List.generate(
          121,
          (i) => {'id': i + 1, 'name': 'Specialization ${i + 1}'},
        );
      final model = _model(api);
      await model.loadSpecializations();
      expect(model.specializations.length, 121);
      expect(model.specializations.last.id, 121);
      model.dispose();
    },
  );

  test(
    'onboarding lookup exposes loading, error, retry and empty states',
    () async {
      final api = _Api()..pending = Completer<dynamic>();
      final model = _model(api);
      final loading = model.loadSpecializations();
      expect(model.isLoadingSpecializations, isTrue);
      api.pending!.completeError(StateError('test failure'));
      await loading;
      expect(model.isLoadingSpecializations, isFalse);
      expect(model.specializationsError, isNotNull);
      api.pending = null;
      api.options = [];
      await model.loadSpecializations();
      expect(model.specializationsError, isNull);
      expect(model.specializations, isEmpty);
      model.dispose();
    },
  );

  testWidgets(
    'profile dropdown preserves an inactive current specialization and permits active replacement',
    (tester) async {
      final api = _Api();
      int? selected = 99;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => TherapistSpecializationDropdown(
                value: selected,
                existingName: 'Inactive existing',
                service: TherapistApiService(apiClient: api),
                onChanged: (id) => setState(() => selected = id),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Inactive existing (raniji izbor)'), findsOneWidget);
      final field = tester.widget<DropdownButtonFormField<int>>(
        find.byType(DropdownButtonFormField<int>),
      );
      final dropdown = tester.widget<DropdownButton<int>>(
        find.byType(DropdownButton<int>),
      );
      expect(
        dropdown.items!.singleWhere((x) => x.value == 99).enabled,
        isFalse,
      );
      field.onChanged!(7);
      await tester.pumpAndSettle();
      expect(selected, 7);
      expect(find.text('First'), findsOneWidget);
    },
  );

  testWidgets(
    'profile dropdown shows retry after API failure and handles empty catalogue',
    (tester) async {
      final api = _Api()..failLookup = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TherapistSpecializationDropdown(
              value: null,
              onChanged: (_) {},
              service: TherapistApiService(apiClient: api),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextButton), findsOneWidget);
      api.failLookup = false;
      api.options = [];
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(find.text('Nema aktivnih specijalizacija.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'onboarding API does not clear preferences when field is omitted and sends explicit clearing',
    () {
      SaveClientOnboardingRequest request(List<int>? ids) =>
          SaveClientOnboardingRequest(
            preferredSpecializationIds: ids,
            assessmentFocusAreas: ['Anxiety'],
            preferredTherapistGender: 'Any',
            preferredSessionType: 'Online',
            preferredLanguages: ['English'],
            minimumPricePerSession: null,
            maximumPricePerSession: null,
            location: 'City',
            preferredDays: [1],
            preferredTherapyApproachIds: [3],
            acceptSensitiveDataProcessing: false,
            sensitiveDataProcessingVersion: 'v1',
          );
      expect(
        request(null).toJson().containsKey('preferredSpecializationIds'),
        isFalse,
      );
      expect(request([]).toJson()['preferredSpecializationIds'], isEmpty);
    },
  );
}

Future<void> _continue(WidgetTester tester) async {
  tester.widget<Stepper>(find.byType(Stepper)).onStepContinue!();
  await tester.pumpAndSettle();
}

ClientOnboardingViewModel _model(_Api api) => ClientOnboardingViewModel(
  repository: ClientOnboardingRepository(
    apiService: ClientOnboardingApiService(apiClient: api),
  ),
  therapyApproachRepository: TherapyApproachRepository(
    apiService: TherapyApproachApiService(apiClient: api),
  ),
);

class _Api extends ApiClient {
  _Api() : super(sessionStorage: SessionStorageService());
  List<Map<String, dynamic>> options = [
    {'id': 7, 'name': 'First'},
    {'id': 9, 'name': 'Second'},
  ];
  bool failLookup = false;
  bool? lookupRequiresAuth;
  Completer<dynamic>? pending;
  Map<String, dynamic>? saved;
  Map<String, dynamic> get onboarding => {
    'hasCompletedOnboarding': true,
    'assessmentFocusAreas': ['Anxiety'],
    'preferredTherapistGender': 'Any',
    'preferredSessionType': 'Online',
    'preferredLanguages': ['English'],
    'preferredDays': [1, 3, 5],
    'preferredSpecializationIds': saved?['preferredSpecializationIds'] ?? [7],
    'preferredTherapyApproachIds': [3],
    'hasAcceptedSensitiveDataProcessing': true,
    'sensitiveDataProcessingVersion': 'v1',
    'currentSensitiveDataProcessingVersion': 'v1',
  };
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    if (endpoint == '/Therapists/profile') {
      return {
        'specializationId': saved?['specializationId'],
        'specialization': 'Second',
      };
    }
    if (endpoint.contains('therapist-specializations')) {
      lookupRequiresAuth = requiresAuth;
      if (failLookup) throw StateError('lookup failed');
      return pending?.future ?? options;
    }
    if (endpoint.contains('therapy-approaches') ||
        endpoint.contains('TherapyApproaches')) {
      return [
        {'id': 3, 'name': 'Approach', 'isActive': true},
      ];
    }
    return onboarding;
  }

  @override
  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    saved = Map<String, dynamic>.from(body as Map);
    return onboarding;
  }
}
