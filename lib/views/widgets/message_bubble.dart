import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/message_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import '../../views/widgets/user_avatar.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isSent;
  final bool showAvatar;
  final String avatarUrl;
  final String avatarName;
  final Function(String emoji)? onReact;
  final VoidCallback? onReply;
  final VoidCallback? onDelete;
  final bool animateIn;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showAvatar = false,
    this.avatarUrl = '',
    this.avatarName = '',
    this.onReact,
    this.onReply,
    this.onDelete,
    this.animateIn = true,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  double _swipeDx = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: widget.animateIn ? 0 : 1,
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    if (widget.animateIn) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isEmoji =>
      widget.message.type == MessageType.emoji ||
      (widget.message.type == MessageType.text &&
          widget.message.text.length <= 4 &&
          _isOnlyEmoji(widget.message.text));

  bool _isOnlyEmoji(String text) {
    final r = RegExp(
        r'^[\u{1F300}-\u{1FFFF}\u{2600}-\u{27BF}\u{FE00}-\u{FEFF}]+$',
        unicode: true);
    return r.hasMatch(text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            _showOptions(context);
          },
          onHorizontalDragUpdate: (d) {
            setState(() => _swipeDx += d.delta.dx);
            if (_swipeDx.abs() > 60) {
              HapticFeedback.lightImpact();
              widget.onReply?.call();
              setState(() => _swipeDx = 0);
            }
          },
          onHorizontalDragEnd: (_) => setState(() => _swipeDx = 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            transform: Matrix4.translationValues(
                _swipeDx.clamp(-40.0, 40.0), 0, 0),
            child: Padding(
              padding: EdgeInsets.only(
                left: widget.isSent ? 60 : 8,
                right: widget.isSent ? 8 : 60,
                bottom: 2,
                top: 2,
              ),
              child: Row(
                mainAxisAlignment: widget.isSent
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!widget.isSent) ...[
                    UserAvatar(
                        imageUrl: widget.avatarUrl,
                        name: widget.avatarName,
                        radius: 14),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Column(
                      crossAxisAlignment: widget.isSent
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        _buildBubble(),
                        if (widget.message.reactions.isNotEmpty)
                          _buildReactions(),
                        const SizedBox(height: 1),
                        _buildMeta(),
                      ],
                    ),
                  ),
                  if (widget.isSent) const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble() {
    if (_isEmoji) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Text(widget.message.text,
            style: const TextStyle(fontSize: 44)),
      );
    }

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(widget.isSent ? 20 : 6),
      bottomRight: Radius.circular(widget.isSent ? 6 : 20),
    );

    return Container(
      decoration: BoxDecoration(
        color: widget.isSent ? AppColors.sentBubble : AppColors.receivedBubble,
        borderRadius: radius,
        border: widget.isSent ? null : Border.all(color: AppColors.divider.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: radius, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    switch (widget.message.type) {
      case MessageType.image:
        return _buildImageContent();
      case MessageType.voice:
        return _buildVoiceContent();
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            widget.message.text,
            style: TextStyle(
              fontSize: 15,
              color: widget.isSent ? Colors.white : AppColors.textPrimary,
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
    }
  }

  Widget _buildImageContent() {
    final url = widget.message.imageUrl;
    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final isVideo = url.endsWith('.mp4') || url.endsWith('.mov') ||
        url.endsWith('.avi') || url.endsWith('.mkv');

    final media = isLocal
        ? Image.file(File(url),
            width: 220, height: 200, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _mediaError())
        : CachedNetworkImage(
            imageUrl: url,
            width: 220,
            height: 200,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 220,
              height: 200,
              color: AppColors.shimmerBase,
              child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => _mediaError(),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              media,
              if (isVideo)
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 32),
                ),
            ],
          ),
        ),
        if (widget.message.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Text(
              widget.message.text,
              style: TextStyle(
                fontSize: 14,
                color: widget.isSent ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _mediaError() => Container(
        width: 220,
        height: 200,
        color: AppColors.shimmerBase,
        child: const Icon(Icons.broken_image_outlined,
            color: AppColors.textHint, size: 40),
      );

  Widget _buildVoiceContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_circle_filled_rounded,
              color: widget.isSent ? Colors.white : AppColors.primary,
              size: 34),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 110,
                height: 3,
                decoration: BoxDecoration(
                  color: widget.isSent
                      ? Colors.white38
                      : AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Text('Voice message',
                  style: TextStyle(
                      fontSize: 11,
                      color: widget.isSent
                          ? Colors.white70
                          : AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactions() {
    final grouped = <String, int>{};
    for (final e in widget.message.reactions.values) {
      grouped[e] = (grouped[e] ?? 0) + 1;
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: grouped.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Text(
                    e.value > 1 ? '${e.key} ${e.value}' : e.key,
                    style: const TextStyle(fontSize: 13),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMeta() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppUtils.formatMessageTime(widget.message.timestamp),
            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
          ),
          if (widget.isSent) ...[
            const SizedBox(width: 3),
            Icon(
              widget.message.isSeen
                  ? Icons.done_all_rounded
                  : widget.message.isDelivered
                      ? Icons.done_all_rounded
                      : Icons.check_rounded,
              size: 14,
              color: widget.message.isSeen
                  ? AppColors.primary
                  : AppColors.textHint,
            ),
          ],
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    const emojis = ['❤️', '😂', '😮', '😢', '👍', '🔥'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2)),
              ),
              // Quick reactions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis
                      .map((e) => GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onReact?.call(e);
                            },
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.5, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.elasticOut,
                              builder: (_, v, child) =>
                                  Transform.scale(scale: v, child: child),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(e,
                                    style: const TextStyle(fontSize: 26)),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              if (widget.message.type == MessageType.text)
                _optionTile(Icons.copy_rounded, 'Copy', AppColors.primary, () {
                  Navigator.pop(context);
                  Clipboard.setData(
                      ClipboardData(text: widget.message.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }),
              _optionTile(Icons.reply_rounded, 'Reply', AppColors.primary, () {
                Navigator.pop(context);
                widget.onReply?.call();
              }),
              _optionTile(Icons.forward_rounded, 'Forward',
                  AppColors.textSecondary, () => Navigator.pop(context)),
              _optionTile(Icons.delete_outline_rounded, 'Delete',
                  AppColors.error, () {
                Navigator.pop(context);
                widget.onDelete?.call();
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionTile(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: color == AppColors.error ? AppColors.error : AppColors.textPrimary)),
      onTap: onTap,
      dense: true,
    );
  }
}
