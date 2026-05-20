import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../services/database_service.dart';

class ChatViewModel extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final _uuid = const Uuid();

  bool get _hasAuth => FirebaseAuth.instance.currentUser != null;

  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  double _uploadProgress = 0;
  StreamSubscription? _messagesSub;

  List<MessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  double get uploadProgress => _uploadProgress;

  void listenToMessages(String chatId, String currentUid) {
    _isLoading = true;
    notifyListeners();
    _messagesSub?.cancel();
    _messagesSub = _db.messagesStream(chatId).listen((msgs) {
      _messages = msgs;
      _isLoading = false;
      notifyListeners();
      // Mark messages as seen when chat is open
      _db.markMessagesSeen(chatId, currentUid);
    });
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    final msg = MessageModel(
      messageId: _uuid.v4(),
      senderId: senderId,
      receiverId: receiverId,
      text: text.trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isDelivered: true,
      isSeen: false,
      type: MessageType.text,
    );
    await _db.sendMessage(chatId, msg);
  }

  Future<void> sendImageMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required File imageFile,
    String text = '',
  }) async {
    if (!_hasAuth) return; // skip upload in mock mode
    _isSending = true;
    _uploadProgress = 0;
    notifyListeners();
    try {
      final task = _db.uploadChatImageWithProgress(chatId, imageFile);
      task.snapshotEvents.listen((snap) {
        _uploadProgress = snap.bytesTransferred / snap.totalBytes;
        notifyListeners();
      });
      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();
      final msg = MessageModel(
        messageId: _uuid.v4(),
        senderId: senderId,
        receiverId: receiverId,
        text: text,
        imageUrl: url,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isDelivered: true,
        isSeen: false,
        type: MessageType.image,
      );
      await _db.sendMessage(chatId, msg);
    } catch (_) {
    } finally {
      _isSending = false;
      _uploadProgress = 0;
      notifyListeners();
    }
  }

  Future<void> sendVoiceMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required File voiceFile,
  }) async {
    if (!_hasAuth) return; // skip upload in mock mode
    _isSending = true;
    notifyListeners();
    try {
      final url = await _db.uploadVoiceMessage(chatId, voiceFile);
      final msg = MessageModel(
        messageId: _uuid.v4(),
        senderId: senderId,
        receiverId: receiverId,
        voiceUrl: url,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isDelivered: true,
        isSeen: false,
        type: MessageType.voice,
      );
      await _db.sendMessage(chatId, msg);
    } catch (_) {
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  Future<void> sendEmojiMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String emoji,
  }) async {
    final msg = MessageModel(
      messageId: _uuid.v4(),
      senderId: senderId,
      receiverId: receiverId,
      text: emoji,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isDelivered: true,
      isSeen: false,
      type: MessageType.emoji,
    );
    await _db.sendMessage(chatId, msg);
  }

  Future<void> addReaction(
    String chatId,
    String messageId,
    String uid,
    String emoji,
  ) async {
    await _db.addReaction(chatId, messageId, uid, emoji);
  }

  Future<void> removeReaction(
    String chatId,
    String messageId,
    String uid,
  ) async {
    await _db.removeReaction(chatId, messageId, uid);
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _db.deleteMessage(chatId, messageId);
  }

  void setTyping(String chatId, String uid, bool isTyping) {
    _db.setTyping(chatId, uid, isTyping);
  }

  void clearTyping(String chatId, String uid) {
    _db.clearTyping(chatId, uid);
  }

  Stream<bool> typingStream(String chatId, String otherUid) =>
      _db.typingStream(chatId, otherUid);

  Future<void> markSeen(String chatId, String currentUid) async {
    await _db.markMessagesSeen(chatId, currentUid);
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }
}