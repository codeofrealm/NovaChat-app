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

class _ChatScreenState extends State<ChatScreen> {
  final _scrollController = ScrollController();
  final _dbService = DatabaseService();
  late ChatViewModel _chatVm;
  late String _currentUid;

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
  }

  @override
  void dispose() {
    // Clear typing indicator when leaving chat
    _dbService.setTyping(widget.chatId, _currentUid, false);
    _scrollController.dispose();
    super.dispose();
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
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildUploadProgress(),
          ChatInputBar(
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
          ),
        ],
      ),
    );
  }

  // ─── AppBar with live presence from RTDB ──────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: StreamBuilder<Map<String, dynamic>>(
        // Live presence from Realtime Database — fastest possible update
        stream: _dbService.presenceStream(widget.otherUser.uid),
        builder: (_, presenceSnap) {
          final presence = presenceSnap.data ?? {};
          final isOnline = presence['isOnline'] as bool? ?? false;
          final lastSeen = presence['lastSeen'] as int? ?? 0;

          return Row(
            children: [
              UserAvatar(
                imageUrl: widget.otherUser.profileImage,
                name: widget.otherUser.name,
                radius: 20,
                showOnline: true,
                isOnline: isOnline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Typing indicator takes priority over online status
                    StreamBuilder<bool>(
                      stream: _chatVm.typingStream(
                        widget.chatId,
                        widget.otherUser.uid,
                      ),
                      builder: (_, typingSnap) {
                        final isTyping = typingSnap.data ?? false;
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: isTyping
                              ? const Text(
                                  'typing...',
                                  key: ValueKey('typing'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : Text(
                                  isOnline
                                      ? 'Online'
                                      : lastSeen > 0
                                          ? AppUtils.formatLastSeen(lastSeen)
                                          : 'Offline',
                                  key: const ValueKey('status'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isOnline
                                        ? AppColors.online
                                        : AppColors.textHint,
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
          onPressed: () {},
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined, color: AppColors.primary),
          onPressed: () {},
        ),
      ],
    );
  }

  // ─── Message List ──────────────────────────────────────────
  Widget _buildMessageList() {
    return Consumer<ChatViewModel>(
      builder: (_, vm, __) {
        if (vm.isLoading) return const MessageShimmer();
        if (vm.messages.isEmpty) return _buildEmptyChat();

        // Auto-scroll when new messages arrive
        _scrollToBottom();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12),
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
                  message: msg,
                  isSent: isSent,
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
        );
      },
    );
  }

  // ─── Date Divider ──────────────────────────────────────────
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
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }

  // ─── Empty Chat ────────────────────────────────────────────
  Widget _buildEmptyChat() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            imageUrl: widget.otherUser.profileImage,
            name: widget.otherUser.name,
            radius: 40,
          ),
          const SizedBox(height: 16),
          Text(widget.otherUser.name, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 6),
          Text(
            widget.otherUser.about,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
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

  // ─── Upload Progress ───────────────────────────────────────
  Widget _buildUploadProgress() {
    return Consumer<ChatViewModel>(
      builder: (_, vm, __) {
        if (!vm.isSending || vm.uploadProgress == 0) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            LinearProgressIndicator(
              value: vm.uploadProgress,
              backgroundColor: AppColors.primarySoft,
              color: AppColors.primary,
              minHeight: 3,
            ),
            Container(
              color: AppColors.primarySoft,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.upload_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Uploading ${(vm.uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
