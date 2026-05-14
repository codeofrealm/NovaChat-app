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

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text('Choose Photo', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
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
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authVm = context.read<AuthViewModel>();
      final profileVm = context.read<ProfileViewModel>();
      final uid = authVm.firebaseUser?.uid ?? 'mock_uid';
      final phone = authVm.firebaseUser?.phoneNumber ?? '';

      String imageUrl = '';
      // Only upload image if a real Firebase user is signed in
      if (_imageFile != null && authVm.firebaseUser != null) {
        imageUrl = await profileVm.uploadProfileImage(uid, _imageFile!);
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
        AppUtils.showSnackBar(context, 'Failed to save profile', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                _buildAvatarPicker(),
                const SizedBox(height: 32),
                _buildNameField(),
                const SizedBox(height: 40),
                PrimaryButton(
                  label: 'Create Profile',
                  isLoading: _isLoading,
                  onPressed: _saveProfile,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
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
        onTap: _showImagePicker,
        child: Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primarySoft,
                border: Border.all(color: AppColors.primary, width: 2),
                image: _imageFile != null
                    ? DecorationImage(
                        image: FileImage(_imageFile!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imageFile == null
                  ? const Icon(
                      Icons.person_rounded,
                      size: 52,
                      color: AppColors.primary,
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
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
      decoration: const InputDecoration(
        hintText: 'Your full name',
        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textHint),
      ),
      validator: (v) {
        if (v == null || v.trim().length < 2) return 'Enter your name';
        return null;
      },
    );
  }
}
