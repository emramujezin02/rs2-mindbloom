import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/chat_list_viewmodel.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final ChatListViewModel _viewModel = AppInjection.createChatListViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);
    _viewModel.loadConversations();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);
    _viewModel.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _refresh() {
    return _viewModel.loadConversations();
  }

  Future<void> _openConversation(int appointmentId) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouter.chatDetails, arguments: appointmentId);

    if (!mounted) {
      return;
    }

    await _viewModel.loadConversations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.conversations.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading conversations...',
        skeletonItemCount: 6,
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.conversations.isEmpty) {
      return AppErrorWidget(
        title: 'Conversations could not be loaded',
        error: _viewModel.errorMessage,
        onRetry: _refresh,
      );
    }

    if (_viewModel.conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: const AppEmptyStateWidget(
          title: 'No conversations',
          message: 'You do not have any conversations yet.',
          icon: Icons.chat_bubble_outline,
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount:
            _viewModel.conversations.length +
            (_viewModel.errorMessage != null ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (_viewModel.errorMessage != null && index == 0) {
            return AppInlineError(
              title: 'Conversations could not be refreshed',
              error: _viewModel.errorMessage,
              onRetry: _refresh,
            );
          }

          final conversationIndex =
              index - (_viewModel.errorMessage != null ? 1 : 0);

          final conversation = _viewModel.conversations[conversationIndex];

          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  conversation.otherParticipantName.isEmpty
                      ? '?'
                      : conversation.otherParticipantName[0].toUpperCase(),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      conversation.otherParticipantName,
                      style: TextStyle(
                        fontWeight: conversation.unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (conversation.unreadCount > 0)
                    Badge.count(count: conversation.unreadCount),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    conversation.lastMessage?.trim().isNotEmpty == true
                        ? conversation.lastMessage!
                        : 'No messages yet.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conversation.lastMessageAtUtc != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatter.format(
                        conversation.lastMessageAtUtc!.toLocal(),
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              trailing: conversation.isClosed
                  ? const Icon(Icons.lock_outline)
                  : const Icon(Icons.chevron_right),
              onTap: () {
                _openConversation(conversation.appointmentId);
              },
            ),
          );
        },
      ),
    );
  }
}
