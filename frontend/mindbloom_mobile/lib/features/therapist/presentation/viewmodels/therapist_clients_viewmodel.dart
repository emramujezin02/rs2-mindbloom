import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/therapist_client_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistClientsViewModel extends ChangeNotifier {
  static const int pageSize = 10;

  final TherapistRepository repository;

  TherapistClientsViewModel({required this.repository});

  final List<TherapistClientModel> _clients = [];

  Timer? _searchDebounce;

  bool isLoading = false;
  bool isLoadingMore = false;
  String? errorMessage;
  String? loadMoreErrorMessage;
  String searchQuery = '';

  int pageNumber = 1;
  int totalPages = 0;
  int totalCount = 0;

  List<TherapistClientModel> get clients => List.unmodifiable(_clients);

  int get totalClients => totalCount;

  bool get hasSearch => searchQuery.trim().isNotEmpty;

  bool get hasMorePages => pageNumber < totalPages;

  Future<void> loadClients({String? search}) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    loadMoreErrorMessage = null;
    pageNumber = 1;
    notifyListeners();

    try {
      final result = await repository.getTherapistClients(
        search: search,
        pageNumber: 1,
        pageSize: pageSize,
      );

      _clients
        ..clear()
        ..addAll(result.items);

      pageNumber = result.pageNumber;
      totalPages = result.totalPages;
      totalCount = result.totalCount;
      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Clients could not be loaded.',
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreClients() async {
    if (isLoading || isLoadingMore || !hasMorePages) {
      return;
    }

    isLoadingMore = true;
    loadMoreErrorMessage = null;
    notifyListeners();

    try {
      final result = await repository.getTherapistClients(
        search: searchQuery,
        pageNumber: pageNumber + 1,
        pageSize: pageSize,
      );

      final existingIds = _clients.map((client) => client.clientId).toSet();

      _clients.addAll(
        result.items.where((client) => !existingIds.contains(client.clientId)),
      );

      pageNumber = result.pageNumber;
      totalPages = result.totalPages;
      totalCount = result.totalCount;
    } catch (error) {
      loadMoreErrorMessage = AppErrorMessage.from(
        error,
        fallback: 'More clients could not be loaded.',
      );
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  void onSearchChanged(String value) {
    searchQuery = value;
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      loadClients(search: searchQuery);
    });

    notifyListeners();
  }

  Future<void> submitSearch() async {
    _searchDebounce?.cancel();
    await loadClients(search: searchQuery);
  }

  Future<void> clearSearch() async {
    _searchDebounce?.cancel();

    if (searchQuery.isEmpty) {
      return;
    }

    searchQuery = '';
    notifyListeners();

    await loadClients();
  }

  Future<void> refresh() {
    return loadClients(search: searchQuery);
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}
