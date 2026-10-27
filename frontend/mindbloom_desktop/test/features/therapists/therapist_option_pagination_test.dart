import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/core/network/api_client.dart';
import 'package:mindbloom_desktop/features/reports/data/services/admin_report_api_service.dart';
import 'package:mindbloom_desktop/features/workshop_management/data/services/workshop_management_api_service.dart';
import 'package:mindbloom_desktop/services/session_storage_service.dart';

void main() {
  for (final reports in [false, true]) {
    group(
      reports ? 'report therapist options' : 'workshop therapist options',
      () {
        Future<List<dynamic>> load(_PagedApiClient client) => reports
            ? AdminReportApiService(apiClient: client).getTherapists()
            : WorkshopManagementApiService(apiClient: client).getTherapists();

        test('loads subsequent limited pages without losing options', () async {
          final client = _PagedApiClient([
            _page([
              _therapist(3, 'Charlie'),
              _therapist(1, 'Alpha'),
            ], hasNext: true),
            _page([_therapist(2, 'Bravo')]),
          ]);
          final result = await load(client);
          expect(result, hasLength(3));
          expect(result.map((item) => item.id).toSet(), {1, 2, 3});
          expect(client.requests.map((uri) => uri.queryParameters['Page']), [
            '1',
            '2',
          ]);
          expect(
            client.requests.every(
              (uri) => uri.queryParameters['PageSize'] == '50',
            ),
            isTrue,
          );
          expect(
            result.map((item) => item.fullName),
            reports
                ? ['Alpha', 'Bravo', 'Charlie']
                : ['Charlie', 'Alpha', 'Bravo'],
          );
        });

        test('empty first page stops immediately', () async {
          final client = _PagedApiClient([_page([])]);
          expect(await load(client), isEmpty);
          expect(client.requests, hasLength(1));
        });

        test(
          'a failed next page is reported instead of returning partial options',
          () async {
            final client = _PagedApiClient([
              _page([_therapist(1, 'Alpha')], hasNext: true),
            ], failPage: 2);
            await expectLater(load(client), throwsStateError);
            expect(client.requests, hasLength(2));
          },
        );

        test('rejects an unpaginated response', () async {
          await expectLater(
            load(_PagedApiClient([<dynamic>[]])),
            throwsFormatException,
          );
        });

        test(
          'rejects an empty intermediate page rather than looping forever',
          () async {
            final client = _PagedApiClient([_page([], hasNext: true)]);
            await expectLater(load(client), throwsFormatException);
            expect(client.requests, hasLength(1));
          },
        );
      },
    );
  }
}

Map<String, dynamic> _therapist(int id, String name) => {
  'id': id,
  'fullName': name,
  'specialization': 'Psychotherapy',
};

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  bool hasNext = false,
}) => {'items': items, 'hasNextPage': hasNext};

class _PagedApiClient extends ApiClient {
  final List<dynamic> pages;
  final int? failPage;
  final requests = <Uri>[];

  _PagedApiClient(this.pages, {this.failPage})
    : super(sessionStorage: SessionStorageService());

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    final uri = Uri.parse(endpoint);
    requests.add(uri);
    expect(uri.path, '/Therapists');
    final page = int.parse(uri.queryParameters['Page']!);
    if (page == failPage) throw StateError('API unavailable');
    return pages[page - 1];
  }
}
