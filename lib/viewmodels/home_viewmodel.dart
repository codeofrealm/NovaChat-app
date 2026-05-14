import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class HomeViewModel extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final FirestoreService _fs = FirestoreService();
  final NotificationService _notifService = NotificationService();

  List<Map<String, dynamic>> _chats = [];
  List<UserModel> _allUsers = [];
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  StreamSubscription? _chatsSub;
  int _totalUnread = 0;

  List<Map<String, dynamic>> get chats => _chats;
  List<UserModel> get allUsers => _allUsers;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  int get totalUnread => _totalUnread;

  void listenToChats(String uid) {
    _isLoading = true;
    notifyListeners();
    _chatsSub?.cancel();
    _chatsSub = _db.chatsStream(uid).listen((chats) {
      _chats = chats;
      _isLoading = false;
      _computeTotalUnread(uid);
      notifyListeners();
    });
  }

  Future<void> _computeTotalUnread(String uid) async {
    int total = 0;
    for (final chat in _chats) {
      final chatId = chat['id'] as String?;
      if (chatId == null) continue;
      final count = await _db.getUnreadCountSync(uid);
      total += count;
    }
    _totalUnread = total;
    notifyListeners();
  }

  Future<void> loadAllUsers(String currentUid) async {
    _isLoading = true;
    notifyListeners();
    _allUsers = await _fs.getAllUsers(currentUid);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> searchUsers(String query, String currentUid) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }
    _isSearching = true;
    notifyListeners();
    _searchResults = await _fs.searchUsers(query, currentUid);
    _isSearching = false;
    notifyListeners();
  }

  Stream<UserModel?> userStream(String uid) => _fs.userStream(uid);
  Stream<int> unreadCountStream(String chatId, String uid) =>
      _db.unreadCountStream(chatId, uid);

  void setOnline(String uid, String name) => _db.setOnline(uid, name);
  void setOffline(String uid) => _db.setOffline(uid);

  void requestNotificationPermission(String uid) async {
    final token = await _notifService.getToken();
    if (token != null) {
      await _notifService.saveToken(uid, token);
    }
  }

  @override
  void dispose() {
    _chatsSub?.cancel();
    super.dispose();
  }
}