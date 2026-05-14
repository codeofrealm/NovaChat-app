import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../views/widgets/chat_list_tile.dart';
import '../../views/widgets/shimmer_widgets.dart';
import '../../views/widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'new_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final authVm = context.read<AuthViewModel>();
    await authVm.loadCurrentUser();
    if (!mounted) return;
    final uid = authVm.firebaseUser?.uid;
    if (uid == null) return;
    final homeVm = context.read<HomeViewModel>();
    homeVm.setOnline(uid);
    homeVm.listenToChats(uid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildAppBar()],
        body: Column(
          children: [
            _buildSearchBar(),
            Expanded(child: _buildChatList()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          const Text('NovaChat', style: AppTextStyles.headlineLarge),
        ],
      ),
      actions: [
        Consumer<AuthViewModel>(
          builder: (_, vm, __) => GestureDetector(
            onTap: () => Navigator.of(context).push(
              AppUtils.slideRoute(const EditProfileScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: UserAvatar(
                imageUrl: vm.currentUser?.profileImage ?? '',
                name: vm.currentUser?.name ?? '',
                radius: 18,
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (v) async {
            if (v == 'logout') {
              await context.read<AuthViewModel>().signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
              }
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                  SizedBox(width: 10),
                  Text('Logout'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search chats...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
          suffixIcon: _isSearching
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _isSearching = false);
                    context.read<HomeViewModel>().searchUsers('', '');
                  },
                  child: const Icon(Icons.close, color: AppColors.textHint),
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (q) {
          setState(() => _isSearching = q.isNotEmpty);
          final uid = context.read<AuthViewModel>().firebaseUser?.uid ?? '';
          context.read<HomeViewModel>().searchUsers(q, uid);
        },
      ),
    );
  }

  Widget _buildChatList() {
    return Consumer2<HomeViewModel, AuthViewModel>(
      builder: (_, homeVm, authVm, __) {
        final currentUid = authVm.firebaseUser?.uid ?? '';

        if (_isSearching) {
          return _buildSearchResults(homeVm, currentUid);
        }

        if (homeVm.isLoading) return const ChatListShimmer();

        if (homeVm.chats.isEmpty) return _buildEmptyState();

        return ListView.separated(
          itemCount: homeVm.chats.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 76, endIndent: 16),
          itemBuilder: (_, i) {
            final chat = homeVm.chats[i];
            final participants = List<String>.from(
              (chat['participants'] as Map?)?.keys ?? [],
            );
            final otherUid =
                participants.firstWhere((p) => p != currentUid, orElse: () => '');
            if (otherUid.isEmpty) return const SizedBox.shrink();

            return StreamBuilder<UserModel?>(
              stream: homeVm.userStream(otherUid),
              builder: (_, snap) {
                final user = snap.data;
                if (user == null) return const SizedBox.shrink();
                return StreamBuilder<int>(
                  stream: homeVm.unreadCountStream(chat['id'], currentUid),
                  builder: (_, unreadSnap) {
                    return ChatListTile(
                      user: user,
                      lastMessage: chat['lastMessage'] ?? '',
                      lastMessageTime: chat['lastMessageTime'] ?? 0,
                      unreadCount: unreadSnap.data ?? 0,
                      onTap: () => _openChat(user, currentUid),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(HomeViewModel vm, String currentUid) {
    if (vm.isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (vm.searchResults.isEmpty) {
      return const Center(
        child: Text('No users found', style: AppTextStyles.bodyMedium),
      );
    }
    return ListView.separated(
      itemCount: vm.searchResults.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 76, endIndent: 16),
      itemBuilder: (_, i) {
        final user = vm.searchResults[i];
        return ChatListTile(
          user: user,
          lastMessage: '',
          lastMessageTime: 0,
          unreadCount: 0,
          onTap: () => _openChat(user, currentUid),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text('No chats yet', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'Start a new conversation!',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () => Navigator.of(context).push(
        AppUtils.slideRoute(const NewChatScreen()),
      ),
      backgroundColor: AppColors.primary,
      elevation: 4,
      child: const Icon(Icons.edit_rounded, color: Colors.white),
    );
  }

  void _openChat(UserModel user, String currentUid) {
    final chatId = AppUtils.getChatId(currentUid, user.uid);
    Navigator.of(context).push(
      AppUtils.slideRoute(
        ChatScreen(otherUser: user, chatId: chatId),
      ),
    );
  }
}
