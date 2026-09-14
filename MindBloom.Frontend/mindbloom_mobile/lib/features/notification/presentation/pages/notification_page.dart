import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../appointment/data/models/appointment_model.dart';
import '../../data/models/notification_model.dart';
import '../viewmodels/notification_scope.dart';
import '../viewmodels/notification_viewmodel.dart';

const _notificationBackground = Color(0xFFFCFAFF);
const _notificationSurface = Color(0xFFFFFFFF);
const _notificationLavender = Color(0xFFF6F0FC);
const _notificationBorder = Color(0xFFE7DDF1);
const _notificationPrimary = Color(0xFF6D4F91);
const _notificationText = Color(0xFF372D45);
const _notificationMuted = Color(0xFF6C6278);
const _notificationRadius = 18.0;

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
          title: Text(
            notification.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          content: SingleChildScrollView(
            child: Column(
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
      backgroundColor: _notificationBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _notificationBackground,
        surfaceTintColor: Colors.transparent,
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
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: viewModel.isRealtimeConnected
                      ? _notificationLavender
                      : _notificationSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _notificationBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      viewModel.isRealtimeConnected ? Icons.wifi : Icons.sync,
                      size: 15,
                      color: _notificationPrimary,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        viewModel.connectionStatusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _notificationMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
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
      return const AppLoadingWidget.skeleton(
        message: 'Loading notifications...',
        skeletonItemCount: 6,
      );
    }

    if (viewModel.error != null && viewModel.notifications.isEmpty) {
      return AppErrorWidget(
        title: 'Notifications could not be loaded',
        error: viewModel.error,
        onRetry: _refresh,
      );
    }

    if (viewModel.notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppEmptyStateWidget(
          title: 'No notifications',
          message: 'You do not have any notifications yet.',
          icon: Icons.notifications_none,
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final footerItemCount =
        viewModel.isLoadingMore || viewModel.loadMoreError != null ? 1 : 0;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        itemCount:
            viewModel.notifications.length +
            footerItemCount +
            (viewModel.error != null ? 1 : 0),
        separatorBuilder: (context, index) {
          return const SizedBox(height: 8);
        },
        itemBuilder: (context, index) {
          if (viewModel.error != null && index == 0) {
            return AppInlineError(
              title: 'Notifications could not be refreshed',
              error: viewModel.error,
              onRetry: _refresh,
            );
          }

          final adjustedIndex = index - (viewModel.error != null ? 1 : 0);

          if (adjustedIndex >= viewModel.notifications.length) {
            if (viewModel.loadMoreError != null) {
              return AppLoadMoreError(
                error: viewModel.loadMoreError,
                fallbackMessage: 'More notifications could not be loaded.',
                onRetry: viewModel.retryLoadMore,
              );
            }

            return const AppLoadMoreIndicator(
              loadingMessage: 'Loading more notifications...',
            );
          }

          final item = viewModel.notifications[adjustedIndex];

          return _NotificationTile(
            notification: item,
            formatter: formatter,
            icon: _iconForAction(item.actionType, item.isRead),
            onTap: () {
              _openNotification(item);
            },
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

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final DateFormat formatter;
  final IconData icon;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.formatter,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final errorColor = Theme.of(context).colorScheme.error;

    return Material(
      color: isUnread ? _notificationLavender : _notificationSurface,
      borderRadius: BorderRadius.circular(_notificationRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_notificationRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_notificationRadius),
            border: Border.all(
              color: isUnread ? _notificationPrimary : _notificationBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: isUnread
                        ? _notificationPrimary
                        : _notificationLavender,
                    child: Icon(
                      icon,
                      color: isUnread ? Colors.white : _notificationPrimary,
                    ),
                  ),
                  if (isUnread)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _notificationPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(color: _notificationSurface),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _notificationText,
                        fontSize: 16,
                        fontWeight: isUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isUnread
                            ? _notificationText
                            : _notificationMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          formatter.format(notification.createdAtUtc.toLocal()),
                          style: const TextStyle(
                            color: _notificationMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isUnread)
                          const Text(
                            'Unread',
                            style: TextStyle(
                              color: _notificationPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    if (!notification.isActionAvailable) ...[
                      const SizedBox(height: 8),
                      Text(
                        notification.unavailableReason ??
                            'Linked resource unavailable.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: errorColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 22,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Icon(
                    notification.isRead ? Icons.done_all : Icons.circle,
                    size: notification.isRead ? 20 : 12,
                    color: notification.isRead
                        ? _notificationMuted
                        : _notificationPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
