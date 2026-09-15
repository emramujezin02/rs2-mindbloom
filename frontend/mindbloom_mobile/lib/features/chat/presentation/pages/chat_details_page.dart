import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_mobile/features/chat/data/models/chat_message_model.dart';
import '../../../../app/di/injection.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/chat_details_viewmodel.dart';

const _chatBackground = Color(0xFFFCFAFF);
const _chatSurface = Color(0xFFFFFFFF);
const _chatLavender = Color(0xFFF6F0FC);
const _chatBorder = Color(0xFFE7DDF1);
const _chatPrimary = Color(0xFF6D4F91);
const _chatText = Color(0xFF372D45);
const _chatMuted = Color(0xFF6C6278);
const _chatRadius = 20.0;

class ChatDetailsPage extends StatefulWidget {
  final int appointmentId;

  const ChatDetailsPage({super.key, required this.appointmentId});

  @override
  State<ChatDetailsPage> createState() => _ChatDetailsPageState();
}

class _ChatDetailsPageState extends State<ChatDetailsPage> {
  late final ChatDetailsViewModel _viewModel;
  bool _isLoadingOlderFromScroll = false;
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
    if (!_scrollController.hasClients || _isLoadingOlderFromScroll) {
      return;
    }

    if (_scrollController.position.pixels <= 100) {
      _loadOlderPreservingPosition();
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

      _viewModel.onComposerChanged('');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _loadOlderPreservingPosition() async {
    if (!_scrollController.hasClients || _isLoadingOlderFromScroll) {
      return;
    }

    _isLoadingOlderFromScroll = true;

    final previousMaxExtent = _scrollController.position.maxScrollExtent;

    await _viewModel.loadOlderMessages();

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        _isLoadingOlderFromScroll = false;

        return;
      }

      final newMaxExtent = _scrollController.position.maxScrollExtent;

      final addedExtent = newMaxExtent - previousMaxExtent;

      _scrollController.jumpTo(_scrollController.position.pixels + addedExtent);

      _isLoadingOlderFromScroll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _viewModel.conversation;

    return Scaffold(
      backgroundColor: _chatBackground,
      appBar: AppBar(
        backgroundColor: _chatBackground,
        surfaceTintColor: Colors.transparent,
        title: Text(
          conversation?.otherParticipantName ?? 'Conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _viewModel.isConnected ? _chatLavender : _chatSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _chatBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _viewModel.isConnected ? Icons.wifi : Icons.wifi_off,
                      size: 15,
                      color: _chatPrimary,
                    ),
                    const SizedBox(width: 5),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 104),
                      child: Text(
                        _viewModel.connectionStatusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _chatMuted,
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.conversation == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading conversation...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.conversation == null) {
      return AppErrorWidget(
        title: 'Conversation could not be loaded',
        error: _viewModel.errorMessage,
        onRetry: _initialize,
      );
    }

    final conversation = _viewModel.conversation;

    if (conversation == null) {
      return const AppEmptyStateWidget(
        title: 'Conversation unavailable',
        message: 'The requested conversation could not be loaded.',
        icon: Icons.chat_bubble_outline,
      );
    }

    final canSend =
        _messageController.text.trim().isNotEmpty && !_viewModel.isLoading;

    return Column(
      children: [
        if (_viewModel.isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(10),
            child: AppInlineLoadingIndicator(
              message: 'Loading older messages...',
            ),
          ),

        if (_viewModel.hasMoreMessages && !_viewModel.isLoadingMore)
          TextButton.icon(
            onPressed: _loadOlderPreservingPosition,
            icon: const Icon(Icons.history),
            label: const Text('Load older messages'),
          ),

        Expanded(
          child: _viewModel.messages.isEmpty
              ? const AppEmptyStateWidget(
                  title: 'No messages yet',
                  message: 'Start the conversation when you are ready.',
                  icon: Icons.chat_bubble_outline,
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  itemCount: _viewModel.messages.length,
                  itemBuilder: (context, index) {
                    final message = _viewModel.messages[index];

                    return _MessageBubble(
                      message: message,
                      onRetry: message.hasFailed
                          ? () {
                              _viewModel.retryMessage(message);
                            }
                          : null,
                    );
                  },
                ),
        ),

        if (_viewModel.isOtherParticipantTyping)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width - 64,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${conversation.otherParticipantName} is typing...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (_viewModel.errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
            child: AppInlineError(
              title: 'Message action could not be completed',
              error: _viewModel.errorMessage,
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _chatSurface,
                  borderRadius: BorderRadius.circular(_chatRadius),
                  border: Border.all(color: _chatBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: 2000,
                        onChanged: (value) {
                          _viewModel.onComposerChanged(value);
                          setState(() {});
                        },
                        decoration: const InputDecoration(
                          hintText: 'Write a message...',
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) {
                          _sendMessage();
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: canSend ? _sendMessage : null,
                      tooltip: 'Send message',
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback? onRetry;

  const _MessageBubble({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('HH:mm');

    return Align(
      alignment: message.isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: message.hasFailed
                ? Theme.of(context).colorScheme.errorContainer
                : message.isMine
                ? _chatPrimary
                : _chatSurface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(message.isMine ? 18 : 6),
              bottomRight: Radius.circular(message.isMine ? 6 : 18),
            ),
            border: Border.all(
              color: message.hasFailed
                  ? Theme.of(context).colorScheme.error
                  : message.isMine
                  ? _chatPrimary
                  : _chatBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.isMine)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.senderName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _chatMuted,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),

              Text(
                _withSoftBreaks(message.content),
                softWrap: true,
                style: TextStyle(
                  color: message.isMine ? Colors.white : _chatText,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 5),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatter.format(message.sentAtUtc.toLocal()),
                    style: TextStyle(
                      color: message.isMine
                          ? Colors.white.withValues(alpha: 0.78)
                          : _chatMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (message.isEdited) ...[
                    const SizedBox(width: 4),
                    Text(
                      'edited',
                      style: TextStyle(
                        color: message.isMine
                            ? Colors.white.withValues(alpha: 0.78)
                            : _chatMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],

                  if (message.isMine) ...[
                    const SizedBox(width: 6),

                    if (message.isSending)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else if (message.hasFailed)
                      const Tooltip(
                        message: 'Message could not be sent',
                        child: Icon(Icons.error_outline, size: 16),
                      )
                    else if (message.isRead)
                      const Tooltip(
                        message: 'Read',
                        child: Icon(
                          Icons.done_all,
                          size: 17,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Tooltip(
                        message: 'Sent',
                        child: Icon(Icons.done, size: 16, color: Colors.white),
                      ),
                  ],
                ],
              ),

              if (message.hasFailed) ...[
                const SizedBox(height: 6),

                Text(
                  _withSoftBreaks(
                    message.sendingError ?? 'Message could not be sent.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 11,
                  ),
                ),

                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _withSoftBreaks(String value) {
  const chunkLength = 32;

  return value.splitMapJoin(
    RegExp(r'(\s+)'),
    onMatch: (match) => match.group(0)!,
    onNonMatch: (segment) {
      if (segment.length <= chunkLength) {
        return segment;
      }

      final buffer = StringBuffer();

      for (var index = 0; index < segment.length; index += chunkLength) {
        final end = (index + chunkLength).clamp(0, segment.length);

        buffer.write(segment.substring(index, end));

        if (end < segment.length) {
          buffer.write('\u200B');
        }
      }

      return buffer.toString();
    },
  );
}
