import 'package:flutter_test/flutter_test.dart';
import 'package:mindbloom_desktop/features/workshop_management/data/models/workshop_model.dart';
import 'package:mindbloom_desktop/features/workshop_management/data/repositories/workshop_management_repository.dart';
import 'package:mindbloom_desktop/features/workshop_management/presentation/viewmodels/workshop_form_viewmodel.dart';

class FakeWorkshopFormRepository implements WorkshopManagementRepository {
  int createCallCount = 0;
  int updateCallCount = 0;

  int? updatedWorkshopId;

  String? receivedTitle;
  String? receivedDescription;

  Object? createError;
  Object? updateError;

  WorkshopModel _result() {
    final start = DateTime.utc(2026, 10, 10, 10);

    return WorkshopModel(
      id: 1,
      title: receivedTitle ?? 'Workshop',
      description: receivedDescription ?? 'Workshop description',
      startUtc: start,
      endUtc: start.add(const Duration(hours: 2)),
      therapistName: 'Therapist',
      type: 'Online',
      onlineLink: 'https://example.com',
      location: null,
      capacity: 20,
      registeredCount: 0,
      availableSeats: 20,
      price: 30,
      status: 'Scheduled',
      organizerUserId: 1,
      organizerName: 'Administrator',
      therapistId: 5,
      createdAtUtc: DateTime.utc(2026, 8, 1),
      updatedAtUtc: null,
      statusChangeReason: null,
      imageUrl: null,
      registrationDeadlineUtc: start.subtract(const Duration(days: 1)),
    );
  }

  @override
  Future<WorkshopModel> createWorkshop({
    required String title,
    required String description,
    required DateTime startUtc,
    required DateTime endUtc,
    required int type,
    required String? onlineLink,
    required String? location,
    required int capacity,
    required double price,
    required int? therapistId,
    required String? imageUrl,
    required DateTime registrationDeadlineUtc,
  }) async {
    createCallCount++;

    receivedTitle = title;
    receivedDescription = description;

    if (createError != null) {
      throw createError!;
    }

    return _result();
  }

  @override
  Future<WorkshopModel> updateWorkshop({
    required int workshopId,
    required String title,
    required String description,
    required DateTime startUtc,
    required DateTime endUtc,
    required int type,
    required String? onlineLink,
    required String? location,
    required int capacity,
    required double price,
    required int? therapistId,
    required String? imageUrl,
    required DateTime registrationDeadlineUtc,
  }) async {
    updateCallCount++;

    updatedWorkshopId = workshopId;

    receivedTitle = title;

    receivedDescription = description;

    if (updateError != null) {
      throw updateError!;
    }

    return _result();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

void main() {
  group('WorkshopFormViewModel', () {
    final start = DateTime.utc(2026, 10, 10, 10);

    final end = start.add(const Duration(hours: 2));

    final deadline = start.subtract(const Duration(days: 1));

    test('save creates workshop when workshopId is null', () async {
      final repository = FakeWorkshopFormRepository();

      final viewModel = WorkshopFormViewModel(repository: repository);

      final success = await viewModel.save(
        workshopId: null,
        title: 'New workshop',
        description: 'A complete description for the new workshop.',
        startUtc: start,
        endUtc: end,
        type: 1,
        onlineLink: 'https://example.com',
        location: null,
        capacity: 20,
        price: 30,
        therapistId: 5,
        imageUrl: null,
        registrationDeadlineUtc: deadline,
      );

      expect(success, isTrue);

      expect(repository.createCallCount, 1);

      expect(repository.updateCallCount, 0);

      expect(repository.receivedTitle, 'New workshop');

      expect(viewModel.isSaving, isFalse);

      expect(viewModel.error, isNull);
    });

    test('save updates workshop when workshopId exists', () async {
      final repository = FakeWorkshopFormRepository();

      final viewModel = WorkshopFormViewModel(repository: repository);

      final success = await viewModel.save(
        workshopId: 77,
        title: 'Updated workshop',
        description: 'Updated description for workshop.',
        startUtc: start,
        endUtc: end,
        type: 1,
        onlineLink: 'https://example.com/updated',
        location: null,
        capacity: 30,
        price: 45,
        therapistId: 8,
        imageUrl: '/images/workshop.jpg',
        registrationDeadlineUtc: deadline,
      );

      expect(success, isTrue);

      expect(repository.createCallCount, 0);

      expect(repository.updateCallCount, 1);

      expect(repository.updatedWorkshopId, 77);

      expect(repository.receivedTitle, 'Updated workshop');
    });

    test('create failure returns false and exposes error', () async {
      final repository = FakeWorkshopFormRepository();

      repository.createError = Exception('Create failed.');

      final viewModel = WorkshopFormViewModel(repository: repository);

      final success = await viewModel.save(
        workshopId: null,
        title: 'Workshop',
        description: 'Valid workshop description.',
        startUtc: start,
        endUtc: end,
        type: 1,
        onlineLink: 'https://example.com',
        location: null,
        capacity: 20,
        price: 20,
        therapistId: null,
        imageUrl: null,
        registrationDeadlineUtc: deadline,
      );

      expect(success, isFalse);

      expect(viewModel.error, contains('Create failed'));

      expect(viewModel.isSaving, isFalse);
    });

    test('update failure returns false and exposes error', () async {
      final repository = FakeWorkshopFormRepository();

      repository.updateError = Exception('Update failed.');

      final viewModel = WorkshopFormViewModel(repository: repository);

      final success = await viewModel.save(
        workshopId: 12,
        title: 'Workshop',
        description: 'Valid workshop description.',
        startUtc: start,
        endUtc: end,
        type: 1,
        onlineLink: 'https://example.com',
        location: null,
        capacity: 20,
        price: 20,
        therapistId: null,
        imageUrl: null,
        registrationDeadlineUtc: deadline,
      );

      expect(success, isFalse);

      expect(viewModel.error, contains('Update failed'));

      expect(viewModel.isSaving, isFalse);
    });
  });
}
