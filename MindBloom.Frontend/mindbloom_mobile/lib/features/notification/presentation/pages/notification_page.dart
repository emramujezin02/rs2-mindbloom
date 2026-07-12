import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/notification_viewmodel.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationViewModel _viewModel =
      AppInjection.createNotificationViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _viewModel.loadNotifications();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _viewModel.notifications.length,
              itemBuilder: (context, index) {
                final item = _viewModel.notifications[index];

                return Card(
                  color: item.isRead ? null : Colors.blue.shade50,
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.message),
                        const SizedBox(height: 6),
                        Text(
                          formatter.format(item.createdAtUtc.toLocal()),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: item.isRead
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.done),
                            onPressed: () {
                              _viewModel.markAsRead(item.id);
                            },
                          ),
                  ),
                );
              },
            ),
    );
  }
}
