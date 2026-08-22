import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/features/workshop_management/data/models/workshop_model.dart';
import 'package:mindbloom_desktop/features/workshop_management/data/models/workshop_paged_response.dart';
import 'package:mindbloom_desktop/features/workshop_management/data/repositories/workshop_management_repository.dart';
import 'package:mindbloom_desktop/features/workshop_management/presentation/viewmodels/workshop_management_viewmodel.dart';

class FakeWorkshopManagementRepository implements WorkshopManagementRepository {
  WorkshopPagedResponse response = const WorkshopPagedResponse(
    items: [],
    pageNumber: 1,
    pageSize: 10,
    totalCount: 0,
    totalPages: 0,
  );

  Object? loadError;
  Object? deleteError;

  int loadCallCount = 0;
  int deleteCallCount = 0;

  int? deletedWorkshopId;

  String? receivedSearch;
  int? receivedType;
  int? receivedStatus;
  DateTime? receivedFromUtc;
  DateTime? receivedToUtc;
  int? receivedPageNumber;
  int? receivedPageSize;

  @override
  Future<WorkshopPagedResponse> getWorkshops({
    String? search,
    int? type,
    int? status,
    DateTime? fromUtc,
    DateTime? toUtc,
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    loadCallCount++;

    receivedSearch = search;
    receivedType = type;
    receivedStatus = status;
    receivedFromUtc = fromUtc;
    receivedToUtc = toUtc;
    receivedPageNumber = pageNumber;
    receivedPageSize = pageSize;

    if (loadError != null) {
      throw loadError!;
    }

    return response;
  }

  @override
  Future<void> deleteWorkshop(int workshopId) async {
    deleteCallCount++;
    deletedWorkshopId = workshopId;

    if (deleteError != null) {
      throw deleteError!;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

WorkshopModel createWorkshop({
  int id = 1,
  String title = 'Mindfulness Workshop',
}) {
  final start = DateTime.utc(2026, 9, 10, 10);

  return WorkshopModel(
    id: id,
    title: title,
    description: 'A workshop for learning mindfulness techniques.',
    startUtc: start,
    endUtc: start.add(const Duration(hours: 2)),
    therapistName: 'Test Therapist',
    type: 'Online',
    onlineLink: 'https://example.com/workshop',
    location: null,
    capacity: 20,
    registeredCount: 5,
    availableSeats: 15,
    price: 25,
    status: 'Scheduled',
    organizerUserId: 100,
    organizerName: 'Administrator',
    therapistId: 10,
    createdAtUtc: DateTime.utc(2026, 8, 1),
    updatedAtUtc: null,
    statusChangeReason: null,
    imageUrl: null,
    registrationDeadlineUtc: start.subtract(const Duration(days: 1)),
  );
}

void main() {
  group('WorkshopManagementViewModel', () {
    test('loadWorkshops loads workshops and pagination data', () async {
      final repository = FakeWorkshopManagementRepository();

      repository.response = WorkshopPagedResponse(
        items: [createWorkshop()],
        pageNumber: 2,
        pageSize: 10,
        totalCount: 25,
        totalPages: 3,
      );

      final viewModel = WorkshopManagementViewModel(repository: repository);

      viewModel.pageNumber = 2;

      await viewModel.loadWorkshops();

      expect(viewModel.workshops.length, 1);

      expect(viewModel.workshops.first.title, 'Mindfulness Workshop');

      expect(viewModel.pageNumber, 2);

      expect(viewModel.totalCount, 25);

      expect(viewModel.totalPages, 3);

      expect(viewModel.isLoading, isFalse);
    });

    test('applyFilters sends all selected filters to repository', () async {
      final repository = FakeWorkshopManagementRepository();

      final viewModel = WorkshopManagementViewModel(repository: repository);

      final from = DateTime(2026, 9, 1);

      final to = DateTime(2026, 9, 30, 23, 59, 59);

      viewModel.search = 'mindfulness';

      viewModel.selectedType = 1;

      viewModel.selectedStatus = 1;

      viewModel.fromUtc = from;

      viewModel.toUtc = to;

      await viewModel.applyFilters();

      expect(repository.receivedSearch, 'mindfulness');

      expect(repository.receivedType, 1);

      expect(repository.receivedStatus, 1);

      expect(repository.receivedFromUtc, from);

      expect(repository.receivedToUtc, to);

      expect(repository.receivedPageNumber, 1);
    });

    test('clearFilters resets all filters', () async {
      final repository = FakeWorkshopManagementRepository();

      final viewModel = WorkshopManagementViewModel(repository: repository);

      viewModel.search = 'test';

      viewModel.selectedType = 2;

      viewModel.selectedStatus = 4;

      viewModel.fromUtc = DateTime(2026, 1, 1);

      viewModel.toUtc = DateTime(2026, 12, 31);

      await viewModel.clearFilters();

      expect(viewModel.search, '');

      expect(viewModel.selectedType, isNull);

      expect(viewModel.selectedStatus, isNull);

      expect(viewModel.fromUtc, isNull);

      expect(viewModel.toUtc, isNull);

      expect(viewModel.pageNumber, 1);
    });

    test('nextPage loads following page', () async {
      final repository = FakeWorkshopManagementRepository();

      repository.response = const WorkshopPagedResponse(
        items: [],
        pageNumber: 2,
        pageSize: 10,
        totalCount: 25,
        totalPages: 3,
      );

      final viewModel = WorkshopManagementViewModel(repository: repository);

      viewModel.pageNumber = 1;
      viewModel.totalPages = 3;

      await viewModel.nextPage();

      expect(repository.receivedPageNumber, 2);

      expect(viewModel.pageNumber, 2);
    });

    test('previousPage loads previous page', () async {
      final repository = FakeWorkshopManagementRepository();

      repository.response = const WorkshopPagedResponse(
        items: [],
        pageNumber: 1,
        pageSize: 10,
        totalCount: 25,
        totalPages: 3,
      );

      final viewModel = WorkshopManagementViewModel(repository: repository);

      viewModel.pageNumber = 2;
      viewModel.totalPages = 3;

      await viewModel.previousPage();

      expect(repository.receivedPageNumber, 1);

      expect(viewModel.pageNumber, 1);
    });

    test('changePageSize resets page and requests new page size', () async {
      final repository = FakeWorkshopManagementRepository();

      repository.response = const WorkshopPagedResponse(
        items: [],
        pageNumber: 1,
        pageSize: 20,
        totalCount: 40,
        totalPages: 2,
      );

      final viewModel = WorkshopManagementViewModel(repository: repository);

      viewModel.pageNumber = 3;

      await viewModel.changePageSize(20);

      expect(repository.receivedPageNumber, 1);

      expect(repository.receivedPageSize, 20);

      expect(viewModel.pageSize, 20);
    });

    test('deleteWorkshop deletes workshop and reloads list', () async {
      final repository = FakeWorkshopManagementRepository();

      repository.response = const WorkshopPagedResponse(
        items: [],
        pageNumber: 1,
        pageSize: 10,
        totalCount: 0,
        totalPages: 0,
      );

      final viewModel = WorkshopManagementViewModel(repository: repository);

      viewModel.workshops = [createWorkshop(id: 42)];

      final success = await viewModel.deleteWorkshop(42);

      expect(success, isTrue);

      expect(repository.deleteCallCount, 1);

      expect(repository.deletedWorkshopId, 42);

      expect(repository.loadCallCount, 1);

      expect(viewModel.isActionLoading, isFalse);
    });

    test(
      'deleteWorkshop returns false and exposes error when repository fails',
      () async {
        final repository = FakeWorkshopManagementRepository();

        repository.deleteError = Exception('Workshop cannot be deleted.');

        final viewModel = WorkshopManagementViewModel(repository: repository);

        final success = await viewModel.deleteWorkshop(10);

        expect(success, isFalse);

        expect(viewModel.error, contains('Workshop cannot be deleted'));

        expect(viewModel.isActionLoading, isFalse);
      },
    );

    test('loadWorkshops sets error state when loading fails', () async {
      final repository = FakeWorkshopManagementRepository();

      repository.loadError = Exception('Server unavailable.');

      final viewModel = WorkshopManagementViewModel(repository: repository);

      await viewModel.loadWorkshops();

      expect(viewModel.workshops, isEmpty);

      expect(viewModel.error, isNotNull);

      expect(viewModel.isLoading, isFalse);
    });
  });
}
