import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/widgets/app_error_message.dart';
import '../../data/models/therapist_client_model.dart';
import '../../data/repositories/therapist_repository.dart';

class TherapistClientsViewModel extends ChangeNotifier {
  final TherapistRepository repository;

  TherapistClientsViewModel({required this.repository});

  final List<TherapistClientModel> _clients = [];

  Timer? _searchDebounce;

  bool isLoading = false;
  String? errorMessage;
  String searchQuery = '';

  List<TherapistClientModel> get clients => List.unmodifiable(_clients);

  int get totalClients => _clients.length;

  bool get hasSearch => searchQuery.trim().isNotEmpty;

  Future<void> loadClients({String? search}) async {
    if (isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await repository.getTherapistClients(search: search);

      _clients
        ..clear()
        ..addAll(result);

      errorMessage = null;
    } catch (error) {
      errorMessage = AppErrorMessage.from(
        error,
        fallback: 'Klijente nije moguće učitati.',
      );
    } finally {
      isLoading = false;
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
