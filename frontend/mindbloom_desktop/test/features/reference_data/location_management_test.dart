import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/core/network/api_client.dart';
import 'package:mindbloom_desktop/features/reference_data/data/repositories/reference_data_repository.dart';
import 'package:mindbloom_desktop/features/reference_data/data/services/reference_data_api_service.dart';
import 'package:mindbloom_desktop/features/reference_data/presentation/viewmodels/location_management_viewmodel.dart';
import 'package:mindbloom_desktop/features/reference_data/presentation/pages/location_management_page.dart';
import 'package:mindbloom_desktop/services/session_storage_service.dart';

void main() {
  test(
    'location list sends search, activity and bounded page parameters',
    () async {
      final api = _Api();
      final model = _model(api);
      addTearDown(model.dispose);
      model.search = 'Town';
      model.activeFilter = true;
      model.pageSize = 20;
      await model.load(page: 2);
      expect(api.gets.last.queryParameters, {
        'pageNumber': '2',
        'pageSize': '20',
        'search': 'Town',
        'isActive': 'true',
      });
      expect(model.pageNumber, 2);
      expect(model.totalCount, 45);
    },
  );
  test('create and edit carry all fields and refresh page one', () async {
    final api = _Api();
    final model = _model(api);
    addTearDown(model.dispose);
    expect(
      await model.save(
        name: ' Town ',
        country: ' Country ',
        region: ' Region ',
        isActive: true,
      ),
      isTrue,
    );
    expect(api.writes.last.$1, 'POST');
    expect(api.writes.last.$2, '/reference-data/locations');
    expect(api.writes.last.$3, {
      'name': 'Town',
      'country': 'Country',
      'region': 'Region',
      'isActive': true,
    });
    expect(
      await model.save(
        id: 1,
        name: 'Renamed',
        country: 'Country',
        region: 'Region',
        isActive: false,
      ),
      isTrue,
    );
    expect(api.writes.last.$1, 'PUT');
    expect(api.writes.last.$2, '/reference-data/locations/1');
    expect(api.gets.last.queryParameters['pageNumber'], '1');
    expect(model.isSaving, isFalse);
  });
  test('invalid name, country and length do not send requests', () async {
    final api = _Api();
    final model = _model(api);
    addTearDown(model.dispose);
    expect(await model.save(name: '', country: 'C', isActive: true), isFalse);
    expect(await model.save(name: 'T', country: '', isActive: true), isFalse);
    expect(
      await model.save(name: 'x' * 101, country: 'C', isActive: true),
      isFalse,
    );
    expect(api.writes, isEmpty);
    expect(model.error, isNotNull);
  });
  test('delete delegates reference-safe operation and reloads list', () async {
    final api = _Api();
    final model = _model(api);
    addTearDown(model.dispose);
    expect(await model.delete(1), isTrue);
    expect(api.writes.last.$1, 'DELETE');
    expect(api.gets, hasLength(1));
  });
  test('API errors remain visible and loading flags recover', () async {
    final api = _Api()..fail = true;
    final model = _model(api);
    addTearDown(model.dispose);
    await model.load();
    expect(model.error, isNotNull);
    expect(model.isLoading, isFalse);
    expect(
      await model.save(name: 'Town', country: 'Country', isActive: true),
      isFalse,
    );
    expect(model.isSaving, isFalse);
  });
  testWidgets('CRUD page validates create dialog and confirms deactivation', (
    tester,
  ) async {
    final api = _Api();
    final model = _model(api);
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(home: LocationManagementPage(viewModel: model)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Town'), findsOneWidget);
    expect(find.text('Regija/općina'), findsOneWidget);
    await tester.tap(find.text('Dodaj lokaciju'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();
    expect(find.text('Polje je obavezno.'), findsNWidgets(2));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Naziv'),
      'New town',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Država'),
      'Country',
    );
    await tester.tap(find.text('Sačuvaj'));
    await tester.pumpAndSettle();
    expect(api.writes.last.$1, 'POST');
    await tester.tap(find.byTooltip('Deaktiviraj'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('postojeće veze ostaju sačuvane'),
      findsOneWidget,
    );
    expect(api.writes.where((x) => x.$1 == 'DELETE'), isEmpty);
    await tester.tap(find.text('Potvrdi'));
    await tester.pumpAndSettle();
    expect(api.writes.last.$1, 'DELETE');
    expect(tester.takeException(), isNull);
  });
}

LocationManagementViewModel _model(_Api api) => LocationManagementViewModel(
  repository: ReferenceDataRepository(
    apiService: ReferenceDataApiService(apiClient: api),
  ),
);

class _Api extends ApiClient {
  _Api() : super(sessionStorage: SessionStorageService());
  bool fail = false;
  final gets = <Uri>[];
  final writes = <(String, String, Map<String, dynamic>)>[];
  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    if (fail) throw StateError('Unavailable');
    final uri = Uri.parse(endpoint);
    gets.add(uri);
    return {
      'items': [
        {
          'id': 1,
          'name': 'Town',
          'country': 'Country',
          'region': 'Region',
          'isActive': true,
          'therapistCount': 2,
        },
      ],
      'pageNumber': int.parse(uri.queryParameters['pageNumber']!),
      'pageSize': int.parse(uri.queryParameters['pageSize']!),
      'totalCount': 45,
      'totalPages': 5,
    };
  }

  @override
  Future<dynamic> post(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    if (fail) throw StateError('Unavailable');
    writes.add(('POST', endpoint, Map<String, dynamic>.from(body as Map)));
    return {};
  }

  @override
  Future<dynamic> put(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
    String? idempotencyKey,
  }) async {
    writes.add(('PUT', endpoint, Map<String, dynamic>.from(body as Map)));
    return {};
  }

  @override
  Future<dynamic> delete(
    String endpoint, {
    Object? body,
    bool requiresAuth = true,
  }) async {
    writes.add(('DELETE', endpoint, {}));
    return null;
  }
}
