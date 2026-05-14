import 'dart:async';
import 'dart:io';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String text) onSendText;
  final Function(File image) onSendImage;
  final Function(File voice) onSendVoice;
  final Function(bool isTyping) onTypingChanged;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendVoice,
    required this.onTypingChanged,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _showEmoji = false;
  bool _isRecording = false;
  bool _hasText = false;
  Timer? _typingTimer;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  late AnimationController _animController;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onTypingChanged(hasText);
    _typingTimer?.cancel();
    if (hasText) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        widget.onTypingChanged(false);
      });
    }
  }

  void _send() {
    if (_controller.text.trim().isEmpty) return;
    widget.onSendText(_controller.text);
    _controller.clear();
    widget.onTypingChanged(false);
  }

  Future<void> _pickImage() async {
    Navigator.pop(context);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked != null) {
        widget.onSendImage(File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    Navigator.pop(context);
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) return;
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked != null) {
        widget.onSendImage(File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
      HapticFeedback.mediumImpact();
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordDuration += const Duration(seconds: 1));
    });
  }

  void _stopRecording() {
    _recordTimer?.cancel();
    setState(() => _isRecording = false);
    // In production: stop recorder and get file, then call widget.onSendVoice(file)
  }

  void _toggleEmoji() {
    _focusNode.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        setState(() => _showEmoji = !_showEmoji);
        if (_showEmoji) {
          _animController.forward(from: 0);
        } else {
          _animController.reverse();
        }
      }
    });
  }

  void _showAttachmentSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentSheet(
        onImage: _pickImage,
        onCamera: _takePhoto,
        onVoice: () {
          Navigator.pop(context);
          // Voice recording action
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isRecording) _buildRecordingBar(),
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 4,
            bottom: MediaQuery.of(context).padding.bottom + 4,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _buildEmojiButton(),
                const SizedBox(width: 4),
                Expanded(child: _buildTextField()),
                const SizedBox(width: 4),
                _buildAttachButton(),
                const SizedBox(width: 4),
                _buildSendOrMicButton(),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
        SlideTransition(
          position: _slideAnim,
          child: FadeTransition(
            opacity: _animController,
            child: _buildEmojiPicker(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primarySoft,
      child: Row(
        children: [
          const Icon(Icons.mic_rounded, color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Recording ${AppUtils.formatDuration(_recordDuration)}',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiButton() {
    return GestureDetector(
      onTap: _toggleEmoji,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Icon(
          _showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
          key: ValueKey(_showEmoji),
          color: _showEmoji ? AppColors.primary : AppColors.textSecondary,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider.withOpacity(0.5)),
      ),
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        maxLines: null,
        textCapitalization: TextCapitalization.sentences,
        style: AppTextStyles.bodyLarge,
        decoration: const InputDecoration(
          hintText: 'Message...',
          hintStyle: TextStyle(color: AppColors.textHint),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onTap: () {
          if (_showEmoji) setState(() => _showEmoji = false);
        },
        onSubmitted: (_) => _send(),
      ),
    );
  }

  Widget _buildAttachButton() {
    return GestureDetector(
      onTap: _showAttachmentSheet,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.background,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider.withOpacity(0.5)),
        ),
        child: const Icon(Icons.add, color: AppColors.textSecondary, size: 22),
      ),
    );
  }

  Widget _buildSendOrMicButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) => _stopRecording(),
      onTap: _hasText ? _send : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: _hasText
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                )
              : null,
          color: _hasText ? null : AppColors.primarySoft,
          shape: BoxShape.circle,
          boxShadow: _hasText
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Icon(
          _hasText ? Icons.send_rounded : Icons.mic_rounded,
          color: _hasText ? Colors.white : AppColors.primary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildEmojiPicker() {
    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: EmojiPicker(
        onEmojiSelected: (_, emoji) {
          _controller.text += emoji.emoji;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
          widget.onTypingChanged(true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 2), () {
            widget.onTypingChanged(false);
          });
        },
        config: const Config(
          height: 280,
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: Colors.white,
            columns: 8,
          ),
          categoryViewConfig: CategoryViewConfig(
            iconColorSelected: AppColors.primary,
            indicatorColor: AppColors.primary,
            backgroundColor: AppColors.background,
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            buttonColor: AppColors.primary,
            buttonIconColor: Colors.white,
            backgroundColor: AppColors.background,
          ),
        ),
      ),
    );
  }
}

/// Attachment Bottom Sheet
class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onCamera;
  final VoidCallback onVoice;

  const _AttachmentSheet({
    required this.onImage,
    required this.onCamera,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 16, bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Attach',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          _buildOption(
            icon: Icons.image_outlined,
            label: 'Gallery',
            onTap: onImage,
          ),
          _buildOption(
            icon: Icons.camera_alt_outlined,
            label: 'Camera',
            onTap: onCamera,
          ),
          _buildOption(
            icon: Icons.mic_none_outlined,
            label: 'Voice Note',
            onTap: onVoice,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label, style: AppTextStyles.titleMedium),
          ],
        ),
      ),
    );
  }
}