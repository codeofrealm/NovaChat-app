import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../views/widgets/primary_button.dart';
import 'email_entry_screen.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  int _secondsLeft = 60;
  Timer? _timer;
  late AnimationController _successController;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify() async {
    if (_otpController.text.length < 5) return;
    final vm = context.read<AuthViewModel>();
    await vm.verifyOtp(_otpController.text);
    if (!mounted) return;
    if (vm.state == AuthState.verified) {
      setState(() => _showSuccess = true);
      _successController.forward();
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppUtils.fadeRoute(
          vm.isNewUser ? const EmailEntryScreen() : const HomeScreen(),
        ),
        (_) => false,
      );
    } else if (vm.state == AuthState.error) {
      AppUtils.showSnackBar(context, vm.errorMessage, isError: true);
      vm.clearError();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _successController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(),
              const SizedBox(height: 40),
              _buildOtpField(),
              const SizedBox(height: 24),
              _buildResendRow(),
              const SizedBox(height: 32),
              if (_showSuccess) _buildSuccessAnimation(),
              Consumer<AuthViewModel>(
                builder: (_, vm, __) => PrimaryButton(
                  label: 'Verify OTP',
                  isLoading: vm.state == AuthState.loading,
                  onPressed: _verify,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 20),
        const Text('Verify OTP', style: AppTextStyles.displayMedium),
        const SizedBox(height: 8),
        Text(
          'Enter the 5-digit code sent to\n${widget.phoneNumber}',
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOtpField() {
    final defaultPinTheme = PinTheme(
      width: 52,
      height: 56,
      textStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
    );

    return Pinput(
      controller: _otpController,
      length: 5,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: defaultPinTheme.copyDecorationWith(
        border: Border.all(color: AppColors.primary, width: 2),
        color: AppColors.primarySoft,
      ),
      submittedPinTheme: defaultPinTheme.copyDecorationWith(
        border: Border.all(color: AppColors.success, width: 1.5),
        color: AppColors.success.withOpacity(0.05),
      ),
      onCompleted: (_) => _verify(),
      autofocus: true,
    );
  }

  Widget _buildResendRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Didn't receive the code? ",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        _secondsLeft > 0
            ? Text(
                'Resend in ${_secondsLeft}s',
                style: const TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              )
            : GestureDetector(
                onTap: () {
                  _startTimer();
                  final phone = widget.phoneNumber;
                  context.read<AuthViewModel>().sendOtp(phone);
                },
                child: const Text(
                  'Resend OTP',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildSuccessAnimation() {
    return Center(
      child: ScaleTransition(
        scale: CurvedAnimation(
          parent: _successController,
          curve: Curves.elasticOut,
        ),
        child: Container(
          width: 72,
          height: 72,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 44,
          ),
        ),
      ),
    );
  }
}
