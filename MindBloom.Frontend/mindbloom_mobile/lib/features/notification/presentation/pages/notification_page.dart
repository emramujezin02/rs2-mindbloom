import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../viewmodels/notification_scope.dart';
import '../viewmodels/notification_viewmodel.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  NotificationViewModel? _viewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final viewModel = NotificationScope.of(context);

    if (!identical(_viewModel, viewModel)) {
      _viewModel = viewModel;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _viewModel?.initialize();
      });
    }
  }

  Future<void> _refresh() async {
    await _viewModel?.loadNotifications(showLoading: false);
  }

  Future<void> _markAsRead(int notificationId) async {
    final success = await _viewModel?.markAsRead(notificationId) ?? false;

    if (!mounted || success) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _viewModel?.error ?? 'Notification could not be marked as read.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = NotificationScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    viewModel.isRealtimeConnected ? Icons.wifi : Icons.sync,
                    size: 18,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    viewModel.connectionStatusText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(viewModel),
    );
  }

  Widget _buildBody(NotificationViewModel viewModel) {
    if (viewModel.isLoading && viewModel.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null && viewModel.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                viewModel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.notifications_none, size: 64),
            SizedBox(height: 12),
            Center(child: Text('You do not have any notifications.')),
          ],
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: viewModel.notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = viewModel.notifications[index];

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  item.isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                ),
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 5),
                  Text(item.message),
                  const SizedBox(height: 7),
                  Text(
                    formatter.format(item.createdAtUtc.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              trailing: item.isRead
                  ? const Icon(Icons.done_all)
                  : IconButton(
                      tooltip: 'Mark as read',
                      icon: const Icon(Icons.done),
                      onPressed: () {
                        _markAsRead(item.id);
                      },
                    ),
              onTap: item.isRead
                  ? null
                  : () {
                      _markAsRead(item.id);
                    },
            ),
          );
        },
      ),
    );
  }
}
