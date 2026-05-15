import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/profile_viewmodel.dart';
import '../../views/widgets/primary_button.dart';
import '../../views/widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  File? _imageFile;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null) {
      _nameController.text = user.name;
      _aboutController.text = user.about;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _save() async {
    final authVm = context.read<AuthViewModel>();
    final profileVm = context.read<ProfileViewModel>();
    final uid = authVm.uid;
    if (uid.isEmpty) return;

    String? imageUrl;
    if (_imageFile != null && authVm.firebaseUser != null) {
      imageUrl = await profileVm.uploadProfileImage(uid, _imageFile!);
    } else if (_imageFile != null) {
      imageUrl = _imageFile!.path;
    }

    await profileVm.updateProfile(
      uid,
      name: _nameController.text.trim(),
      about: _aboutController.text.trim(),
      profileImage: imageUrl,
    );

    await authVm.loadCurrentUser();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
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
        title: const Text('Edit Profile', style: AppTextStyles.headlineMedium),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 24),
                _buildAvatarSection(),
                const SizedBox(height: 32),
                _buildFields(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            _imageFile != null
                ? CircleAvatar(
                    radius: 56,
                    backgroundImage: FileImage(_imageFile!),
                    backgroundColor: AppColors.primarySoft,
                  )
                : Consumer<AuthViewModel>(
                    builder: (_, authVm, __) => UserAvatar(
                      imageUrl: authVm.currentUser?.profileImage ?? '',
                      name: authVm.currentUser?.name ?? '',
                      radius: 56,
                    ),
                  ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider.withOpacity(0.5)),
          ),
          child: TextFormField(
            controller: _nameController,
            style: AppTextStyles.bodyLarge,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Name',
              prefixIcon:
                  Icon(Icons.person_outline_rounded, color: AppColors.textHint),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider.withOpacity(0.5)),
          ),
          child: TextFormField(
            controller: _aboutController,
            style: AppTextStyles.bodyLarge,
            maxLength: 100,
            decoration: const InputDecoration(
              hintText: 'About',
              prefixIcon:
                  Icon(Icons.info_outline_rounded, color: AppColors.textHint),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}