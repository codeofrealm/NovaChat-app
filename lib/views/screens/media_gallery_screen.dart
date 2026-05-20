import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/message_model.dart';
import '../../utils/app_theme.dart';

class MediaGalleryScreen extends StatelessWidget {
  final String title;
  final List<MessageModel> messages;

  const MediaGalleryScreen({
    super.key,
    required this.title,
    required this.messages,
  });

  @override
  Widget build(BuildContext context) {
    final mediaMessages = messages
        .where((m) => m.type == MessageType.image && m.imageUrl.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: AppTextStyles.headlineMedium),
            Text(
              '${mediaMessages.length} media files',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      ),
      body: mediaMessages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: AppColors.textHint.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text(
                    'No media shared yet',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: mediaMessages.length,
              itemBuilder: (context, index) {
                final msg = mediaMessages[index];
                return GestureDetector(
                  onTap: () {
                    // Full screen image viewer could be added here
                  },
                  child: Hero(
                    tag: msg.messageId,
                    child: CachedNetworkImage(
                      imageUrl: msg.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.shimmerBase,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.shimmerBase,
                        child: const Icon(Icons.error_outline),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
