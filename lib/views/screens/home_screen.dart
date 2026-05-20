import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../models/group_model.dart';
import '../../models/story_model.dart';
import '../../models/user_model.dart';
import '../../services/group_service.dart';
import '../../services/story_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../views/widgets/shimmer_widgets.dart';
import '../../views/widgets/user_avatar.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'edit_profile_screen.dart';
import 'group_chat_screen.dart';
import 'new_chat_screen.dart';
import 'splash_screen.dart';
import 'story_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  late RefreshController _refreshController;
  late TabController _tabController;
  final _storyService = StoryService();
  final _groupService = GroupService();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    _tabController.dispose();
    super.dispose();
  }

  void _openChat(UserModel user, String currentUid) {
    final chatId = [currentUid, user.uid]..sort();
    Navigator.of(context).push(AppUtils.slideRoute(
      ChatScreen(otherUser: user, chatId: chatId.join('_')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Stories row
          _buildStoriesRow(),
          // Tab bar
          Container(
            color: AppColors.background,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.divider.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Chats'),
                  Tab(text: 'Groups'),
                  Tab(text: 'Calls'),
                ],
              ),
            ),
          ),
          // Search bar
          _buildSearchBar(),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatsTab(),
                _buildGroupsTab(),
                _buildCallsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      titleSpacing: 16,
      title: const Text('NovaChat',
          style: TextStyle(
              color: AppColors.primary,
              fontSize: 22,
              letterSpacing: -0.5,
              fontWeight: FontWeight.w800)),
      actions: [
        Consumer<AuthViewModel>(
          builder: (_, vm, __) => GestureDetector(
            onTap: () => Navigator.of(context)
                .push(AppUtils.slideRoute(const EditProfileScreen())),
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white54, width: 1.5),
              ),
              child: ClipOval(
                child: vm.currentUser?.profileImage.isNotEmpty == true
                    ? (vm.currentUser!.profileImage.startsWith('/')
                        ? Image.file(
                            File(vm.currentUser!.profileImage),
                            fit: BoxFit.cover)
                        : CachedNetworkImage(
                            imageUrl: vm.currentUser!.profileImage,
                            fit: BoxFit.cover))
                    : const Icon(Icons.person, color: AppColors.primary, size: 18),
              ),
            ),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
          onSelected: (v) {
            if (v == 'new_group') {
              Navigator.of(context)
                  .push(AppUtils.slideRoute(const CreateGroupScreen()));
            } else if (v == 'logout') {
              _logout();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'new_group', child: Text('New Group')),
            const PopupMenuItem(value: 'logout', child: Text('Logout')),
          ],
        ),
      ],
    );
  }

  // ─── Stories Row ────────────────────────────────────────────────────────────
  Widget _buildStoriesRow() {
    final uid = context.read<AuthViewModel>().uid;
    return Container(
      height: 104,
      color: AppColors.background,
      child: StreamBuilder<Map<String, List<StoryModel>>>(
        stream: _storyService.storiesStream(),
        builder: (_, snap) {
          final storiesMap = snap.data ?? {};
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            children: [
              // Add story button
              _storyItem(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppColors.primary, size: 28),
                ),
                label: 'My Story',
                onTap: () {},
                hasStory: false,
              ),
              // Other users' stories
              ...storiesMap.entries.where((e) => e.key != uid).map((e) {
                final stories = e.value;
                final first = stories.first;
                return _storyItem(
                  child: UserAvatar(
                    imageUrl: first.userImage,
                    name: first.userName,
                    radius: 28,
                    showBorder: false,
                  ),
                  label: first.userName.split(' ').first,
                  hasStory: true,
                  onTap: () => Navigator.of(context).push(
                    AppUtils.slideRoute(StoryViewerScreen(
                      userId: e.key,
                      stories: stories,
                      currentUid: uid,
                    )),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _storyItem({
    required Widget child,
    required String label,
    required VoidCallback onTap,
    required bool hasStory,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasStory
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                border: hasStory
                    ? null
                    : Border.all(color: AppColors.divider, width: 1.5),
              ),
              padding: EdgeInsets.all(hasStory ? 2.5 : 0),
              child: ClipOval(child: child),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textHint, size: 20),
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
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.divider.withOpacity(0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppColors.divider.withOpacity(0.5)),
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

  // ─── Chats Tab ──────────────────────────────────────────────────────────────
  Widget _buildChatsTab() {
    return Consumer2<HomeViewModel, AuthViewModel>(
      builder: (_, homeVm, authVm, __) {
        final currentUid = authVm.uid;
        if (_isSearching) return _buildSearchResults(homeVm, currentUid);
        if (homeVm.isLoading) return const ChatListShimmer();
        if (homeVm.chats.isEmpty) return _buildEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'No conversations yet',
          subtitle: 'Tap + to start a new chat',
        );

        return SmartRefresher(
          controller: _refreshController,
          enablePullDown: true,
          header: WaterDropHeader(
            complete: Icon(Icons.check_circle, color: AppColors.success),
          ),
          onRefresh: _onRefresh,
          child: ListView.builder(
            itemCount: homeVm.chats.length,
            padding: EdgeInsets.zero,
            itemBuilder: (_, i) {
              final chat = homeVm.chats[i];
              final participants = List<String>.from(
                  (chat['participants'] as Map?)?.keys ?? []);
              final otherUid = participants
                  .firstWhere((p) => p != currentUid, orElse: () => '');
              if (otherUid.isEmpty) return const SizedBox.shrink();
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 300 + (i * 100).clamp(0, 500)),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(
                      opacity: value,
                      child: child,
                    ),
                  );
                },
                child: _ChatTile(
                  key: ValueKey(chat['id']),
                  userStream: homeVm.userStream(otherUid),
                  chatData: chat,
                  unreadStream:
                      homeVm.unreadCountStream(chat['id'], currentUid),
                  onTap: (user) => _openChat(user, currentUid),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ─── Groups Tab ─────────────────────────────────────────────────────────────
  Widget _buildGroupsTab() {
    final uid = context.read<AuthViewModel>().uid;
    return StreamBuilder<List<GroupModel>>(
      stream: _groupService.groupsStream(uid),
      builder: (_, snap) {
        final groups = snap.data ?? [];
        if (groups.isEmpty) {
          return _buildEmptyState(
            icon: Icons.group_outlined,
            title: 'No groups yet',
            subtitle: 'Tap + to create a group',
          );
        }
        return ListView.builder(
          itemCount: groups.length,
          padding: EdgeInsets.zero,
          itemBuilder: (_, i) => TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (i * 100).clamp(0, 500)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: _GroupTile(
              group: groups[i],
              onTap: () => Navigator.of(context).push(
                AppUtils.slideRoute(GroupChatScreen(group: groups[i])),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Calls Tab ──────────────────────────────────────────────────────────────
  Widget _buildCallsTab() {
    // Recent calls list (UI only)
    return _buildEmptyState(
      icon: Icons.call_outlined,
      title: 'No recent calls',
      subtitle: 'Tap a contact to start a call',
    );
  }

  Widget _buildSearchResults(HomeViewModel vm, String currentUid) {
    if (vm.isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (vm.searchResults.isEmpty) {
      return const Center(
        child: Text('No results found',
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

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.primary.withOpacity(0.25)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (_, __) {
        final tab = _tabController.index;
        return FloatingActionButton(
          heroTag: 'homeFAB',
          backgroundColor: AppColors.primary,
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: () {
            if (tab == 0) {
              Navigator.of(context)
                  .push(AppUtils.slideRoute(const NewChatScreen()));
            } else if (tab == 1) {
              Navigator.of(context)
                  .push(AppUtils.slideRoute(const CreateGroupScreen()));
            } else {
              Navigator.of(context)
                  .push(AppUtils.slideRoute(const NewChatScreen()));
            }
          },
          child: Icon(
            tab == 1 ? Icons.group_add_rounded : Icons.chat_rounded,
            color: Colors.white,
            size: 22,
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final authVm = context.read<AuthViewModel>();
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
  }

  Future<void> _onRefresh() async {
    final authVm = context.read<AuthViewModel>();
    final homeVm = context.read<HomeViewModel>();
    await authVm.loadCurrentUser();
    homeVm.listenToChats(authVm.uid);
    _refreshController.refreshCompleted();
  }
}

// ─── Group Tile ───────────────────────────────────────────────────────────────
class _GroupTile extends StatelessWidget {
  final GroupModel group;
  final VoidCallback onTap;

  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.group_rounded,
                    color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(group.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (group.lastMessageTime > 0)
                          Text(
                            AppUtils.formatChatTime(group.lastMessageTime),
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textHint),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.lastMessage.isNotEmpty
                          ? group.lastMessage
                          : '${group.members.length} members',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chat Tile ────────────────────────────────────────────────────────────────
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

    return StreamBuilder<int>(
      stream: unreadStream ?? const Stream<int>.empty(),
      builder: (_, snap) {
        final unread = snap.data ?? 0;
        return InkWell(
          onTap: () => onTap(u),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Stack(
                children: [
                  UserAvatar(imageUrl: u.profileImage, name: u.name, radius: 26),
                  if (u.isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.online,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(u.name,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (lastTime > 0)
                          Text(
                            AppUtils.formatChatTime(lastTime),
                            style: TextStyle(
                              fontSize: 11,
                              color: unread > 0
                                  ? AppColors.primary
                                  : AppColors.textHint,
                              fontWeight: unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(lastMsg,
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (unread > 0)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.5, end: 1.0),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            builder: (_, v, child) =>
                                Transform.scale(scale: v, child: child),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                unread > 99 ? '99+' : '$unread',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
        );
      },
    );
  }
}
