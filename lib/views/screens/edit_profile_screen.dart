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

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
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
    final uid = authVm.firebaseUser?.uid;
    if (uid == null) return;

    String? imageUrl;
    if (_imageFile != null) {
      imageUrl = await profileVm.uploadProfileImage(uid, _imageFile!);
    }

    await profileVm.updateProfile(
      uid,
      name: _nameController.text.trim(),
      about: _aboutController.text.trim(),
      profileImage: imageUrl,
    );

    await authVm.loadCurrentUser();
    if (mounted) {
      AppUtils.showSnackBar(context, 'Profile updated!');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile', style: AppTextStyles.headlineMedium),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<AuthViewModel>(
        builder: (_, authVm, __) {
          final user = authVm.currentUser;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildAvatarSection(user),
                const SizedBox(height: 32),
                _buildFields(),
                const SizedBox(height: 32),
                Consumer<ProfileViewModel>(
                  builder: (_, vm, __) => PrimaryButton(
                    label: 'Save Changes',
                    isLoading: vm.isLoading,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarSection(UserModel? user) {
    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: Stack(
          children: [
            _imageFile != null
                ? CircleAvatar(
                    radius: 52,
                    backgroundImage: FileImage(_imageFile!),
                  )
                : UserAvatar(
                    imageUrl: user?.profileImage ?? '',
                    name: user?.name ?? '',
                    radius: 52,
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

  Widget _buildFields() {
    return Column(
      children: [
        TextFormField(
          controller: _nameController,
          style: AppTextStyles.bodyLarge,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name',
            prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textHint),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _aboutController,
          style: AppTextStyles.bodyLarge,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: 'About',
            prefixIcon: Icon(Icons.info_outline_rounded, color: AppColors.textHint),
          ),
        ),
      ],
    );
  }
}
