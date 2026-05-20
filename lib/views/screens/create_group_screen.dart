import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/group_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../views/widgets/user_avatar.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _groupService = GroupService();
  final Set<String> _selectedUids = {};
  List<UserModel> _allUsers = [];
  bool _isLoading = false;
  bool _isCreating = false;
  int _step = 0; // 0 = select members, 1 = group details

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final uid = context.read<AuthViewModel>().uid;
    _allUsers = await context.read<HomeViewModel>().loadAllUsersReturn(uid);
    setState(() => _isLoading = false);
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isCreating = true);
    try {
      final uid = context.read<AuthViewModel>().uid;
      final group = await _groupService.createGroup(
        name: _nameController.text.trim(),
        description: _descController.text.trim(),
        createdBy: uid,
        members: _selectedUids.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        AppUtils.slideRoute(GroupChatScreen(group: group)),
        (r) => r.isFirst,
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: _step == 0 ? () => Navigator.pop(context) : () => setState(() => _step = 0),
        ),
        title: Text(
          _step == 0 ? 'Add Members' : 'Group Details',
          style: AppTextStyles.headlineMedium,
        ),
        actions: [
          if (_step == 0 && _selectedUids.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Next', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          if (_step == 1)
            TextButton(
              onPressed: _isCreating ? null : _createGroup,
              child: _isCreating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Create', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _step == 0 ? _buildMemberSelection() : _buildGroupDetails(),
      bottomNavigationBar: SizedBox(height: MediaQuery.of(context).padding.bottom),
    );
  }

  Widget _buildMemberSelection() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Column(
      children: [
        if (_selectedUids.isNotEmpty)
          Container(
            height: 72,
            color: AppColors.background,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: _allUsers
                  .where((u) => _selectedUids.contains(u.uid))
                  .map((u) => Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                UserAvatar(imageUrl: u.profileImage, name: u.name, radius: 20),
                                Positioned(
                                  right: -2,
                                  top: -2,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedUids.remove(u.uid)),
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 10, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(u.name.split(' ').first,
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _allUsers.length,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
            itemBuilder: (_, i) {
              final user = _allUsers[i];
              final selected = _selectedUids.contains(user.uid);
              return ListTile(
                leading: UserAvatar(imageUrl: user.profileImage, name: user.name, radius: 22),
                title: Text(user.name, style: AppTextStyles.titleMedium),
                subtitle: Text(user.about.isNotEmpty ? user.about : user.phone,
                    style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                onTap: () => setState(() {
                  if (selected) _selectedUids.remove(user.uid);
                  else _selectedUids.add(user.uid);
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupDetails() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        children: [
          // Group icon placeholder
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: const Icon(Icons.group_rounded, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _nameController,
            style: AppTextStyles.bodyLarge,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Group name',
              prefixIcon: const Icon(Icons.group_outlined, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            style: AppTextStyles.bodyLarge,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Group description (optional)',
              prefixIcon: const Icon(Icons.info_outline_rounded, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.people_outline_rounded, color: AppColors.primary),
                const SizedBox(width: 10),
                Text('${_selectedUids.length} members selected',
                    style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
