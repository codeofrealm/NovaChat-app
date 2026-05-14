import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';

class ProfileViewModel extends ChangeNotifier {
  final FirestoreService _db = FirestoreService();
  final StorageService _storage = StorageService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<String> uploadProfileImage(String uid, File file) async {
    _isLoading = true;
    notifyListeners();
    try {
      return await _storage.uploadProfileImage(uid, file);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(
    String uid, {
    String? name,
    String? about,
    String? profileImage,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (about != null) data['about'] = about;
      if (profileImage != null) data['profileImage'] = profileImage;
      await _db.updateUser(uid, data);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<UserModel?> profileStream(String uid) => _db.userStream(uid);
}
