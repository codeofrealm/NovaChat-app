import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../views/widgets/primary_button.dart';
import 'profile_setup_screen.dart';

class EmailEntryScreen extends StatefulWidget {
  const EmailEntryScreen({super.key});

  @override
  State<EmailEntryScreen> createState() => _EmailEntryScreenState();
}

class _EmailEntryScreenState extends State<EmailEntryScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final vm = context.read<AuthViewModel>();
    await vm.saveEmail(email);
    if (!mounted) return;
    Navigator.of(context).push(
      AppUtils.slideRoute(
        ProfileSetupScreen(email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildEmailField(),
                    const SizedBox(height: 12),
                    if (_inlineError != null) _buildInlineError(),
                    const SizedBox(height: 12),
                    const Text(
                      'Your email is used for account recovery and notifications.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    PrimaryButton(label: 'Continue', onPressed: _continue),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
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
          child: const Icon(Icons.email_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 20),
        const Text('Your email\naddress', style: AppTextStyles.displayMedium),
        const SizedBox(height: 8),
        const Text(
          'We\'ll keep your account safe',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.done,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: 'Enter your email',
        prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Email is required';
        if (!AppUtils.isValidEmail(v.trim())) return 'Enter a valid email';
        return null;
      },
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
}