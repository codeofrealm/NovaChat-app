import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/group_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../services/group_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../views/widgets/chat_input_bar.dart';
import '../../views/widgets/message_bubble.dart';
import '../../views/widgets/user_avatar.dart';
import 'media_gallery_screen.dart';
import 'package:uuid/uuid.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;

  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _scrollController = ScrollController();
  final _groupService = GroupService();
  final _uuid = const Uuid();
  StreamSubscription? _msgSub;
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  String _currentUid = '';

  @override
  void initState() {
    super.initState();
    _currentUid = context.read<AuthViewModel>().uid;
    _msgSub = _groupService
        .groupMessagesStream(widget.group.groupId)
        .listen((msgs) {
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendText(String text) async {
    if (text.trim().isEmpty) return;
    final msg = MessageModel(
      messageId: _uuid.v4(),
      senderId: _currentUid,
      receiverId: widget.group.groupId,
      text: text.trim(),
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isDelivered: true,
      type: MessageType.text,
    );
    await _groupService.sendGroupMessage(widget.group.groupId, msg);
    _scrollToBottom();
  }

  Future<void> _sendImage(File file, String caption) async {
    try {
      final url = await _groupService.uploadGroupImage(widget.group.groupId, file);
      final msg = MessageModel(
        messageId: _uuid.v4(),
        senderId: _currentUid,
        receiverId: widget.group.groupId,
        text: caption,
        imageUrl: url,
        timestamp: DateTime.now().millisecondsSinceEpoch,
        isDelivered: true,
        type: MessageType.image,
      );
      await _groupService.sendGroupMessage(widget.group.groupId, msg);
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _sendVoice(File file) async {
    // In a real app, upload the file here. 
    // For now, we simulate the message being added to the list.
    final msg = MessageModel(
      messageId: _uuid.v4(),
      senderId: _currentUid,
      receiverId: widget.group.groupId,
      voiceUrl: 'mock_url', // In real app: upload and get URL
      timestamp: DateTime.now().millisecondsSinceEpoch,
      isDelivered: true,
      type: MessageType.voice,
    );
    await _groupService.sendGroupMessage(widget.group.groupId, msg);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(child: _buildMessages()),
          ChatInputBar(
            onSendText: _sendText,
            onSendImage: _sendImage,
            onSendVoice: _sendVoice,
            onTypingChanged: (isTyping) {
              // Implementation for typing if needed
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
        left: 4,
        right: 8,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                size: 20, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          widget.group.groupImage.isNotEmpty
              ? CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(widget.group.groupImage),
                )
              : Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.group_rounded,
                      color: AppColors.primary, size: 20),
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.group.name,
                    style: AppTextStyles.titleMedium.copyWith(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  '${widget.group.members.length} members',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
            onPressed: () => _startCall(isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined, color: AppColors.primary),
            onPressed: () => _startCall(isVideo: false),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.primary),
            onPressed: _showMoreOptions,
          ),
        ],
      ),
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
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.primary),
                title: const Text('View Shared Media'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(AppUtils.slideRoute(
                      MediaGalleryScreen(
                          title: widget.group.name,
                          messages: _messages)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary),
                title: const Text('Group Info'),
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _startCall({required bool isVideo}) {
    Navigator.of(context).push(AppUtils.slideRoute(
      CallScreen(
        name: widget.group.name,
        imageUrl: widget.group.groupImage,
        isVideo: isVideo,
        isGroup: true,
      ),
    ));
  }

  Widget _buildMessages() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_messages.isEmpty) {
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
              child: const Icon(Icons.group_rounded,
                  size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(widget.group.name, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            const Text('Say hello to the group! 👋',
                style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final msg = _messages[i];
        final isSent = msg.senderId == _currentUid;
        return MessageBubble(
          key: ValueKey(msg.messageId),
          message: msg,
          isSent: isSent,
          showAvatar: !isSent,
          avatarName: msg.senderId, // Replace with user name lookup if available
          onDelete: () => _groupService.deleteGroupMessage(widget.group.groupId, msg.messageId),
        );
      },
    );
  }

  Widget _buildBubble(MessageModel msg, bool isSent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isSent) ...[
            UserAvatar(imageUrl: '', name: msg.senderId, radius: 14),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isSent ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isSent ? 16 : 4),
                  bottomRight: Radius.circular(isSent ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isSent)
                    Text(
                      msg.senderId,
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  Text(
                    msg.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSent ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppUtils.formatChatTime(msg.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSent ? Colors.white60 : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Call Screen ──────────────────────────────────────────────────────────────
class CallScreen extends StatefulWidget {
  final String name;
  final String imageUrl;
  final bool isVideo;
  final bool isGroup;

  const CallScreen({
    super.key,
    required this.name,
    required this.imageUrl,
    this.isVideo = false,
    this.isGroup = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _muted = false;
  bool _speakerOn = false;
  bool _cameraOff = false;
  int _seconds = 0;
  Timer? _timer;
  bool _callConnected = false;

  @override
  void initState() {
    super.initState();
    // Simulate connecting after 2s
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _callConnected = true);
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _seconds++);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _duration {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
              ),
            ),
          ),

          // Video preview placeholder (if video call)
          if (widget.isVideo && !_cameraOff)
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                width: 100,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Center(
                  child: Icon(Icons.videocam_outlined,
                      color: Colors.white54, size: 32),
                ),
              ),
            ),

          // Center content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              // Avatar
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: widget.imageUrl.isNotEmpty
                      ? Image.network(widget.imageUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarPlaceholder())
                      : _avatarPlaceholder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _callConnected ? _duration : 'Connecting...',
                style: TextStyle(
                  color: _callConnected ? AppColors.online : Colors.white54,
                  fontSize: 15,
                ),
              ),
              if (widget.isGroup)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Group Call',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                ),
            ],
          ),

          // Controls
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Secondary controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _controlBtn(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _muted ? 'Unmute' : 'Mute',
                      onTap: () => setState(() => _muted = !_muted),
                      active: _muted,
                    ),
                    const SizedBox(width: 20),
                    _controlBtn(
                      icon: _speakerOn
                          ? Icons.volume_up_rounded
                          : Icons.volume_down_rounded,
                      label: 'Speaker',
                      onTap: () => setState(() => _speakerOn = !_speakerOn),
                      active: _speakerOn,
                    ),
                    if (widget.isVideo) ...[
                      const SizedBox(width: 20),
                      _controlBtn(
                        icon: _cameraOff
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        label: 'Camera',
                        onTap: () => setState(() => _cameraOff = !_cameraOff),
                        active: _cameraOff,
                      ),
                      const SizedBox(width: 20),
                      _controlBtn(
                        icon: Icons.flip_camera_ios_rounded,
                        label: 'Flip',
                        onTap: () {},
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 32),
                // End call button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.error.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.call_end_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
        color: AppColors.primarySoft,
        child: Center(
          child: Text(
            widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
            style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
        ),
      );

  Widget _controlBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : Colors.white12,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
  }
}
