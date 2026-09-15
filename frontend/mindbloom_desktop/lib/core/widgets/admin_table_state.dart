import 'package:flutter/material.dart';

import 'app_empty_state.dart';
import 'app_error_panel.dart';
import 'app_loading_state.dart';

class AdminTableLoadingState extends StatelessWidget {
  final String message;

  const AdminTableLoadingState({
    super.key,
    this.message = 'Učitavanje podataka...',
  });

  @override
  Widget build(BuildContext context) {
    return AppLoadingState(message: message);
  }
}

class AdminTableEmptyState extends StatelessWidget {
  final String title;

  final String? message;

  final IconData icon;

  final VoidCallback? onResetFilters;

  const AdminTableEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      message: message ?? 'Nema podataka za prikaz.',
      icon: icon,
      onResetFilters: onResetFilters,
    );
  }
}

class AdminTableErrorState extends StatelessWidget {
  final String message;

  final VoidCallback? onRetry;

  const AdminTableErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AppErrorPanel(message: message, onRetry: onRetry);
  }
}
