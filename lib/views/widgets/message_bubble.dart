import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isSent;
  final bool showAvatar;
  final String avatarUrl;
  final String avatarName;
  final Function(String emoji)? onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showAvatar = false,
    this.avatarUrl = '',
    this.avatarName = '',
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showReactionPicker(context),
      child: Padding(
        padding: EdgeInsets.only(
          left: isSent ? 60 : 12,
          right: isSent ? 12 : 60,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment:
              isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _buildBubble(context),
            if (message.reactions.isNotEmpty) _buildReactions(),
            const SizedBox(height: 2),
            _buildMeta(),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: isSent ? AppColors.sentBubble : AppColors.receivedBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isSent ? 18 : 4),
          bottomRight: Radius.circular(isSent ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    switch (message.type) {
      case MessageType.image:
        return _buildImageContent();
      case MessageType.voice:
        return _buildVoiceContent();
      default:
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 15,
              color: isSent ? Colors.white : AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        );
    }
  }

  Widget _buildImageContent() {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: const Radius.circular(18),
        topRight: const Radius.circular(18),
        bottomLeft: Radius.circular(isSent ? 18 : 4),
        bottomRight: Radius.circular(isSent ? 4 : 18),
      ),
      child: CachedNetworkImage(
        imageUrl: message.imageUrl,
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
            Icons.play_circle_filled,
            color: isSent ? Colors.white : AppColors.primary,
            size: 32,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 100,
                height: 3,
                decoration: BoxDecoration(
                  color: isSent
                      ? Colors.white.withOpacity(0.5)
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Voice message',
                style: TextStyle(
                  fontSize: 12,
                  color: isSent
                      ? Colors.white.withOpacity(0.8)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReactions() {
    final grouped = <String, int>{};
    for (final emoji in message.reactions.values) {
      grouped[emoji] = (grouped[emoji] ?? 0) + 1;
    }
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: grouped.entries
            .map((e) => Text('${e.key}${e.value > 1 ? e.value : ''}',
                style: const TextStyle(fontSize: 14)))
            .toList(),
      ),
    );
  }

  Widget _buildMeta() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppUtils.formatMessageTime(message.timestamp),
          style: AppTextStyles.bodySmall,
        ),
        if (isSent) ...[
          const SizedBox(width: 4),
          Icon(
            message.isSeen
                ? Icons.done_all
                : message.isDelivered
                    ? Icons.done_all
                    : Icons.done,
            size: 14,
            color: message.isSeen ? AppColors.primary : AppColors.textHint,
          ),
        ],
      ],
    );
  }

  void _showReactionPicker(BuildContext context) {
    const emojis = ['❤️', '😂', '😮', '😢', '👍', '🔥'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis
              .map((e) => GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onReact?.call(e);
                    },
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
