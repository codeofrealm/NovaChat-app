import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/message_model.dart';

class DatabaseService {
  final _db = FirebaseDatabase.instance.ref();
  final _fs = FirebaseFirestore.instance;

  // ─── Online Presence ──────────────────────────────────────
  // Writes to RTDB for low-latency presence detection
  // AND mirrors into Firestore so chat list / user streams stay in sync
  void setOnline(String uid) {
    // RTDB presence node
    _db.child('presence/$uid').update({
      'isOnline': true,
      'lastSeen': ServerValue.timestamp,
    });
    // Mirror to Firestore
    _fs.collection('users').doc(uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((_) {}); // ignore if doc doesn't exist yet

    // On disconnect: RTDB auto-sets offline
    _db.child('presence/$uid').onDisconnect().update({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });
    // On disconnect: also mirror offline to Firestore via Cloud Function
    // (For client-side fallback, we rely on app lifecycle in HomeScreen)
  }

  void setOffline(String uid) {
    _db.child('presence/$uid').update({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });
    _fs.collection('users').doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  // Live presence stream from RTDB (fastest)
  Stream<Map<String, dynamic>> presenceStream(String uid) {
    return _db.child('presence/$uid').onValue.map((e) {
      if (!e.snapshot.exists) return {'isOnline': false, 'lastSeen': 0};
      return Map<String, dynamic>.from(e.snapshot.value as Map);
    });
  }

  // ─── Typing Indicator ─────────────────────────────────────
  void setTyping(String chatId, String uid, bool isTyping) {
    _db.child('chats/$chatId/typing/$uid').set(isTyping);
  }

  Stream<bool> typingStream(String chatId, String otherUid) {
    return _db.child('chats/$chatId/typing/$otherUid').onValue.map(
      (e) => (e.snapshot.value as bool?) ?? false,
    );
  }

  // ─── Chats ────────────────────────────────────────────────
  Future<void> createOrUpdateChat(
    String chatId,
    String uid1,
    String uid2,
    String lastMessage,
    int time,
  ) async {
    await _db.child('chats/$chatId').update({
      'participants/$uid1': true,
      'participants/$uid2': true,
      'lastMessage': lastMessage,
      'lastMessageTime': time,
    });
  }

  Stream<List<Map<String, dynamic>>> chatsStream(String uid) {
    return _db
        .child('chats')
        .orderByChild('participants/$uid')
        .equalTo(true)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];
      final map = event.snapshot.value as Map;
      return map.entries
          .map((e) => {
                'id': e.key,
                ...Map<String, dynamic>.from(e.value as Map),
              })
          .toList()
        ..sort((a, b) =>
            ((b['lastMessageTime'] as int?) ?? 0)
                .compareTo((a['lastMessageTime'] as int?) ?? 0));
    });
  }

  // ─── Messages ─────────────────────────────────────────────
  Future<void> sendMessage(String chatId, MessageModel message) async {
    final ref = _db.child('messages/$chatId').push();
    await ref.set(message.toMap());
    await createOrUpdateChat(
      chatId,
      message.senderId,
      message.receiverId,
      message.type == MessageType.image
          ? '📷 Photo'
          : message.type == MessageType.voice
              ? '🎤 Voice message'
              : message.text,
      message.timestamp,
    );
  }

  Stream<List<MessageModel>> messagesStream(String chatId) {
    return _db
        .child('messages/$chatId')
        .orderByChild('timestamp')
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return [];
      final map = event.snapshot.value as Map;
      return map.entries
          .map((e) => MessageModel.fromMap(e.value as Map, e.key))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
  }

  Future<void> markMessagesSeen(String chatId, String receiverId) async {
    final snap = await _db
        .child('messages/$chatId')
        .orderByChild('receiverId')
        .equalTo(receiverId)
        .get();
    if (!snap.exists) return;
    final map = snap.value as Map;
    final updates = <String, dynamic>{};
    for (final entry in map.entries) {
      if (!(entry.value['isSeen'] as bool? ?? false)) {
        updates['messages/$chatId/${entry.key}/isSeen'] = true;
      }
    }
    if (updates.isNotEmpty) await _db.update(updates);
  }

  Future<void> addReaction(
    String chatId,
    String messageId,
    String uid,
    String emoji,
  ) async {
    await _db
        .child('messages/$chatId/$messageId/reactions/$uid')
        .set(emoji);
  }

  // ─── Unread Count ──────────────────────────────────────────
  Stream<int> unreadCountStream(String chatId, String uid) {
    return _db
        .child('messages/$chatId')
        .orderByChild('receiverId')
        .equalTo(uid)
        .onValue
        .map((event) {
      if (!event.snapshot.exists) return 0;
      final map = event.snapshot.value as Map;
      return map.values
          .where((v) => !(v['isSeen'] as bool? ?? false))
          .length;
    });
  }
}
