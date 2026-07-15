import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_mobile/features/chat/data/models/chat_message_model.dart';
import '../../../../app/di/injection.dart';
import '../viewmodels/chat_details_viewmodel.dart';

class ChatDetailsPage extends StatefulWidget {
  final int appointmentId;

  const ChatDetailsPage({super.key, required this.appointmentId});

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  late final ChatDetailsViewModel _viewModel;

  final TextEditingController _messageController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createChatDetailsViewModel();

    _viewModel.addListener(_onChanged);

    _scrollController.addListener(_onScroll);

    _initialize();
  }

  Future<void> _initialize() async {
    await _viewModel.initializeFromAppointment(widget.appointmentId);

    if (!mounted) {
      return;
    }

    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);

    _viewModel.removeListener(_onChanged);

    _messageController.dispose();

    _scrollController.dispose();

    _viewModel.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final position = _scrollController.hasClients
          ? _scrollController.position
          : null;

      if (position != null &&
          position.maxScrollExtent - position.pixels < 180) {
        _scrollToBottom();
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.pixels <= 100) {
      _viewModel.loadOlderMessages();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();

    if (content.isEmpty) {
      return;
    }

    final success = await _viewModel.sendMessage(content);

    if (!mounted) {
      return;
    }

    if (success) {
      _messageController.clear();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _viewModel.conversation;

    return Scaffold(
      appBar: AppBar(
        title: Text(conversation?.otherParticipantName ?? 'Conversation'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    _viewModel.isConnected ? Icons.wifi : Icons.wifi_off,
                    size: 17,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _viewModel.connectionStatusText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.conversation == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && _viewModel.conversation == null) {
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
                onPressed: _initialize,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final conversation = _viewModel.conversation;

    if (conversation == null) {
      return const Center(child: Text('Conversation could not be loaded.'));
    }

    return Column(
      children: [
        if (_viewModel.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(10),
            child: CircularProgressIndicator(),
          ),

        if (_viewModel.hasMoreMessages && !_viewModel.isLoadingMore)
          TextButton.icon(
            onPressed: _viewModel.loadOlderMessages,
            icon: const Icon(Icons.history),
            label: const Text('Load older messages'),
          ),

        Expanded(
          child: _viewModel.messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet. '
                    'Start the conversation.',
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  itemCount: _viewModel.messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(message: _viewModel.messages[index]);
                  },
                ),
        ),

        if (_viewModel.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: Text(
              _viewModel.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),

        if (conversation.isClosed)
          const SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'This conversation is closed.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        hintText: 'Write a message...',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      onSubmitted: (_) {
                        _sendMessage();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _viewModel.isSending ? null : _sendMessage,
                    icon: _viewModel.isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isMine
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!message.isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(message.content),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatter.format(message.sentAtUtc.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (message.isEdited) ...[
                  const SizedBox(width: 4),
                  const Text('edited', style: TextStyle(fontSize: 10)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
