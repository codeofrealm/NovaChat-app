import 'dart:async';
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
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthViewModel>().uid;
      context.read<HomeViewModel>().loadAllUsers(uid);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q, String uid) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      context.read<HomeViewModel>().searchUsers(q, uid);
    });
  }

  void _openChat(UserModel user, String currentUid) {
    final chatId = [currentUid, user.uid]..sort();
    Navigator.of(context).push(
      AppUtils.slideRoute(
          ChatScreen(otherUser: user, chatId: chatId.join('_'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Select Contact',
            style: AppTextStyles.headlineMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.divider, height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search name or phone...',
          hintStyle:
              const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textHint, size: 20),
          suffixIcon: _isSearching
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _isSearching = false);
                    final uid = context.read<AuthViewModel>().uid;
                    context.read<HomeViewModel>().searchUsers('', uid);
                  },
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.textHint, size: 18),
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (q) {
          setState(() => _isSearching = q.isNotEmpty);
          final uid = context.read<AuthViewModel>().uid;
          _onSearch(q, uid);
        },
      ),
    );
  }

  Widget _buildBody() {
    return Consumer2<HomeViewModel, AuthViewModel>(
      builder: (_, homeVm, authVm, __) {
        final currentUid = authVm.uid;
        final users = _isSearching ? homeVm.searchResults : homeVm.allUsers;

        if (homeVm.isLoading && !_isSearching) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (homeVm.isSearching && _isSearching) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline_rounded,
                    size: 64,
                    color: AppColors.primary.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  _isSearching ? 'No users found' : 'No contacts yet',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSearching
                      ? 'Try a different name or number'
                      : 'Invite friends to join NovaChat',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: users.length,
          padding: const EdgeInsets.only(top: 4, bottom: 80),
          itemBuilder: (_, i) =>
              _buildContactTile(users[i], currentUid),
        );
      },
    );
  }

  Widget _buildContactTile(UserModel user, String currentUid) {
    return InkWell(
      onTap: () => _openChat(user, currentUid),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  imageUrl: user.profileImage,
                  name: user.name,
                  radius: 26,
                ),
                if (user.isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    user.about.isNotEmpty
                        ? user.about
                        : user.phone,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (user.isOnline)
              const Text('online',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.online,
                      fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
