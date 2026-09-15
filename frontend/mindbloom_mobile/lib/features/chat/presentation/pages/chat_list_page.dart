import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/conversation_model.dart';
import '../viewmodels/chat_list_viewmodel.dart';

const _chatListBackground = Color(0xFFFCFAFF);
const _chatListSurface = Color(0xFFFFFFFF);
const _chatListLavender = Color(0xFFF6F0FC);
const _chatListBorder = Color(0xFFE7DDF1);
const _chatListPrimary = Color(0xFF6D4F91);
const _chatListText = Color(0xFF372D45);
const _chatListMuted = Color(0xFF6C6278);
const _chatListRadius = 20.0;

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
      backgroundColor: _chatListBackground,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: _chatListBackground,
        surfaceTintColor: Colors.transparent,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
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

          return _ConversationCard(
            conversation: conversation,
            formatter: formatter,
            onTap: () {
              _openConversation(conversation.appointmentId);
            },
          );
        },
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ConversationModel conversation;
  final DateFormat formatter;
  final VoidCallback onTap;

  const _ConversationCard({
    required this.conversation,
    required this.formatter,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;
    final name = conversation.otherParticipantName.trim();
    final lastMessage = conversation.lastMessage?.trim();

    return Material(
      color: hasUnread ? _chatListLavender : _chatListSurface,
      borderRadius: BorderRadius.circular(_chatListRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_chatListRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_chatListRadius),
            border: Border.all(
              color: hasUnread ? _chatListPrimary : _chatListBorder,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: hasUnread
                    ? _chatListPrimary
                    : _chatListLavender,
                foregroundColor: hasUnread ? Colors.white : _chatListPrimary,
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Conversation' : name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _chatListText,
                              fontSize: 16,
                              fontWeight: hasUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (hasUnread) ...[
                          const SizedBox(width: 8),
                          Badge.count(count: conversation.unreadCount),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lastMessage?.isNotEmpty == true
                          ? lastMessage!
                          : 'No messages yet.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hasUnread ? _chatListText : _chatListMuted,
                        height: 1.35,
                        fontWeight: hasUnread
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    if (conversation.lastMessageAtUtc != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        formatter.format(
                          conversation.lastMessageAtUtc!.toLocal(),
                        ),
                        style: const TextStyle(
                          color: _chatListMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                conversation.isClosed
                    ? Icons.lock_outline
                    : Icons.chevron_right,
                color: _chatListMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
