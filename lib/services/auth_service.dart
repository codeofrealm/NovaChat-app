import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Send OTP to phone number (mock)
  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    onCodeSent('mock_verification_id', null);
  }

  // Verify OTP (mock: only '12345' is valid)
  Future<UserCredential?> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    if (otp != '12345') throw Exception('Invalid OTP');
    return null;
  }

  // Sign in with credential (auto-verify)
  Future<UserCredential?> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async => await _auth.signOut();
}
