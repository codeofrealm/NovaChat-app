import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/user_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_utils.dart';
import 'user_avatar.dart';

class ChatListTile extends StatelessWidget {
  final UserModel user;
  final String lastMessage;
  final int lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback onTap;

  const ChatListTile({
    super.key,
    required this.user,
    this.lastMessage = '',
    this.lastMessageTime = 0,
    this.unreadCount = 0,
    this.isOnline = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: AppColors.primarySoft.withOpacity(0.5),
          highlightColor: AppColors.primarySoft,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
            child: Row(
              children: [
                Stack(
                  children: [
                    UserAvatar(
                      imageUrl: user.profileImage,
                      name: user.name,
                      radius: 28,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.online,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.name,
                              style: AppTextStyles.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessageTime > 0)
                            Text(
                              AppUtils.formatChatTime(lastMessageTime),
                              style: TextStyle(
                                fontSize: 11,
                                color: unreadCount > 0
                                    ? AppColors.primary
                                    : AppColors.textHint,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage.isNotEmpty
                                  ? lastMessage
                                  : user.about,
                              style: TextStyle(
                                fontSize: 13,
                                color: unreadCount > 0
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: unreadCount > 0
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading shimmer version
class ChatListTileShimmer extends StatelessWidget {
  const ChatListTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}