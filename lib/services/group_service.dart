import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import 'package:uuid/uuid.dart';

class GroupService {
  final _db = FirebaseDatabase.instance.ref();
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String createdBy,
    required List<String> members,
    String groupImage = '',
  }) async {
    final groupId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final group = GroupModel(
      groupId: groupId,
      name: name,
      description: description,
      groupImage: groupImage,
      createdBy: createdBy,
      members: [...members, createdBy],
      admins: [createdBy],
      createdAt: now,
    );
    await _db.child('groups/$groupId').set(group.toMap());
    return group;
  }

  Stream<List<GroupModel>> groupsStream(String uid) {
    return _db.child('groups').onValue.asBroadcastStream().map((event) {
      if (!event.snapshot.exists) return <GroupModel>[];
      final map = event.snapshot.value as Map;
      return map.entries
          .map((e) => GroupModel.fromMap(e.value as Map, e.key as String))
          .where((g) => g.members.contains(uid))
          .toList()
        ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
    }).handleError((_) => <GroupModel>[]);
  }

  Future<void> sendGroupMessage(String groupId, MessageModel message) async {
    try {
      final ref = _db.child('group_messages/$groupId').push();
      await ref.set(message.toMap());
      await _db.child('groups/$groupId').update({
        'lastMessage': message.type == MessageType.image ? '📷 Photo' : message.text,
        'lastMessageTime': message.timestamp,
      });
    } catch (_) {}
  }

  Future<void> deleteGroupMessage(String groupId, String messageId) async {
    try {
      await _db.child('group_messages/$groupId/$messageId').remove();
    } catch (_) {}
  }

  Stream<List<MessageModel>> groupMessagesStream(String groupId) {
    return _db
        .child('group_messages/$groupId')
        .orderByChild('timestamp')
        .onValue.asBroadcastStream()
        .map((event) {
      if (!event.snapshot.exists) return <MessageModel>[];
      final map = event.snapshot.value as Map;
      return map.entries
          .map((e) => MessageModel.fromMap(e.value as Map, e.key as String))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }).handleError((_) => <MessageModel>[]);
  }

  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final snap = await _db.child('groups/$groupId').get();
      if (!snap.exists) return null;
      return GroupModel.fromMap(snap.value as Map, groupId);
    } catch (_) {
      return null;
    }
  }

  Future<String> uploadGroupImage(String groupId, File file) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref('group_images/$groupId/$id.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }
}
