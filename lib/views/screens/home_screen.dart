import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../views/widgets/shimmer_widgets.dart';
import '../../views/widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'edit_profile_screen.dart';
import 'new_chat_screen.dart';
import 'splash_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  late RefreshController _refreshController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refreshController = RefreshController(initialRefresh: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final authVm = context.read<AuthViewModel>();
    await authVm.loadCurrentUser();
    if (!mounted) return;
    final uid = authVm.uid;
    if (uid.isEmpty) return;
    final homeVm = context.read<HomeViewModel>();
    homeVm.setOnline(uid, authVm.currentUser?.name ?? '');
    homeVm.listenToChats(uid);
    homeVm.requestNotificationPermission(uid);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  void _openChat(UserModel user, String currentUid) {
    final chatId = [currentUid, user.uid]..sort();
    Navigator.of(context).push(
      AppUtils.slideRoute(ChatScreen(
        otherUser: user,
        chatId: chatId.join('_'),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      endDrawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: SmartRefresher(
              controller: _refreshController,
              enablePullDown: true,
              header: WaterDropHeader(
                complete: Icon(Icons.check_circle, color: AppColors.success),
              ),
              onRefresh: _onRefresh,
              child: _buildChatList(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'newChatFAB',
        onPressed: () => Navigator.of(context)
            .push(AppUtils.slideRoute(const NewChatScreen())),
        backgroundColor: AppColors.primary,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.chat_rounded, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chat_bubble_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('NovaChat', style: AppTextStyles.headlineLarge),
        ],
      ),
      actions: [
        Consumer<HomeViewModel>(
          builder: (_, vm, __) {
            final count = vm.totalUnread;
            return count > 0
                ? Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                    ),
                  )
                : const SizedBox.shrink();
          },
        ),
        Consumer<AuthViewModel>(
          builder: (_, vm, __) => GestureDetector(
            onTap: () => Navigator.of(context)
                .push(AppUtils.slideRoute(const EditProfileScreen())),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: ClipOval(
                child: vm.currentUser?.profileImage.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: vm.currentUser!.profileImage,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Icon(Icons.person,
                            color: AppColors.primary, size: 18),
                      )
                    : const Icon(Icons.person,
                        color: AppColors.primary, size: 18),
              ),
            ),
          ),
        ),
        Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: AppColors.divider, height: 1),
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
          hintText: 'Search chats...',
          hintStyle:
              const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
          suffixIcon: _isSearching
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _isSearching = false);
                    context.read<HomeViewModel>().searchUsers('', '');
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
          context.read<HomeViewModel>().searchUsers(q, uid);
        },
      ),
    );
  }

  Widget _buildChatList() {
    return Consumer2<HomeViewModel, AuthViewModel>(
      builder: (_, homeVm, authVm, __) {
        final currentUid = authVm.uid;

        if (_isSearching) return _buildSearchResults(homeVm, currentUid);
        if (homeVm.isLoading) return const ChatListShimmer();
        if (homeVm.chats.isEmpty) return _buildEmptyState();

        return ListView.builder(
          itemCount: homeVm.chats.length,
          padding: EdgeInsets.zero,
          itemBuilder: (_, i) {
            final chat = homeVm.chats[i];
            final participants =
                List<String>.from((chat['participants'] as Map?)?.keys ?? []);
            final otherUid = participants
                .firstWhere((p) => p != currentUid, orElse: () => '');
            if (otherUid.isEmpty) return const SizedBox.shrink();

            return _ChatTile(
              key: ValueKey(chat['id']),
              userStream: homeVm.userStream(otherUid),
              chatData: chat,
              unreadStream: homeVm.unreadCountStream(chat['id'], currentUid),
              onTap: (user) => _openChat(user, currentUid),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchResults(HomeViewModel vm, String currentUid) {
    if (vm.isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (vm.searchResults.isEmpty) {
      return const Center(
        child: Text('No chats found',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    return ListView.builder(
      itemCount: vm.searchResults.length,
      padding: EdgeInsets.zero,
      itemBuilder: (_, i) {
        final user = vm.searchResults[i];
        return _ChatTile(
          key: ValueKey(user.uid),
          user: user,
          onTap: (u) => _openChat(u, currentUid),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 72, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No conversations yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Tap the chat button to start a new conversation',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      width: 280,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: Consumer<AuthViewModel>(
        builder: (_, authVm, __) {
          final user = authVm.currentUser;
          return SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 2.5),
                  ),
                  child: ClipOval(
                    child: user?.profileImage.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: user!.profileImage,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: AppColors.primarySoft,
                            child: const Icon(Icons.person,
                                color: AppColors.primary, size: 40),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?.name ?? '',
                    style: AppTextStyles.titleLarge),
                const SizedBox(height: 2),
                Text(user?.phone ?? '',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(user?.email ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textHint)),
                const SizedBox(height: 20),
                const Divider(),
                _drawerItem(Icons.edit_outlined, 'Edit Profile', () {
                  Navigator.pop(context);
                  Navigator.of(context)
                      .push(AppUtils.slideRoute(const EditProfileScreen()));
                }),
                _drawerItem(Icons.chat_bubble_outline_rounded, 'New Chat',
                    () {
                  Navigator.pop(context);
                  Navigator.of(context)
                      .push(AppUtils.slideRoute(const NewChatScreen()));
                }),
                const Divider(),
                _drawerItem(Icons.logout_rounded, 'Logout', () async {
                  Navigator.pop(context);
                  if (authVm.uid.isNotEmpty) {
                    context.read<HomeViewModel>().setOffline(authVm.uid);
                  }
                  await authVm.signOut();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      AppUtils.fadeRoute(const SplashScreen()),
                      (_) => false,
                    );
                  }
                }, color: AppColors.error),
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text('NovaChat v1.0',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap,
      {Color color = AppColors.textPrimary}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: color)),
      onTap: onTap,
      horizontalTitleGap: 8,
    );
  }

  Future<void> _onRefresh() async {
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    await authVm.loadCurrentUser();
    homeVm.listenToChats(authVm.uid);
    _refreshController.refreshCompleted();
  }
}

// ─── WhatsApp-style Chat Tile ─────────────────────────────────────────────────
class _ChatTile extends StatelessWidget {
  final UserModel? user;
  final Stream<UserModel?>? userStream;
  final Map<String, dynamic>? chatData;
  final Stream<int>? unreadStream;
  final ValueChanged<UserModel> onTap;

  const _ChatTile({
    super.key,
    this.user,
    this.userStream,
    this.chatData,
    this.unreadStream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (user != null) return _tile(context, user!);
    return StreamBuilder<UserModel?>(
      stream: userStream,
      builder: (_, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        return _tile(context, snap.data!);
      },
    );
  }

  Widget _tile(BuildContext context, UserModel u) {
    final lastMsg = chatData?['lastMessage'] as String? ?? u.about;
    final lastTime = chatData?['lastMessageTime'] as int? ?? 0;

    return InkWell(
      onTap: () => onTap(u),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  imageUrl: u.profileImage,
                  name: u.name,
                  radius: 26,
                ),
                if (u.isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.online,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(u.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (lastTime > 0)
                        StreamBuilder<int>(
                          stream: unreadStream ??
                              const Stream<int>.empty(),
                          builder: (_, snap) {
                            final unread = snap.data ?? 0;
                            return Text(
                              AppUtils.formatChatTime(lastTime),
                              style: TextStyle(
                                fontSize: 11,
                                color: unread > 0
                                    ? AppColors.primary
                                    : AppColors.textHint,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StreamBuilder<int>(
                        stream:
                            unreadStream ?? const Stream<int>.empty(),
                        builder: (_, snap) {
                          final count = snap.data ?? 0;
                          if (count == 0) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              count > 99 ? '99+' : '$count',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
