import 'dart:async';
import 'dart:io';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) widget.onSendImage(File(picked.path));
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
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
    if (_showEmoji) {
      _focusNode.requestFocus();
    } else {
      _focusNode.unfocus();
    }
    setState(() => _showEmoji = !_showEmoji);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isRecording) _buildRecordingBar(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                _buildEmojiButton(),
                const SizedBox(width: 8),
                Expanded(child: _buildTextField()),
                const SizedBox(width: 8),
                _buildAttachButton(),
                const SizedBox(width: 6),
                _buildSendOrMicButton(),
              ],
            ),
          ),
        ),
        if (_showEmoji) _buildEmojiPicker(),
      ],
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.primarySoft,
      child: Row(
        children: [
          const Icon(Icons.mic, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Text(
            'Recording ${AppUtils.formatDuration(_recordDuration)}',
            style: const TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _stopRecording,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiButton() {
    return GestureDetector(
      onTap: _toggleEmoji,
      child: Icon(
        _showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined,
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
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
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
      onTap: _pickImage,
      child: const Icon(
        Icons.attach_file_rounded,
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }

  Widget _buildSendOrMicButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, anim) =>
          ScaleTransition(scale: anim, child: child),
      child: _hasText
          ? GestureDetector(
              key: const ValueKey('send'),
              onTap: _send,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            )
          : GestureDetector(
              key: const ValueKey('mic'),
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isRecording ? AppColors.error : AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mic,
                  color: _isRecording ? Colors.white : AppColors.primary,
                  size: 22,
                ),
              ),
            ),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 280,
      child: EmojiPicker(
        onEmojiSelected: (_, emoji) {
          _controller.text += emoji.emoji;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        },
        config: const Config(
          height: 280,
          emojiViewConfig: EmojiViewConfig(
            backgroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}
