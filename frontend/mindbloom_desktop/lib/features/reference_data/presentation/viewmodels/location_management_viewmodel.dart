import 'package:flutter/foundation.dart';
import '../../../../core/error/app_error_helper.dart';
import '../../data/models/therapist_location_model.dart';
import '../../data/repositories/reference_data_repository.dart';

class LocationManagementViewModel extends ChangeNotifier {
  final ReferenceDataRepository repository;
  LocationManagementViewModel({required this.repository});
  List<TherapistLocationModel> items = [];
  int pageNumber = 1, pageSize = 10, totalCount = 0, totalPages = 0;
  String search = '';
  bool? activeFilter;
  bool isLoading = false, isSaving = false;
  String? error;
  bool _disposed = false;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load({int? page}) async {
    if (isLoading) return;
    isLoading = true;
    error = null;
    _notify();
    try {
      final response = await repository.getLocations(
        pageNumber: page ?? pageNumber,
        pageSize: pageSize,
        search: search,
        isActive: activeFilter,
      );
      items = response.items;
      pageNumber = response.pageNumber;
      pageSize = response.pageSize;
      totalCount = response.totalCount;
      totalPages = response.totalPages;
    } catch (exception) {
      error = AppErrorHelper.message(exception);
    } finally {
      isLoading = false;
      _notify();
    }
  }

  Future<bool> save({
    int? id,
    required String name,
    required String country,
    String region = '',
    required bool isActive,
  }) async {
    if (isSaving) return false;
    if (name.trim().isEmpty ||
        country.trim().isEmpty ||
        [name, country, region].any((x) => x.trim().length > 100)) {
      error =
          'Naziv i država su obavezni. Polja mogu imati najviše 100 znakova.';
      _notify();
      return false;
    }
    return _mutate(
      () => repository.saveLocation(
        id: id,
        name: name,
        country: country,
        region: region,
        isActive: isActive,
      ),
    );
  }

  Future<bool> delete(int id) => _mutate(() => repository.deleteLocation(id));
  Future<bool> _mutate(Future<void> Function() action) async {
    if (isSaving || isLoading) return false;
    isSaving = true;
    error = null;
    _notify();
    try {
      await action();
      await load(page: 1);
      return true;
    } catch (exception) {
      error = AppErrorHelper.message(exception);
      return false;
    } finally {
      isSaving = false;
      _notify();
    }
  }
}
