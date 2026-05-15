import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/contacts_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../views/widgets/user_avatar.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  final _contactsService = ContactsService();

  List<UserModel> _onApp = [];
  List<UserModel> _others = [];
  List<UserModel> _filtered = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadContacts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    final uid = context.read<AuthViewModel>().uid;
    final result = await _contactsService.getContacts(uid);
    if (!mounted) return;
    setState(() {
      _onApp = result.onApp;
      _others = result.others;
      _isLoading = false;
    });
  }

  void _onSearch(String q) {
    setState(() {
      _query = q;
      _isSearching = q.isNotEmpty;
      if (q.isEmpty) {
        _filtered = [];
      } else {
        final all = [..._onApp, ..._others];
        _filtered = all
            .where((u) =>
                u.name.toLowerCase().contains(q.toLowerCase()) ||
                u.phone.contains(q))
            .toList();
      }
    });
  }

  void _openChat(UserModel user) {
    final currentUid = context.read<AuthViewModel>().uid;
    final chatId = [currentUid, user.uid]..sort();
    Navigator.of(context).push(
      AppUtils.slideRoute(ChatScreen(otherUser: user, chatId: chatId.join('_'))),
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Select Contact', style: AppTextStyles.headlineMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.divider, height: 1),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _isSearching
                    ? _buildList(_filtered, showSectionHeader: false)
                    : _buildSectioned(),
          ),
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
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
          suffixIcon: _isSearching
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                  child: const Icon(Icons.close_rounded, color: AppColors.textHint, size: 18),
                )
              : null,
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: _onSearch,
      ),
    );
  }

  Widget _buildSectioned() {
    if (_onApp.isEmpty && _others.isEmpty) {
      return _buildEmpty('No contacts found', 'Invite friends to join NovaChat');
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        if (_onApp.isNotEmpty) ...[
          _sectionHeader('Contacts on NovaChat', _onApp.length),
          ..._onApp.map((u) => _contactTile(u)),
        ],
        if (_others.isNotEmpty) ...[
          _sectionHeader('Other Users', _others.length),
          ..._others.map((u) => _contactTile(u)),
        ],
      ],
    );
  }

  Widget _buildList(List<UserModel> users, {bool showSectionHeader = true}) {
    if (users.isEmpty) {
      return _buildEmpty('No results', 'Try a different name or number');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: users.length,
      itemBuilder: (_, i) => _contactTile(users[i]),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactTile(UserModel user) {
    return InkWell(
      onTap: () => _openChat(user),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(imageUrl: user.profileImage, name: user.name, radius: 26),
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
                        border: Border.all(color: Colors.white, width: 2),
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
                  Text(
                    user.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user.about.isNotEmpty ? user.about : user.phone,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (user.isOnline)
              const Text(
                'online',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.online,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline_rounded,
              size: 64, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
