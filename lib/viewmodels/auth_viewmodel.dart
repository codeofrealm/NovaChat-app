import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user_model.dart';

enum AuthState { idle, loading, otpSent, verified, error }

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();

  AuthState _state = AuthState.idle;
  String _errorMessage = '';
  String _verificationId = '';
  int? _resendToken;
  UserModel? _currentUser;
  bool _isNewUser = false;

  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isNewUser => _isNewUser;
  User? get firebaseUser => _authService.currentUser;

  void _setState(AuthState s) {
    _state = s;
    notifyListeners();
  }

  // Send OTP
  Future<void> sendOtp(String phoneNumber) async {
    _setState(AuthState.loading);
    await _authService.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId, resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        _setState(AuthState.otpSent);
      },
      onError: (error) {
        _errorMessage = error;
        _setState(AuthState.error);
      },
      onAutoVerified: (credential) async {
        await _handleCredential(credential);
      },
    );
  }

  // Verify OTP
  Future<void> verifyOtp(String otp) async {
    _setState(AuthState.loading);
    try {
      final result = await _authService.verifyOtp(
        verificationId: _verificationId,
        otp: otp,
      );
      if (result != null) {
        await _checkUserExists(result.user!);
      }
    } catch (e) {
      _errorMessage = 'Invalid OTP. Please try again.';
      _setState(AuthState.error);
    }
  }

  Future<void> _handleCredential(PhoneAuthCredential credential) async {
    try {
      final result = await _authService.signInWithCredential(credential);
      if (result != null) await _checkUserExists(result.user!);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(AuthState.error);
    }
  }

  Future<void> _checkUserExists(User user) async {
    final existing = await _dbService.getUser(user.uid);
    _isNewUser = existing == null;
    _currentUser = existing;
    _setState(AuthState.verified);
  }

  // Save email
  Future<void> saveEmail(String email) async {
    final uid = firebaseUser?.uid;
    if (uid == null) return;
    await _dbService.updateUser(uid, {'email': email});
  }

  // Save profile
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String email,
    required String profileImageUrl,
  }) async {
    final uid = firebaseUser?.uid;
    if (uid == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final user = UserModel(
      uid: uid,
      name: name,
      email: email,
      phone: phone,
      profileImage: profileImageUrl,
      createdAt: now,
      lastSeen: now,
    );
    await _dbService.createUser(user);
    _currentUser = user;
    notifyListeners();
  }

  // Load current user
  Future<void> loadCurrentUser() async {
    final uid = firebaseUser?.uid;
    if (uid == null) return;
    _currentUser = await _dbService.getUser(uid);
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_currentUser != null) {
      _dbService.setOffline(_currentUser!.uid);
    }
    await _authService.signOut();
    _currentUser = null;
    _state = AuthState.idle;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    if (_state == AuthState.error) _setState(AuthState.idle);
  }
}
