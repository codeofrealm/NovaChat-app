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

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _dbService = DatabaseService();
  late ChatViewModel _chatVm;
  late String _currentUid;
  bool _showAppBar = true;
  double _lastScrollOffset = 0;

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
    _chatVm.listenToMessages(widget.chatId, _currentUid);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _dbService.setTyping(widget.chatId, _currentUid, false);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _chatVm.markSeen(widget.chatId, _currentUid);
    }
  }

  void _onScroll() {
    final direction = _scrollController.offset - _lastScrollOffset;
    if (direction.abs() < 5) return;
    _lastScrollOffset = _scrollController.offset;
    final shouldShow = direction < 0;
    if (shouldShow != _showAppBar && mounted) {
      setState(() => _showAppBar = shouldShow);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildAnimatedAppBar(),
          Expanded(child: _buildMessageList()),
          _buildTypingIndicator(),
          _buildUploadProgress(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildAnimatedAppBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      color: Colors.white,
      height: _showAppBar ? 60 : 0,
      width: double.infinity,
      child: _showAppBar
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded,
                          size: 20, color: AppColors.textPrimary),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    StreamBuilder<Map<String, dynamic>>(
                      stream:
                          _dbService.presenceStream(widget.otherUser.uid),
                      builder: (_, presenceSnap) {
                        final presence = presenceSnap.data ?? {};
                        final isOnline =
                            presence['isOnline'] as bool? ?? false;
                        final lastSeen =
                            presence['lastSeen'] as int? ?? 0;
                        return Expanded(
                          child: Row(
                            children: [
                              UserAvatar(
                                imageUrl: widget.otherUser.profileImage,
                                name: widget.otherUser.name,
                                radius: 18,
                                showOnline: true,
                                isOnline: isOnline,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.otherUser.name,
                                      style: AppTextStyles.titleMedium,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    StreamBuilder<bool>(
                                      stream: _chatVm.typingStream(
                                        widget.chatId,
                                        widget.otherUser.uid,
                                      ),
                                      builder: (_, typingSnap) {
                                        final isTyping =
                                            typingSnap.data ?? false;
                                        return AnimatedSwitcher(
                                          duration: const Duration(
                                              milliseconds: 250),
                                          child: isTyping
                                              ? const Text(
                                                  'typing...',
                                                  key: ValueKey('typing'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color:
                                                        AppColors.primary,
                                                    fontStyle:
                                                        FontStyle.italic,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                )
                                              : Text(
                                                  isOnline
                                                      ? 'Online'
                                                      : lastSeen > 0
                                                          ? AppUtils
                                                              .formatLastSeen(
                                                                  lastSeen)
                                                          : 'Offline',
                                                  key: const ValueKey(
                                                      'status'),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isOnline
                                                        ? AppColors.online
                                                        : AppColors
                                                            .textHint,
                                                  ),
                                                ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.videocam_outlined,
                                    color: AppColors.primary),
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.call_outlined,
                                    color: AppColors.primary),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading) return const MessageShimmer();
        if (vm.messages.isEmpty) return _buildEmptyChat();

        _scrollToBottom();

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              reverse: false,
              itemCount: vm.messages.length,
              itemBuilder: (_, i) {
                final msg = vm.messages[i];
                final isSent = msg.senderId == _currentUid;
                final showDate = i == 0 ||
                    !_isSameDay(
                        vm.messages[i - 1].timestamp, msg.timestamp);

                return Column(
                  children: [
                    if (showDate) _buildDateDivider(msg.timestamp),
                    const SizedBox(height: 2),
                    MessageBubble(
                      key: ValueKey(msg.messageId),
                      message: msg,
                      isSent: isSent,
                      showAvatar: true,
                      avatarUrl: isSent
                          ? (context.read<AuthViewModel>().currentUser
                                      ?.profileImage ??
                                  '')
                          : widget.otherUser.profileImage,
                      avatarName:
                          isSent ? 'You' : widget.otherUser.name,
                      onReact: (emoji) => vm.addReaction(
                        widget.chatId,
                        msg.messageId,
                        _currentUid,
                        emoji,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
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
      now.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    )) {
      label = 'Yesterday';
    } else {
      label = AppUtils.formatChatTime(timestamp);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider, height: 1)),
        ],
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 80),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.2),
                  AppColors.accent.withOpacity(0.15),
                ],
              ),
            ),
            child: UserAvatar(
              imageUrl: widget.otherUser.profileImage,
              name: widget.otherUser.name,
              radius: 42,
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.otherUser.name, style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Say hello! 👋',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
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
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: isTyping ? 28 : 0,
          color: AppColors.primarySoft,
          child: isTyping
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.more_horiz,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.otherUser.name} is typing...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontStyle: FontStyle.italic,
                        ),
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
          color: AppColors.primarySoft.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            children: [
              LinearProgressIndicator(
                value: vm.uploadProgress,
                backgroundColor: AppColors.background,
                color: AppColors.primary,
                minHeight: 2,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.cloud_upload_outlined,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Sending ${(vm.uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
      onSendImage: (File file) {
        _chatVm.sendImageMessage(
          chatId: widget.chatId,
          senderId: _currentUid,
          receiverId: widget.otherUser.uid,
          imageFile: file,
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

  bool _isSameDay(int ts1, int ts2) {
    final d1 = DateTime.fromMillisecondsSinceEpoch(ts1);
    final d2 = DateTime.fromMillisecondsSinceEpoch(ts2);
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }
}