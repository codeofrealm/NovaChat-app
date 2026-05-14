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
    with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _pinputFocusNode = FocusNode();
  int _secondsLeft = 60;
  Timer? _timer;
  late AnimationController _successController;
  late AnimationController _shakeController;
  bool _showSuccess = false;
  bool _isVerifying = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _verify([String? completedPin]) async {
    final otp = (completedPin ?? _otpController.text).trim();

    if (otp.length < 5) {
      setState(() => _inlineError = 'Please enter the complete 5-digit code.');
      _shakeController.forward(from: 0);
      return;
    }

    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _inlineError = null;
    });

    final vm = context.read<AuthViewModel>();
    await vm.verifyOtp(otp);

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (vm.state == AuthState.verified) {
      setState(() => _showSuccess = true);
      _successController.forward();
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppUtils.fadeRoute(
          vm.isNewUser ? const EmailEntryScreen() : const HomeScreen(),
        ),
        (_) => false,
      );
    } else if (vm.state == AuthState.error) {
      setState(() => _inlineError = vm.errorMessage);
      _otpController.clear();
      _pinputFocusNode.requestFocus();
      _shakeController.forward(from: 0);
      vm.clearError();
    }
  }

  void _resendOtp() {
    setState(() {
      _inlineError = null;
      _otpController.clear();
    });
    _startTimer();
    context.read<AuthViewModel>().sendOtp(widget.phoneNumber);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _pinputFocusNode.dispose();
    _successController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildHeader(),
              const SizedBox(height: 32),
              _buildTestModeBanner(),
              const SizedBox(height: 24),
              _buildOtpField(),
              const SizedBox(height: 12),
              if (_inlineError != null) _buildInlineError(),
              const SizedBox(height: 20),
              _buildResendRow(),
              const SizedBox(height: 40),
              if (_showSuccess) _buildSuccessAnimation(),
              Consumer<AuthViewModel>(
                builder: (_, vm, __) => PrimaryButton(
                  label: 'Verify Code',
                  isLoading:
                      vm.state == AuthState.loading || _isVerifying,
                  onPressed: (vm.state == AuthState.loading || _isVerifying)
                      ? null
                      : () => _verify(),
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
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            children: [
              const TextSpan(text: 'Enter the 5-digit code sent to\n'),
              TextSpan(
                text: widget.phoneNumber,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestModeBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Test mode — enter code: 12345',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpField() {
    final defaultTheme = PinTheme(
      width: 58,
      height: 62,
      textStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 1.5),
      ),
    );

    final errorTheme = defaultTheme.copyDecorationWith(
      border: Border.all(color: AppColors.error, width: 1.5),
      color: AppColors.error.withValues(alpha: 0.04),
    );

    return FadeTransition(
      opacity: _shakeController.drive(
        Tween<double>(begin: 1, end: 0.92)),
      child: Pinput(
        controller: _otpController,
        focusNode: _pinputFocusNode,
        length: 5,
        defaultPinTheme: defaultTheme,
        focusedPinTheme: defaultTheme.copyDecorationWith(
          border: Border.all(color: AppColors.primary, width: 2),
          color: AppColors.primarySoft,
        ),
        submittedPinTheme: _inlineError != null
            ? errorTheme
            : defaultTheme.copyDecorationWith(
                border: Border.all(color: AppColors.success, width: 1.5),
                color: AppColors.success.withValues(alpha: 0.05),
              ),
        errorPinTheme: errorTheme,
        onCompleted: (pin) => _verify(pin),
        autofocus: true,
        onChanged: (_) {
          if (_inlineError != null) setState(() => _inlineError = null);
        },
      ),
    );
  }

  Widget _buildInlineError() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _inlineError!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
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
                onTap: _resendOtp,
                child: const Text(
                  'Resend OTP',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.primary,
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
          width: 80,
          height: 80,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.success, Color(0xFF34D399)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.success.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }
}