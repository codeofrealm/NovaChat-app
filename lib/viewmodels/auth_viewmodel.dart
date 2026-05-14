import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';

enum AuthState { idle, loading, otpSent, verified, error }

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  AuthState _state = AuthState.idle;
  String _errorMessage = '';
  String _verificationId = '';
  int? _resendToken;
  UserModel? _currentUser;
  bool _isNewUser = false;
  String _pendingEmail = '';

  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isNewUser => _isNewUser;
  User? get firebaseUser => _authService.currentUser;

  void _setState(AuthState s) {
    _state = s;
    notifyListeners();
  }

  // ─── Send OTP ────────────────────────────────────────────
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

  // ─── Verify OTP ──────────────────────────────────────────
  Future<void> verifyOtp(String otp) async {
    _setState(AuthState.loading);
    try {
      final result = await _authService.verifyOtp(
        verificationId: _verificationId,
        otp: otp,
      );
      if (result?.user != null) {
        await _checkUserExists(result!.user!);
      } else {
        _errorMessage = 'Verification failed. Please try again.';
        _setState(AuthState.error);
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setState(AuthState.error);
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
      _setState(AuthState.error);
    }
  }

  Future<void> _handleCredential(PhoneAuthCredential credential) async {
    try {
      final result = await _authService.signInWithCredential(credential);
      if (result?.user != null) {
        await _checkUserExists(result!.user!);
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapAuthError(e.code);
      _setState(AuthState.error);
    } catch (e) {
      _errorMessage = 'Auto-verification failed.';
      _setState(AuthState.error);
    }
  }

  Future<void> _checkUserExists(User user) async {
    try {
      final existing = await _firestoreService.getUser(user.uid);
      _isNewUser = existing == null;
      _currentUser = existing;
      _setState(AuthState.verified);
    } catch (e) {
      // Even if Firestore check fails, treat as new user and continue
      _isNewUser = true;
      _currentUser = null;
      _setState(AuthState.verified);
    }
  }

  // ─── Save Email (held in memory until profile save) ──────
  Future<void> saveEmail(String email) async {
    _pendingEmail = email.trim();
  }

  // ─── Save Profile to Firestore ───────────────────────────
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String email,
    required String profileImageUrl,
  }) async {
    final uid = firebaseUser?.uid;
    if (uid == null) {
      throw Exception('User not authenticated. Please login again.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final resolvedEmail =
        email.isNotEmpty ? email : _pendingEmail;
    final resolvedPhone =
        phone.isNotEmpty ? phone : (firebaseUser?.phoneNumber ?? '');

    final user = UserModel(
      uid: uid,
      name: name.trim(),
      email: resolvedEmail,
      phone: resolvedPhone,
      profileImage: profileImageUrl,
      createdAt: now,
      lastSeen: now,
    );

    await _firestoreService.createUser(user);
    _currentUser = user;
    notifyListeners();
  }

  // ─── Load Current User from Firestore ────────────────────
  Future<void> loadCurrentUser() async {
    final uid = firebaseUser?.uid;
    if (uid == null) return;
    try {
      _currentUser = await _firestoreService.getUser(uid);
      notifyListeners();
    } catch (_) {}
  }

  // ─── Update User Fields ──────────────────────────────────
  Future<void> updateUserField(String uid, Map<String, dynamic> data) async {
    await _firestoreService.updateUser(uid, data);
    await loadCurrentUser();
  }

  // ─── Sign Out ────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _pendingEmail = '';
    _state = AuthState.idle;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    if (_state == AuthState.error) _setState(AuthState.idle);
  }

  // ─── Map Firebase error codes to readable messages ───────
  String _mapAuthError(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Invalid OTP. Please check and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'invalid-phone-number':
        return 'Invalid phone number format.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
