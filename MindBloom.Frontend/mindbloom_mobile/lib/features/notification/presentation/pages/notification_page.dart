import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../appointment/data/models/appointment_model.dart';
import '../../data/models/notification_model.dart';
import '../viewmodels/notification_scope.dart';
import '../viewmodels/notification_viewmodel.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  NotificationViewModel? _viewModel;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);
  }

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

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);

    _scrollController.dispose();

    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 250) {
      _viewModel?.loadMore();
    }
  }

  Future<void> _refresh() async {
    await _viewModel?.refresh();
  }

  Future<void> _markAllRead() async {
    final success = await _viewModel?.markAllAsRead() ?? false;

    if (!mounted || success) {
      return;
    }

    _showMessage(
      _viewModel?.error ?? 'Notifications could not be marked as read.',
    );
  }

  Future<void> _openNotification(NotificationModel notification) async {
    final viewModel = _viewModel;

    if (viewModel == null) {
      return;
    }

    final marked = await viewModel.markAsRead(notification.id);

    if (!mounted) {
      return;
    }

    if (!marked) {
      _showMessage(
        viewModel.error ?? 'Notification could not be marked as read.',
      );

      return;
    }

    if (!notification.isActionAvailable) {
      _showMessage(
        notification.unavailableReason ??
            'The linked resource is no longer available.',
      );

      return;
    }

    try {
      await _navigateForNotification(notification);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage(
        'The linked resource no longer exists or could not be opened.',
      );

      await viewModel.refresh();
    }
  }

  Future<void> _navigateForNotification(NotificationModel notification) async {
    switch (notification.actionType) {
      case NotificationActionType.appointment:
        await _openAppointment(
          notification.appointmentId ?? notification.resourceId,
        );

        break;

      case NotificationActionType.chat:
        final appointmentId =
            notification.appointmentId ?? notification.resourceId;

        if (appointmentId == null) {
          throw StateError('Appointment identifier is missing.');
        }

        await Navigator.of(
          context,
        ).pushNamed(AppRouter.chatDetails, arguments: appointmentId);

        break;

      case NotificationActionType.payment:
        await Navigator.of(context).pushNamed(AppRouter.myPayments);

        break;

      case NotificationActionType.membership:
        await Navigator.of(context).pushNamed(AppRouter.myMemberships);

        break;

      case NotificationActionType.workshop:
        final workshopId = notification.resourceId;

        if (workshopId == null) {
          throw StateError('Workshop identifier is missing.');
        }

        await Navigator.of(
          context,
        ).pushNamed(AppRouter.workshopDetails, arguments: workshopId);

        break;

      case NotificationActionType.review:
        await Navigator.of(context).pushNamed(AppRouter.myReviews);

        break;

      case NotificationActionType.therapistProfile:
        await Navigator.of(context).pushNamed(AppRouter.profile);

        break;

      case NotificationActionType.none:
        await _showNotificationDetails(notification);

        break;
    }
  }

  Future<void> _openAppointment(int? appointmentId) async {
    if (appointmentId == null) {
      throw StateError('Appointment identifier is missing.');
    }

    final repository = AppInjection.createAppointmentRepository();

    final AppointmentModel appointment = await repository.getAppointmentDetails(
      appointmentId,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).pushNamed(AppRouter.appointmentDetails, arguments: appointment);
  }

  Future<void> _showNotificationDetails(NotificationModel notification) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(notification.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.message),
              const SizedBox(height: 16),
              Text(
                formatter.format(notification.createdAtUtc.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = NotificationScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (viewModel.unreadCount > 0)
            TextButton(
              onPressed: viewModel.isMarkingAllRead ? null : _markAllRead,
              child: viewModel.isMarkingAllRead
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Read all'),
            ),

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
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount:
            viewModel.notifications.length + (viewModel.isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= viewModel.notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final item = viewModel.notifications[index];

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(_iconForAction(item.actionType, item.isRead)),
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
                  Text(
                    item.message,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    formatter.format(item.createdAtUtc.toLocal()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!item.isActionAvailable) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.unavailableReason ?? 'Linked resource unavailable.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: item.isRead
                  ? const Icon(Icons.done_all)
                  : const Icon(Icons.circle, size: 12),
              onTap: () {
                _openNotification(item);
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconForAction(NotificationActionType actionType, bool isRead) {
    switch (actionType) {
      case NotificationActionType.appointment:
        return Icons.calendar_month;

      case NotificationActionType.payment:
        return Icons.payments_outlined;

      case NotificationActionType.chat:
        return Icons.chat_outlined;

      case NotificationActionType.membership:
        return Icons.card_membership_outlined;

      case NotificationActionType.workshop:
        return Icons.groups_outlined;

      case NotificationActionType.review:
        return Icons.reviews_outlined;

      case NotificationActionType.therapistProfile:
        return Icons.person_outline;

      case NotificationActionType.none:
        return isRead ? Icons.notifications_none : Icons.notifications_active;
    }
  }
}
