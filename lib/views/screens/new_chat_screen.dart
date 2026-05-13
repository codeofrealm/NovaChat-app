import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../views/widgets/user_avatar.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthViewModel>().firebaseUser?.uid ?? '';
      context.read<HomeViewModel>().loadAllUsers(uid);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Chat', style: AppTextStyles.headlineMedium),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (q) {
                final uid =
                    context.read<AuthViewModel>().firebaseUser?.uid ?? '';
                context.read<HomeViewModel>().searchUsers(q, uid);
              },
            ),
          ),
          Expanded(
            child: Consumer2<HomeViewModel, AuthViewModel>(
              builder: (_, homeVm, authVm, __) {
                final currentUid = authVm.firebaseUser?.uid ?? '';
                final users = _searchController.text.isNotEmpty
                    ? homeVm.searchResults
                    : homeVm.allUsers;

                if (homeVm.isSearching) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (users.isEmpty) {
                  return const Center(
                    child: Text(
                      'No users found',
                      style: AppTextStyles.bodyMedium,
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: users.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 76, endIndent: 16),
                  itemBuilder: (_, i) => _buildUserTile(users[i], currentUid),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserModel user, String currentUid) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: UserAvatar(
        imageUrl: user.profileImage,
        name: user.name,
        radius: 24,
        showOnline: true,
        isOnline: user.isOnline,
      ),
      title: Text(user.name, style: AppTextStyles.titleMedium),
      subtitle: Text(
        user.about,
        style: AppTextStyles.bodyMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () {
        final chatId = AppUtils.getChatId(currentUid, user.uid);
        Navigator.of(context).pushReplacement(
          AppUtils.slideRoute(ChatScreen(otherUser: user, chatId: chatId)),
        );
      },
    );
  }
}
