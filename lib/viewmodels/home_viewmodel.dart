import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class HomeViewModel extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Map<String, dynamic>> _chats = [];
  List<UserModel> _allUsers = [];
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  bool _isSearching = false;
  StreamSubscription? _chatsSub;

  List<Map<String, dynamic>> get chats => _chats;
  List<UserModel> get allUsers => _allUsers;
  List<UserModel> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;

  void listenToChats(String uid) {
    _isLoading = true;
    notifyListeners();
    _chatsSub?.cancel();
    _chatsSub = _db.chatsStream(uid).listen((chats) {
      _chats = chats;
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> loadAllUsers(String currentUid) async {
    _allUsers = await _db.getAllUsers(currentUid);
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
    _searchResults = await _db.searchUsers(query, currentUid);
    _isSearching = false;
    notifyListeners();
  }

  Stream<UserModel?> userStream(String uid) => _db.userStream(uid);

  Stream<int> unreadCountStream(String chatId, String uid) =>
      _db.unreadCountStream(chatId, uid);

  void setOnline(String uid) => _db.setOnline(uid);
  void setOffline(String uid) => _db.setOffline(uid);

  @override
  void dispose() {
    _chatsSub?.cancel();
    super.dispose();
  }
}
