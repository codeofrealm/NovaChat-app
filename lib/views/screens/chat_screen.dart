import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../views/widgets/chat_input_bar.dart';
import '../../views/widgets/message_bubble.dart';
import '../../views/widgets/shimmer_widgets.dart';
import '../../views/widgets/user_avatar.dart';
import 'group_chat_screen.dart';
import 'user_detail_screen.dart';
import 'media_gallery_screen.dart';

class ChatScreen extends StatefulWidget {
  final UserModel otherUser;
  final String chatId;

  const ChatScreen({
    super.key,
    required this.otherUser,
    required this.chatId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _dbService = DatabaseService();
  late ChatViewModel _chatVm;
  String _currentUid = '';
  bool _showScrollBtn = false;

  @override
  void initState() {
    super.initState();
    _chatVm = context.read<ChatViewModel>();
    final uid = context.read<AuthViewModel>().uid;
    if (uid.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
      return;
    }
    _currentUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chatVm.listenToMessages(widget.chatId, _currentUid);
    });
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    if (_currentUid.isNotEmpty) {
      _dbService.setTyping(widget.chatId, _currentUid, false);
    }
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentUid.isNotEmpty) {
      _chatVm.markSeen(widget.chatId, _currentUid);
    }
  }

  void _onScroll() {
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent -
                _scrollController.offset >
            200;
    if (atBottom != _showScrollBtn && mounted) {
      setState(() => _showScrollBtn = atBottom);
    }
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;
      if (animated) {
        _scrollController.animateTo(max,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      } else {
        _scrollController.jumpTo(max);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(backgroundColor: AppColors.primary, elevation: 0),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Stack(
                children: [
                  Container(color: AppColors.background),
                  Column(
                    children: [
                      Expanded(child: _buildMessageList()),
                      _buildTypingIndicator(),
                      _buildUploadProgress(),
                    ],
                  ),
                  if (_showScrollBtn)
                    Positioned(
                      bottom: 8,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => _scrollToBottom(),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary, size: 22),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.only(
        top: 4,
        bottom: 8,
        left: 4,
        right: 4,
      ),
      child: StreamBuilder<Map<String, dynamic>>(
        stream: _dbService.presenceStream(widget.otherUser.uid),
        builder: (_, presenceSnap) {
          final presence = presenceSnap.data ?? {};
          final isOnline = presence['isOnline'] as bool? ?? false;
          final lastSeen = presence['lastSeen'] as int? ?? 0;

          return Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  AppUtils.slideRoute(
                      UserDetailScreen(user: widget.otherUser)),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        UserAvatar(
                          imageUrl: widget.otherUser.profileImage,
                          name: widget.otherUser.name,
                          radius: 19,
                          showBorder: false,
                        ),
                        if (isOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.online,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.otherUser.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        StreamBuilder<bool>(
                          stream: _chatVm.typingStream(
                              widget.chatId, widget.otherUser.uid),
                          builder: (_, typingSnap) {
                            final isTyping = typingSnap.data ?? false;
                            return Text(
                              isTyping
                                  ? 'typing...'
                                  : isOnline
                                      ? 'online'
                                      : lastSeen > 0
                                          ? AppUtils.formatLastSeen(lastSeen)
                                          : 'offline',
                              style: TextStyle(
                                color: isTyping
                                    ? Colors.white
                                    : Colors.white70,
                                fontSize: 13,
                                fontWeight: isTyping ? FontWeight.w500 : FontWeight.w400,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.videocam_outlined,
                    color: Colors.white, size: 24),
                onPressed: () => Navigator.of(context).push(
                  AppUtils.slideRoute(CallScreen(
                    name: widget.otherUser.name,
                    imageUrl: widget.otherUser.profileImage,
                    isVideo: true,
                  )),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call_outlined,
                    color: Colors.white, size: 22),
                onPressed: () => Navigator.of(context).push(
                  AppUtils.slideRoute(CallScreen(
                    name: widget.otherUser.name,
                    imageUrl: widget.otherUser.profileImage,
                    isVideo: false,
                  )),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white, size: 22),
                onPressed: () => _showMoreOptions(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading) return const MessageShimmer();
        if (vm.messages.isEmpty) return _buildEmptyChat();

        _scrollToBottom(animated: false);

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          itemCount: vm.messages.length,
          itemBuilder: (_, i) {
            final msg = vm.messages[i];
            final isSent = msg.senderId == _currentUid;
            final showDate = i == 0 ||
                !_isSameDay(vm.messages[i - 1].timestamp, msg.timestamp);

            return Column(
              children: [
                if (showDate) _buildDateDivider(msg.timestamp),
                MessageBubble(
                  key: ValueKey(msg.messageId),
                  message: msg,
                  isSent: isSent,
                  avatarUrl: isSent
                      ? (context
                              .read<AuthViewModel>()
                              .currentUser
                              ?.profileImage ??
                          '')
                      : widget.otherUser.profileImage,
                  avatarName: isSent ? 'You' : widget.otherUser.name,
                  onReact: (emoji) => vm.addReaction(
                    widget.chatId,
                    msg.messageId,
                    _currentUid,
                    emoji,
                  ),
                  onReply: () {},
                  onDelete: () => vm.deleteMessage(widget.chatId, msg.messageId),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateDivider(int timestamp) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(timestamp, now.millisecondsSinceEpoch)) {
      label = 'Today';
    } else if (_isSameDay(
        timestamp,
        now
            .subtract(const Duration(days: 1))
            .millisecondsSinceEpoch)) {
      label = 'Yesterday';
    } else {
      label = AppUtils.formatChatTime(timestamp);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.8),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: ClipOval(
              child: UserAvatar(
                imageUrl: widget.otherUser.profileImage,
                name: widget.otherUser.name,
                radius: 44,
                showBorder: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textHint),
                const SizedBox(width: 6),
                const Text(
                  'Messages are end-to-end encrypted',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Say hi to ${widget.otherUser.name}! 👋',
            style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return StreamBuilder<bool>(
      stream: _chatVm.typingStream(widget.chatId, widget.otherUser.uid),
      builder: (_, snap) {
        final isTyping = snap.data ?? false;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: isTyping
              ? Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      UserAvatar(
                        imageUrl: widget.otherUser.profileImage,
                        name: widget.otherUser.name,
                        radius: 12,
                        showBorder: false,
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                            bottomLeft: Radius.circular(4),
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6),
                          ],
                        ),
                        child: const _TypingDots(),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildUploadProgress() {
    return Consumer<ChatViewModel>(
      builder: (_, vm, __) {
        if (!vm.isSending || vm.uploadProgress == 0) {
          return const SizedBox.shrink();
        }
        return Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.cloud_upload_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: vm.uploadProgress,
                  backgroundColor: AppColors.divider,
                  color: AppColors.primary,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(vm.uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.primary)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInputBar() {
    return ChatInputBar(
      onSendText: (text) {
        _chatVm.sendTextMessage(
          chatId: widget.chatId,
          senderId: _currentUid,
          receiverId: widget.otherUser.uid,
          text: text,
        );
        _scrollToBottom();
      },
      onSendImage: (File file, String caption) {
        _chatVm.sendImageMessage(
          chatId: widget.chatId,
          senderId: _currentUid,
          receiverId: widget.otherUser.uid,
          imageFile: file,
          text: caption,
        );
      },
      onSendVoice: (File file) {
        _chatVm.sendVoiceMessage(
          chatId: widget.chatId,
          senderId: _currentUid,
          receiverId: widget.otherUser.uid,
          voiceFile: file,
        );
      },
      onTypingChanged: (isTyping) {
        _chatVm.setTyping(widget.chatId, _currentUid, isTyping);
      },
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded,
                    color: AppColors.primary),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(AppUtils.slideRoute(
                      UserDetailScreen(user: widget.otherUser)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.search_rounded,
                    color: AppColors.primary),
                title: const Text('Search Messages'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('View Shared Media'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(AppUtils.slideRoute(
                      MediaGalleryScreen(
                          title: widget.otherUser.name,
                          messages: _chatVm.messages)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined,
                    color: AppColors.textSecondary),
                title: const Text('Mute Notifications'),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  bool _isSameDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.year == d2.year &&
        d1.month == d2.month &&
        d1.day == d2.day;
  }
}

// ─── Animated Typing Dots ────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final t = (_controller.value - i * 0.15).clamp(0.0, 1.0);
            final bounce = (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 7,
              height: 7,
              transform: Matrix4.translationValues(0, -bounce * 5, 0),
              decoration: BoxDecoration(
                color: AppColors.textHint,
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

// Chat wallpaper removed for neat and clean design
