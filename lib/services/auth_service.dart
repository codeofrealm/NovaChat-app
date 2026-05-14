import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _testOtp = '12345';

  // Mock UID used when anonymous sign-in is disabled
  static const _mockUid = 'novachat_test_user';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    onCodeSent('test_mode', null);
  }

  Future<_MockUserCredential?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    debugPrint('AuthService.verifyOtp: entered="${otp.trim()}" expected="$_testOtp"');

    if (otp.trim() != _testOtp) {
      throw FirebaseAuthException(
        code: 'invalid-verification-code',
        message: 'Invalid OTP. Please enter $_testOtp.',
      );
    }

    debugPrint('AuthService.verifyOtp: OTP correct ✓');

    // Try anonymous sign-in first; if disabled, fall back to mock
    try {
      final result = await _auth.signInAnonymously();
      debugPrint('AuthService.verifyOtp: signInAnonymously uid=${result.user?.uid}');
      return _MockUserCredential(result.user);
    } on FirebaseAuthException catch (e) {
      debugPrint('AuthService.verifyOtp: signInAnonymously failed (${e.code}), using mock user');
      // Anonymous sign-in disabled — use mock user so flow continues
      return _MockUserCredential(null, mockUid: _mockUid);
    }
  }

  Future<UserCredential?> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
  }
}

/// Wraps either a real Firebase User or a mock UID
class _MockUserCredential {
  final User? _firebaseUser;
  final String? _mockUid;

  _MockUserCredential(this._firebaseUser, {String? mockUid})
      : _mockUid = mockUid;

  _MockUser? get user => _firebaseUser != null
      ? _MockUser(_firebaseUser.uid)
      : _mockUid != null
          ? _MockUser(_mockUid)
          : null;
}

class _MockUser {
  final String uid;
  const _MockUser(this.uid);
}
