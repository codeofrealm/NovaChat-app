import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../views/widgets/primary_button.dart';
import 'success_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String email;
  const ProfileSetupScreen({super.key, required this.email});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 512,
      );
      if (picked != null) {
        setState(() {
          _imageFile = File(picked.path);
          _errorMessage = null;
        });
      }
    } catch (_) {}
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 16, bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Choose Photo', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _imageSourceOption(
                  Icons.camera_alt_rounded,
                  'Camera',
                  () => _pickImage(ImageSource.camera),
                ),
                _imageSourceOption(
                  Icons.photo_library_rounded,
                  'Gallery',
                  () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final authVm = context.read<AuthViewModel>();
    if (authVm.uid.isEmpty) {
      setState(() => _errorMessage = 'Session expired. Please go back and login again.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final profileVm = context.read<ProfileViewModel>();
      final userUid = authVm.uid;
      final phone = authVm.firebaseUser?.phoneNumber ?? '';

      String imageUrl = '';
      if (_imageFile != null && authVm.firebaseUser != null) {
        imageUrl = await profileVm.uploadProfileImage(userUid, _imageFile!);
      } else if (_imageFile != null) {
        imageUrl = _imageFile!.path;
      }

      await authVm.saveProfile(
        name: _nameController.text.trim(),
        phone: phone,
        email: widget.email,
        profileImageUrl: imageUrl,
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppUtils.fadeRoute(const SuccessScreen()),
        (_) => false,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = _parseError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('permission-denied') || msg.contains('permission denied')) {
      return 'Permission denied. Check Firebase Storage & Firestore rules.';
    }
    if (msg.contains('network') || msg.contains('unavailable')) {
      return 'No internet connection. Please check your network and try again.';
    }
    if (msg.contains('unauthenticated') || msg.contains('not authenticated')) {
      return 'Session expired. Please go back and login again.';
    }
    if (msg.contains('storage')) {
      return 'Image upload failed. You can skip the photo and add it later.';
    }
    if (msg.contains('firestore') || msg.contains('cloud_firestore')) {
      return 'Failed to save profile. Please try again.';
    }
    final raw = e.toString().replaceAll('Exception: ', '');
    return raw.length < 120 ? raw : 'Failed to save profile. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: _isLoading
            ? const SizedBox.shrink()
            : IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      size: 18, color: AppColors.textPrimary),
                ),
                onPressed: () => Navigator.pop(context),
              ),
      ),
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
                    const SizedBox(height: 32),
                    _buildAvatarPicker(),
                    const SizedBox(height: 32),
                    _buildNameField(),
                    const SizedBox(height: 16),
                    if (_errorMessage != null) ...[
                      _buildErrorCard(),
                      const SizedBox(height: 16),
                    ],
                    const SizedBox(height: 32),
                    PrimaryButton(
                      label: 'Create Profile',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _saveProfile,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.error,
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close_rounded,
                color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set up your\nprofile', style: AppTextStyles.displayMedium),
        SizedBox(height: 8),
        Text(
          'Add a photo and your name to get started',
          style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: GestureDetector(
        onTap: _isLoading ? null : _showImagePicker,
        child: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
                border: Border.all(
                  color: _imageFile != null
                      ? AppColors.success
                      : AppColors.primary,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                image: _imageFile != null
                    ? DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageFile == null
                  ? const Icon(Icons.person_outline_rounded,
                      size: 50, color: AppColors.primary)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _imageFile != null
                        ? [AppColors.success, const Color(0xFF34D399)]
                        : [AppColors.primary, AppColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: Icon(
                  _imageFile != null
                      ? Icons.check_rounded
                      : Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      style: AppTextStyles.bodyLarge,
      enabled: !_isLoading,
      decoration: InputDecoration(
        hintText: 'Your full name',
        prefixIcon:
            const Icon(Icons.person_outline_rounded, color: AppColors.textHint),
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
      ),
      validator: (v) {
        if (v == null || v.trim().length < 2) {
          return 'Please enter at least 2 characters';
        }
        return null;
      },
    );
  }
}