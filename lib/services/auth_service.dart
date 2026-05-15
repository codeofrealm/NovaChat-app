import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const _testOtp = '12345';

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  Stream<User?> get idTokenChanges => _auth.idTokenChanges();

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    if (kDebugMode) {
      onCodeSent('novachat-debug-verification', null);
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) {
          onAutoVerified(credential);
        },
        verificationFailed: (e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (verificationId, resendToken) {
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (verificationId) {},
        timeout: const Duration(seconds: 60),
      );
    } on FirebaseAuthException catch (e) {
      onError(e.message ?? 'Failed to send OTP');
    } catch (e) {
      onError('Failed to send OTP. Please try again.');
    }
  }

  Future<_MockUserCredential?> verifyOtp({
    required String verificationId,
    required String otp,
    required String phoneNumber,
  }) async {
    if (kDebugMode && otp.trim() == _testOtp) {
      return _testCredentialForPhone(phoneNumber);
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final result = await _auth.signInWithCredential(credential);
      return _MockUserCredential(result.user);
    } on FirebaseAuthException catch (e) {
      // Fallback for test mode
      if (otp.trim() == _testOtp) {
        return _testCredentialForPhone(phoneNumber);
      }
      throw e;
    } catch (e) {
      if (otp.trim() == _testOtp) {
        return _testCredentialForPhone(phoneNumber);
      }
      rethrow;
    }
  }

  Future<_MockUserCredential> _testCredentialForPhone(String phoneNumber) async {
    final mockUid = _mockUidForPhone(phoneNumber);
    try {
      final result = await _auth.signInAnonymously();
      return _MockUserCredential(result.user, mockUid: mockUid);
    } catch (_) {
      return _MockUserCredential(null, mockUid: mockUid);
    }
  }

  String _mockUidForPhone(String phoneNumber) {
    final digits = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 'novachat_test_user';
    }
    return 'novachat_test_$digits';
  }

  // Real phone auth sign-in
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

class _MockUserCredential {
  final User? _firebaseUser;
  final String? _mockUid;

  _MockUserCredential(this._firebaseUser, {String? mockUid})
      : _mockUid = mockUid;

  _MockUser? get user => _mockUid != null
      ? _MockUser(_mockUid)
      : _firebaseUser != null
          ? _MockUser(_firebaseUser.uid)
          : null;
}

class _MockUser {
  final String uid;
  const _MockUser(this.uid);
}
