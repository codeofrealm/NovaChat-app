import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;
  final _uuid = const Uuid();

  Future<String> uploadProfileImage(String uid, File file) async {
    final ref = _storage.ref('profile_images/$uid.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<String> uploadChatImage(String chatId, File file) async {
    final id = _uuid.v4();
    final ref = _storage.ref('chat_images/$chatId/$id.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<String> uploadVoiceMessage(String chatId, File file) async {
    final id = _uuid.v4();
    final ref = _storage.ref('voice_messages/$chatId/$id.aac');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'audio/aac'),
    );
    return await task.ref.getDownloadURL();
  }

  // Upload with progress callback
  UploadTask uploadChatImageWithProgress(String chatId, File file) {
    final id = _uuid.v4();
    final ref = _storage.ref('chat_images/$chatId/$id.jpg');
    return ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
  }
}
