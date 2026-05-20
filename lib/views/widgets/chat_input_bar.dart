import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../screens/media_preview_screen.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String text) onSendText;
  final Function(File image, String caption) onSendImage;
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
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked != null) {
        final file = File(picked.path);
        if (!mounted) return;
        final caption = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => MediaPreviewScreen(file: file, isVideo: false),
          ),
        );
        if (caption != null) {
          widget.onSendImage(file, caption);
        }
      }
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    Navigator.pop(context);
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) return;
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (picked != null) {
        final file = File(picked.path);
        if (!mounted) return;
        final caption = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => MediaPreviewScreen(file: file, isVideo: false),
          ),
        );
        if (caption != null) {
          widget.onSendImage(file, caption);
        }
      }
    } catch (_) {}
  }

  Future<void> _pickVideo() async {
    Navigator.pop(context);
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (picked != null) {
        final file = File(picked.path);
        if (!mounted) return;
        final caption = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (_) => MediaPreviewScreen(file: file, isVideo: true),
          ),
        );
        if (caption != null) {
          widget.onSendImage(file, caption);
        }
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
    if (!_isRecording) return;
    _recordTimer?.cancel();
    setState(() => _isRecording = false);
    HapticFeedback.heavyImpact();
    // In a real app, we would get the file from the recorder.
    // For this demo/mock, we send a dummy file path.
    widget.onSendVoice(File('mock_voice_message.aac'));
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
      barrierColor: Colors.black26,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: _AttachmentSheet(
          onImage: _pickImage,
          onCamera: _takePhoto,
          onVideo: _pickVideo,
          onVoice: () => Navigator.pop(context),
        ),
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
            border: Border(top: BorderSide(color: AppColors.divider.withOpacity(0.3))),
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
        SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: _animController,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
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

class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onImage;
  final VoidCallback onCamera;
  final VoidCallback onVideo;
  final VoidCallback onVoice;

  const _AttachmentSheet({
    required this.onImage,
    required this.onCamera,
    required this.onVideo,
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
          const Text('Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          // Grid of options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _gridOption(Icons.image_rounded, 'Gallery', AppColors.primary, onImage),
                _gridOption(Icons.camera_alt_rounded, 'Camera', const Color(0xFF10B981), onCamera),
                _gridOption(Icons.videocam_rounded, 'Video', const Color(0xFFF59E0B), onVideo),
                _gridOption(Icons.mic_rounded, 'Audio', const Color(0xFFEF4444), onVoice),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _gridOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}