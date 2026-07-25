enum ChatMessageDeliveryStatus { sending, sent, failed }

class ChatMessageModel {
  final int id;
  final int conversationId;
  final int senderUserId;
  final String senderName;
  final String content;
  final DateTime sentAtUtc;
  final bool isMine;
  final bool isEdited;
  final String? clientMessageId;
  final ChatMessageDeliveryStatus deliveryStatus;
  final String? sendingError;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderName,
    required this.content,
    required this.sentAtUtc,
    required this.isMine,
    required this.isEdited,
    required this.clientMessageId,
    required this.deliveryStatus,
    required this.sendingError,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: _toInt(json['id']),
      conversationId: _toInt(json['conversationId']),
      senderUserId: _toInt(json['senderUserId']),
      senderName: json['senderName']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      sentAtUtc:
          DateTime.tryParse(json['sentAtUtc']?.toString() ?? '') ??
          DateTime.now().toUtc(),
      isMine: json['isMine'] == true,
      isEdited: json['isEdited'] == true,
      clientMessageId: _nullableString(json['clientMessageId']),
      deliveryStatus: ChatMessageDeliveryStatus.sent,
      sendingError: null,
    );
  }

  factory ChatMessageModel.optimistic({
    required int conversationId,
    required String content,
    required String clientMessageId,
  }) {
    final now = DateTime.now().toUtc();

    return ChatMessageModel(
      id: -now.microsecondsSinceEpoch,
      conversationId: conversationId,
      senderUserId: 0,
      senderName: 'You',
      content: content,
      sentAtUtc: now,
      isMine: true,
      isEdited: false,
      clientMessageId: clientMessageId,
      deliveryStatus: ChatMessageDeliveryStatus.sending,
      sendingError: null,
    );
  }

  bool get isSending {
    return deliveryStatus == ChatMessageDeliveryStatus.sending;
  }

  bool get hasFailed {
    return deliveryStatus == ChatMessageDeliveryStatus.failed;
  }

  ChatMessageModel copyWith({
    int? id,
    int? conversationId,
    int? senderUserId,
    String? senderName,
    String? content,
    DateTime? sentAtUtc,
    bool? isMine,
    bool? isEdited,
    String? clientMessageId,
    ChatMessageDeliveryStatus? deliveryStatus,
    String? sendingError,
    bool clearSendingError = false,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderUserId: senderUserId ?? this.senderUserId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      sentAtUtc: sentAtUtc ?? this.sentAtUtc,
      isMine: isMine ?? this.isMine,
      isEdited: isEdited ?? this.isEdited,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      sendingError: clearSendingError
          ? null
          : sendingError ?? this.sendingError,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';

    return text.isEmpty ? null : text;
  }
}
