import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  final _db = FirebaseDatabase.instance.ref();
  final _fs = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  // ─── Users ────────────────────────────────────────────────
  Future<List<UserModel>> getAllUsers(String currentUid) async {
    try {
      final snap = await _db.child('users').get();
      if (!snap.exists) return [];
      final map = snap.value as Map;
      return map.entries
          .where((e) => e.key != currentUid)
          .map((e) => UserModel.fromMap(e.value as Map, e.key as String))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Stream<UserModel?> userStream(String uid) {
    return _db.child('users/$uid').onValue.map((e) {
      if (!e.snapshot.exists) return null;
      return UserModel.fromMap(e.snapshot.value as Map, uid);
    });
  }

  // ─── Online Presence ──────────────────────────────────────
  void setOnline(String uid, String name) {
    final updates = {
      'presence/$uid': {
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'name': name,
      },
      'users/$uid/isOnline': true,
      'users/$uid/lastSeen': ServerValue.timestamp,
    };
    _db.update(updates);

    // On-disconnect handlers
    _db.child('presence/$uid').onDisconnect().update({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });
    _db.child('users/$uid').onDisconnect().update({
      'isOnline': false,
      'lastSeen': ServerValue.timestamp,
    });

    // Mirror to Firestore
    _fs.collection('users').doc(uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  void setOffline(String uid) {
    final updates = {
      'presence/$uid': {
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
      },
      'users/$uid/isOnline': false,
      'users/$uid/lastSeen': ServerValue.timestamp,
    };
    _db.update(updates);

    _fs.collection('users').doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

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
    return _db
        .child('chats/$chatId/typing/$otherUid')
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? false);
  }

  void clearTyping(String chatId, String uid) {
    _db.child('chats/$chatId/typing/$uid').remove();
  }

  // ─── Chats ────────────────────────────────────────────────
  Future<void> createOrUpdateChat({
    required String chatId,
    required String uid1,
    required String uid2,
    required String lastMessage,
    required String lastMessageType,
    required int time,
  }) async {
    final chatData = {
      'participants/$uid1': true,
      'participants/$uid2': true,
      'lastMessage': lastMessage,
      'lastMessageType': lastMessageType,
      'lastMessageTime': time,
    };
    await _db.child('chats/$chatId').set(chatData);
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

  /// Check if a chat already exists between two users
  Future<bool> chatExists(String uid1, String uid2) async {
    final chatId = _getChatId(uid1, uid2);
    final snap = await _db.child('chats/$chatId').get();
    return snap.exists;
  }

  String _getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  // ─── Messages ─────────────────────────────────────────────
  Future<void> sendMessage(String chatId, MessageModel message) async {
    final ref = _db.child('messages/$chatId').push();
    await ref.set(message.toMap());

    final msgText = message.type == MessageType.image
        ? '📷 Photo'
        : message.type == MessageType.voice
            ? '🎤 Voice message'
            : message.type == MessageType.emoji
                ? '😊 Emoji'
                : message.text;

    await createOrUpdateChat(
      chatId: chatId,
      uid1: message.senderId,
      uid2: message.receiverId,
      lastMessage: msgText,
      lastMessageType: message.type.name,
      time: message.timestamp,
    );

    // Mark as delivered
    await ref.update({'isDelivered': true});
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

  Future<void> markMessageDelivered(String chatId, String messageId) async {
    await _db
        .child('messages/$chatId/$messageId')
        .update({'isDelivered': true});
  }

  // ─── Reactions ────────────────────────────────────────────
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

  Future<void> removeReaction(String chatId, String messageId, String uid) async {
    await _db
        .child('messages/$chatId/$messageId/reactions/$uid')
        .remove();
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

  Future<int> getUnreadCountSync(String uid) async {
    int total = 0;
    final chatsSnap = await _db
        .child('chats')
        .orderByChild('participants/$uid')
        .equalTo(true)
        .get();
    if (!chatsSnap.exists) return 0;

    for (final chatEntry in chatsSnap.children) {
      final chatId = chatEntry.key;
      final msgsSnap = await _db
          .child('messages/$chatId')
          .orderByChild('receiverId')
          .equalTo(uid)
          .get();
      if (msgsSnap.exists) {
        for (final msgEntry in msgsSnap.children) {
          if (!((msgEntry.value as Map?)?['isSeen'] as bool? ?? false)) {
            total++;
          }
        }
      }
    }
    return total;
  }

  // ─── Image / Voice Upload via Storage ─────────────────────
  Future<String> uploadChatImage(String chatId, File file) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref('chat_images/$chatId/$id.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<String> uploadVoiceMessage(String chatId, File file) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref('voice_messages/$chatId/$id.aac');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'audio/aac'),
    );
    return await task.ref.getDownloadURL();
  }

  UploadTask uploadChatImageWithProgress(String chatId, File file) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref('chat_images/$chatId/$id.jpg');
    return ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  }
}
