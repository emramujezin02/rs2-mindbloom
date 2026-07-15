import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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

  Future<void> _refresh() async {
    await _viewModel.loadConversations();
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
      appBar: AppBar(title: const Text('Messages')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && _viewModel.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _viewModel.errorMessage!,
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

    if (_viewModel.conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.chat_bubble_outline, size: 64),
            SizedBox(height: 12),
            Center(child: Text('You do not have any conversations.')),
          ],
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _viewModel.conversations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final conversation = _viewModel.conversations[index];

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
