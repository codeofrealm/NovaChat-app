import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/message_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isSent;
  final bool showAvatar;
  final String avatarUrl;
  final String avatarName;
  final Function(String emoji)? onReact;
  final bool animateIn;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showAvatar = false,
    this.avatarUrl = '',
    this.avatarName = '',
    this.onReact,
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
  bool _showReactions = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    if (widget.animateIn) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onLongPress: () => _showReactionPicker(context),
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.isSent ? 64 : 16,
              right: widget.isSent ? 16 : 64,
              bottom: 4,
              top: 2,
            ),
            child: Column(
              crossAxisAlignment:
                  widget.isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (widget.showAvatar && !widget.isSent) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: widget.avatarUrl,
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: AppColors.primarySoft,
                              child: const Icon(Icons.person, size: 14),
                            ),
                            errorWidget: (_, __, ___) => _initialsWidget(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.avatarName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildBubbleWrapper(context),
                if (widget.message.reactions.isNotEmpty)
                  _buildReactions(),
                const SizedBox(height: 2),
                _buildMeta(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleWrapper(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isSent ? AppColors.sentBubble : AppColors.receivedBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.isSent ? 18 : 4),
          bottomRight: Radius.circular(widget.isSent ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(widget.isSent ? 18 : 4),
          bottomRight: Radius.circular(widget.isSent ? 4 : 18),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    switch (widget.message.type) {
      case MessageType.image:
        return _buildImageContent();
      case MessageType.voice:
        return _buildVoiceContent();
      case MessageType.emoji:
        return _buildEmojiContent();
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            widget.message.text,
            style: TextStyle(
              fontSize: 15,
              color: widget.isSent ? Colors.white : AppColors.textPrimary,
              height: 1.45,
            ),
          ),
        );
    }
  }

  Widget _buildImageContent() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CachedNetworkImage(
        imageUrl: widget.message.imageUrl,
        width: 220,
        height: 200,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 220,
          height: 200,
          color: AppColors.shimmerBase,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: 220,
          height: 200,
          color: AppColors.shimmerBase,
          child: const Icon(Icons.error_outline, color: AppColors.textHint),
        ),
      ),
    );
  }

  Widget _buildVoiceContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_filled_rounded,
            color: widget.isSent ? Colors.white : AppColors.primary,
            size: 32,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 3,
                decoration: BoxDecoration(
                  color: widget.isSent
                      ? Colors.white.withOpacity(0.4)
                      : AppColors.primary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Voice message',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isSent
                      ? Colors.white.withOpacity(0.7)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '0:32',
            style: TextStyle(
              fontSize: 10,
              color: widget.isSent
                  ? Colors.white.withOpacity(0.5)
                  : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        widget.message.text,
        style: const TextStyle(fontSize: 40),
      ),
    );
  }

  Widget _buildReactions() {
    final grouped = <String, int>{};
    for (final emoji in widget.message.reactions.values) {
      grouped[emoji] = (grouped[emoji] ?? 0) + 1;
    }
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: grouped.entries
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${e.key}${e.value > 1 ? ' ${e.value}' : ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildMeta() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppUtils.formatMessageTime(widget.message.timestamp),
          style: AppTextStyles.bodySmall,
        ),
        const SizedBox(width: 4),
        if (widget.isSent)
          Icon(
            widget.message.isSeen
                ? Icons.done_all_rounded
                : widget.message.isDelivered
                    ? Icons.done_all_rounded
                    : Icons.check_rounded,
            size: 13,
            color: widget.message.isSeen ? AppColors.primary : AppColors.textHint,
          ),
      ],
    );
  }

  Widget _initialsWidget() {
    final initial = widget.avatarName.isNotEmpty ? widget.avatarName[0] : '?';
    return Container(
      color: AppColors.primarySoft,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    const emojis = ['❤️', '😂', '😮', '😢', '👍', '🔥', '🎉', '😎'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'React',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: emojis
                  .map((e) => GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onReact?.call(e);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(e, style: const TextStyle(fontSize: 24)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}