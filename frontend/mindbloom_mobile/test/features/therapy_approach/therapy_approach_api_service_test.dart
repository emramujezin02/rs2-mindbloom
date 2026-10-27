import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_mobile/core/network/api_client.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/models/therapy_approach_model.dart';
import 'package:mindbloom_mobile/features/therapy_approach/data/services/therapy_approach_api_service.dart';
import 'package:mindbloom_mobile/services/session_storage_service.dart';

void main() {
  test('parses reference data DTO without iconUrl', () {
    final approach = TherapyApproachModel.fromJson({
      'id': 7,
      'name': 'Cognitive therapy',
      'description': 'Therapy description',
      'isActive': true,
      'therapistCount': 2,
      'clientCount': 3,
      'createdAtUtc': '2026-01-01T00:00:00Z',
      'updatedAtUtc': null,
    });

    expect(approach.id, 7);
    expect(approach.name, 'Cognitive therapy');
    expect(approach.description, 'Therapy description');
    expect(approach.isActive, isTrue);
    expect(approach.iconUrl, isNull);
  });

  test(
    'missing description retains the existing empty description fallback',
    () {
      final approach = TherapyApproachModel.fromJson({
        'id': 7,
        'name': 'Cognitive therapy',
        'description': null,
        'isActive': true,
      });

      expect(approach.description, isEmpty);
      expect(approach.iconUrl, isNull);
    },
  );

  test(
    'public call keeps its route and parses active approaches without icons',
    () async {
      final client = _TherapyApproachApiClient([
        {
          'id': 7,
          'name': 'Cognitive therapy',
          'description': 'Description',
          'isActive': true,
        },
        {'id': 8, 'name': 'Inactive', 'isActive': false},
        {
          'id': 9,
          'name': 'No description',
          'description': null,
          'isActive': true,
        },
      ]);

      final result = await TherapyApproachApiService(
        apiClient: client,
      ).getPublicTherapyApproaches();

      expect(client.lastEndpoint, '/TherapyApproaches/public');
      expect(result.map((approach) => approach.id), [7, 9]);
      expect(result.first.description, 'Description');
      expect(result.last.description, isEmpty);
      expect(result.every((approach) => approach.iconUrl == null), isTrue);
    },
  );
}

class _TherapyApproachApiClient extends ApiClient {
  final List<Map<String, dynamic>> response;
  String? lastEndpoint;

  _TherapyApproachApiClient(this.response)
    : super(sessionStorage: SessionStorageService());

  @override
  Future<dynamic> get(String endpoint, {bool requiresAuth = true}) async {
    lastEndpoint = endpoint;
    return response;
  }
}
