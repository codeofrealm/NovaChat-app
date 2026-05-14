enum MessageType { text, image, voice, emoji }

class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String text;
  final String imageUrl;
  final String voiceUrl;
  final int timestamp;
  final bool isSeen;
  final bool isDelivered;
  final MessageType type;
  final Map<String, String> reactions;

  const MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    this.text = '',
    this.imageUrl = '',
    this.voiceUrl = '',
    required this.timestamp,
    this.isSeen = false,
    this.isDelivered = false,
    this.type = MessageType.text,
    this.reactions = const {},
  });

  factory MessageModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return MessageModel(
      messageId: id,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      voiceUrl: map['voiceUrl'] ?? '',
      timestamp: map['timestamp'] ?? 0,
      isSeen: map['isSeen'] ?? false,
      isDelivered: map['isDelivered'] ?? false,
      type: MessageType.values.firstWhere(
        (e) => e.name == (map['type'] ?? 'text'),
        orElse: () => MessageType.text,
      ),
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'receiverId': receiverId,
    'text': text,
    'imageUrl': imageUrl,
    'voiceUrl': voiceUrl,
    'timestamp': timestamp,
    'isSeen': isSeen,
    'isDelivered': isDelivered,
    'type': type.name,
    'reactions': reactions,
  };
}

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final int lastMessageTime;
  final int unreadCount;

  const ChatModel({
    required this.chatId,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageTime = 0,
    this.unreadCount = 0,
  });

  factory ChatModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return ChatModel(
      chatId: id,
      participants: List<String>.from(map['participants']?.keys ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] ?? 0,
      unreadCount: map['unreadCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime,
    'unreadCount': unreadCount,
  };
}
