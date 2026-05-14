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
  UserModel? _currentUser;
  bool _isNewUser = false;
  String _pendingEmail = '';
  String _pendingPhone = '';

  // Holds the resolved UID — either from Firebase user or mock
  String _resolvedUid = '';

  AuthState get state => _state;
  String get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isNewUser => _isNewUser;

  // Returns real Firebase user if available, else null (mock mode)
  User? get firebaseUser => _authService.currentUser;

  // Always returns a valid UID (real or mock)
  String get uid => _resolvedUid.isNotEmpty
      ? _resolvedUid
      : (firebaseUser?.uid ?? '');

  void _setState(AuthState s) {
    _state = s;
    notifyListeners();
  }

  // ─── Send OTP ─────────────────────────────────────────────
  Future<void> sendOtp(String phoneNumber) async {
    _pendingPhone = phoneNumber;
    _setState(AuthState.loading);
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
  }

  // ─── Verify OTP ───────────────────────────────────────────
  Future<void> verifyOtp(String otp) async {
    _setState(AuthState.loading);
    try {
      debugPrint('AuthViewModel.verifyOtp: calling authService.verifyOtp...');
      final result = await _authService.verifyOtp(
        verificationId: _verificationId,
        otp: otp,
      );
      debugPrint('AuthViewModel.verifyOtp: result.user.uid=${result?.user?.uid}');

      if (result?.user != null) {
        _resolvedUid = result!.user!.uid;
        await _checkUserExists(_resolvedUid);
      } else {
        _errorMessage = 'Verification failed. Please try again.';
        _setState(AuthState.error);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthViewModel.verifyOtp FirebaseAuthException: ${e.code} ${e.message}');
      _errorMessage = e.code == 'invalid-verification-code'
          ? 'Invalid OTP. Please enter 12345.'
          : e.message ?? 'Authentication failed.';
      _setState(AuthState.error);
    } catch (e) {
      debugPrint('AuthViewModel.verifyOtp error: $e');
      _errorMessage = 'Something went wrong. Please try again.';
      _setState(AuthState.error);
    }
  }

  // ─── Check if user profile exists in Firestore ────────────
  Future<void> _checkUserExists(String userUid) async {
    debugPrint('AuthViewModel._checkUserExists: uid=$userUid');
    try {
      final existing = await _firestoreService.getUser(userUid);
      _isNewUser = existing == null;
      _currentUser = existing;
      debugPrint('AuthViewModel._checkUserExists: isNewUser=$_isNewUser');
    } catch (e) {
      debugPrint('AuthViewModel._checkUserExists error: $e — treating as new user');
      _isNewUser = true;
      _currentUser = null;
    }
    _setState(AuthState.verified);
  }

  // ─── Save Email ───────────────────────────────────────────
  Future<void> saveEmail(String email) async {
    _pendingEmail = email.trim();
  }

  // ─── Save Profile to Firestore ────────────────────────────
  Future<void> saveProfile({
    required String name,
    required String phone,
    required String email,
    required String profileImageUrl,
  }) async {
    final userUid = uid;
    if (userUid.isEmpty) {
      throw Exception('User not authenticated. Please login again.');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final user = UserModel(
      uid: userUid,
      name: name.trim(),
      email: email.isNotEmpty ? email : _pendingEmail,
      phone: phone.isNotEmpty ? phone : _pendingPhone,
      profileImage: profileImageUrl,
      createdAt: now,
      lastSeen: now,
    );
    debugPrint('AuthViewModel.saveProfile: saving uid=$userUid name=${user.name}');
    await _firestoreService.createUser(user);
    _currentUser = user;
    debugPrint('AuthViewModel.saveProfile: saved successfully ✓');
    notifyListeners();
  }

  // ─── Load Current User ────────────────────────────────────
  Future<void> loadCurrentUser() async {
    final userUid = uid;
    if (userUid.isEmpty) return;
    try {
      _currentUser = await _firestoreService.getUser(userUid);
      notifyListeners();
    } catch (e) {
      debugPrint('AuthViewModel.loadCurrentUser error: $e');
    }
  }

  Future<void> updateUserField(String userUid, Map<String, dynamic> data) async {
    await _firestoreService.updateUser(userUid, data);
    await loadCurrentUser();
  }

  // ─── Sign Out ─────────────────────────────────────────────
  Future<void> signOut() async {
    await _authService.signOut();
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
