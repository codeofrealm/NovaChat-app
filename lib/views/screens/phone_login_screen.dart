import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../views/widgets/primary_button.dart';
import 'otp_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  final bool isRegister;
  const PhoneLoginScreen({super.key, required this.isRegister});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+91';
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final vm = context.read<AuthViewModel>();
    final phone = '$_countryCode${_phoneController.text.trim()}';
    await vm.sendOtp(phone);
    if (!mounted) return;
    // Always navigate — sendOtp never fails in test mode
    Navigator.of(context).push(
      AppUtils.slideRoute(OtpScreen(
          phoneNumber: phone, isRegister: widget.isRegister)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildHeader(),
                const SizedBox(height: 40),
                _buildPhoneField(),
                const SizedBox(height: 12),
                const Text(
                  'We\'ll send a verification code to this number.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),
                Consumer<AuthViewModel>(
                  builder: (_, vm, __) => PrimaryButton(
                    label: 'Send OTP',
                    isLoading: vm.state == AuthState.loading,
                    onPressed: _sendOtp,
                  ),
                ),
              ],
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
          child: const Icon(Icons.phone_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 20),
        const Text('Enter your\nphone number', style: AppTextStyles.displayMedium),
        const SizedBox(height: 8),
        Text(
          widget.isRegister
              ? 'Create your NovaChat account'
              : 'Login to your existing account',
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CountryCodePicker(
            onChanged: (code) =>
                setState(() => _countryCode = code.dialCode ?? '+91'),
            initialSelection: 'IN',
            favorite: const ['+91', 'IN'],
            showCountryOnly: false,
            showOnlyCountryWhenClosed: false,
            alignLeft: false,
            textStyle: AppTextStyles.bodyLarge,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          Container(width: 1, height: 28, color: AppColors.divider),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Phone number',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 7) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
          ),
        ],
      ),
    );
  }
}
