import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/secure_storage_service.dart';

enum AuthState { idle, loading, otpSent, verified, error }

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final SecureStorageService _secureStorage = SecureStorageService();
  final DatabaseService _dbService = DatabaseService();

  AuthState _state = AuthState.idle;
  String _errorMessage = '';
  String _verificationId = '';
  UserModel? _currentUser;
  bool _isNewUser = false;
  String _pendingEmail = '';
  String _pendingPhone = '';
  String _resolvedUid = '';

  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isNewUser => _isNewUser;
  User? get firebaseUser => _authService.currentUser;
  String get uid =>
      _resolvedUid.isNotEmpty ? _resolvedUid : (firebaseUser?.uid ?? '');

  void _setState(AuthState s) {
    _state = s;
    notifyListeners();
  }

  // ─── Check for existing session on app start ───────────────
  Future<bool> checkExistingSession() async {
    final user = _authService.currentUser;
    if (user != null) {
      _resolvedUid = user.uid;
      await _loadAndRestoreSession(user.uid);
      return true;
    }
    // Check cached auth state
    final cached = await _secureStorage.getAuthState();
    if (cached != null && cached['uid'] != null) {
      final uid = cached['uid'] as String;
      final isNewUser = cached['isNewUser'] as bool? ?? false;
      // Verify the user still exists
      final profile = await _firestoreService.getUser(uid);
      if (profile != null) {
        _resolvedUid = uid;
        _isNewUser = isNewUser;
        _currentUser = profile;
        _setState(AuthState.verified);
        return true;
      }
    }
    return false;
  }

  Future<void> _loadAndRestoreSession(String userUid) async {
    _currentUser = await _firestoreService.getUser(userUid);
    _isNewUser = _currentUser == null;
    // Set user online
    if (_currentUser != null) {
      _dbService.setOnline(userUid, _currentUser!.name);
    }
    // Save session locally
    if (_currentUser != null) {
      await _secureStorage.cacheUserProfile(_currentUser!.toMap());
    }
    notifyListeners();
  }

  // ─── Send OTP via Firebase Phone Auth ──────────────────────
  Future<void> sendOtp(String phoneNumber) async {
    _pendingPhone = phoneNumber;
    _setState(AuthState.loading);
    try {
      await _authService.sendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId, _) {
          _verificationId = verificationId;
          _setState(AuthState.otpSent);
        },
        onError: (error) {
          _errorMessage = error;
          _setState(AuthState.error);
        },
        onAutoVerified: (_) {},
      );
    } catch (e) {
      _errorMessage = 'Failed to send OTP. Please try again.';
      _setState(AuthState.error);
    }
  }

  // ─── Verify OTP ────────────────────────────────────────────
  Future<void> verifyOtp(String otp) async {
    _setState(AuthState.loading);
    try {
      final result = await _authService.verifyOtp(
        verificationId: _verificationId,
        otp: otp,
        phoneNumber: _pendingPhone,
      );

      if (result?.user != null) {
        _resolvedUid = result!.user!.uid;
        await _checkUserExists(_resolvedUid);
      } else {
        _errorMessage = 'Verification failed. Please try again.';
        _setState(AuthState.error);
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.code == 'invalid-verification-code'
          ? 'Invalid OTP. Please try again.'
          : e.message ?? 'Authentication failed.';
      _setState(AuthState.error);
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      _setState(AuthState.error);
    }
  }

  // ─── Check if user profile exists in Firestore ─────────────
  Future<void> _checkUserExists(String userUid) async {
    try {
      // First try by UID
      UserModel? existing = await _firestoreService.getUser(userUid);

      // Fallback: search by phone number (handles re-installs / UID changes)
      if (existing == null && _pendingPhone.isNotEmpty) {
        existing = await _firestoreService.getUserByPhone(_pendingPhone);
        if (existing != null) {
          _resolvedUid = existing.uid;
        }
      }

      _isNewUser = existing == null;
      _currentUser = existing;

      if (existing != null) {
        _dbService.setOnline(_resolvedUid, existing.name);
        await _secureStorage.saveAuthState(_resolvedUid, false);
        await _secureStorage.cacheUserProfile(existing.toMap());
      }
      _setState(AuthState.verified);
    } catch (e) {
      _isNewUser = true;
      _currentUser = null;
      _setState(AuthState.verified);
    }
  }

  // ─── Save Email (for new users) ────────────────────────────
  Future<void> saveEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final existing = await _firestoreService.getUserByEmail(normalizedEmail);
    if (existing != null && existing.uid != uid) {
      throw Exception('Email already registered. Please use another email.');
    }
    _pendingEmail = normalizedEmail;
  }

  // ─── Save Profile to Firestore (for new users) ─────────────
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String email,
    required String profileImageUrl,
  }) async {
    final userUid = uid;
    if (userUid.isEmpty) throw Exception('User not authenticated.');
    final resolvedEmail =
        (email.isNotEmpty ? email : _pendingEmail).trim().toLowerCase();
    final resolvedPhone = (phone.isNotEmpty ? phone : _pendingPhone).trim();

    final existingByPhone =
        await _firestoreService.getUserByPhone(resolvedPhone);
    if (existingByPhone != null && existingByPhone.uid != userUid) {
      throw Exception('Phone number already registered. Please login.');
    }

    final existingByEmail =
        await _firestoreService.getUserByEmail(resolvedEmail);
    if (existingByEmail != null && existingByEmail.uid != userUid) {
      throw Exception('Email already registered. Please use another email.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final user = UserModel(
      uid: userUid,
      name: name.trim(),
      email: resolvedEmail,
      phone: resolvedPhone,
      profileImage: profileImageUrl,
      createdAt: now,
      lastSeen: now,
      isOnline: true,
    );

    await _firestoreService.createUser(user);
    _currentUser = user;
    _dbService.setOnline(userUid, name);
    await _secureStorage.saveAuthState(userUid, true);
    await _secureStorage.cacheUserProfile(user.toMap());
    notifyListeners();
  }

  // ─── Load Current User ─────────────────────────────────────
  Future<void> loadCurrentUser() async {
    final userUid = uid;
    if (userUid.isEmpty) return;
    try {
      final cached = await _secureStorage.getCachedUserProfile();
      if (cached != null) {
        _currentUser = UserModel.fromMap(cached, userUid);
        notifyListeners();
      }
      final fresh = await _firestoreService.getUser(userUid);
      if (fresh != null) {
        _currentUser = fresh;
        await _secureStorage.cacheUserProfile(fresh.toMap());
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadCurrentUser error: $e');
    }
  }

  // ─── Update Profile Fields ─────────────────────────────────
  Future<void> updateUserField(String userUid, Map<String, dynamic> data) async {
    await _firestoreService.updateUser(userUid, data);
    await loadCurrentUser();
  }

  // ─── Sign Out ──────────────────────────────────────────────
  Future<void> signOut() async {
    final uid = _resolvedUid;
    if (uid.isNotEmpty) {
      _dbService.setOffline(uid);
    }
    await _authService.signOut();
    await _secureStorage.clearAuthState();
    _currentUser = null;
    _pendingEmail = '';
    _pendingPhone = '';
    _resolvedUid = '';
    _state = AuthState.idle;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    if (_state == AuthState.error) _setState(AuthState.idle);
  }
}
