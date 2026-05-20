import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/story_model.dart';
import '../../services/story_service.dart';
import '../../utils/app_theme.dart';
import '../../views/widgets/user_avatar.dart';

class StoryViewerScreen extends StatefulWidget {
  final String userId;
  final List<StoryModel> stories;
  final String currentUid;

  const StoryViewerScreen({
    super.key,
    required this.userId,
    required this.stories,
    required this.currentUid,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  int _currentIndex = 0;
  final _storyService = StoryService();
  static const _storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: _storyDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _next();
      });
    _startStory();
  }

  void _startStory() {
    _progressController.forward(from: 0);
    final story = widget.stories[_currentIndex];
    if (!story.viewedBy.contains(widget.currentUid)) {
      _storyService.markViewed(widget.userId, story.storyId, widget.currentUid);
    }
  }

  void _next() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() => _currentIndex++);
      _startStory();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startStory();
    }
  }

  String _timeLeft(int expiresAt) {
    final diff = expiresAt - DateTime.now().millisecondsSinceEpoch;
    if (diff <= 0) return 'Expired';
    final hours = diff ~/ 3600000;
    final mins = (diff % 3600000) ~/ 60000;
    if (hours > 0) return '${hours}h ${mins}m left';
    return '${mins}m left';
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];
    final isLocal = story.mediaUrl.startsWith('/');

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          _progressController.stop();
          final x = d.globalPosition.dx;
          final w = MediaQuery.of(context).size.width;
          if (x < w / 3) _prev();
          else _next();
        },
        onTapUp: (_) => _progressController.forward(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story image
            story.mediaUrl.isNotEmpty
                ? isLocal
                    ? Image.file(File(story.mediaUrl), fit: BoxFit.cover)
                    : Image.network(story.mediaUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                : _placeholder(),

            // Gradient top
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
            ),

            // Progress bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              right: 8,
              child: Row(
                children: List.generate(widget.stories.length, (i) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: i < _currentIndex
                            ? Container(height: 3, color: Colors.white)
                            : i == _currentIndex
                                ? AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (_, __) => LinearProgressIndicator(
                                      value: _progressController.value,
                                      backgroundColor: Colors.white38,
                                      color: Colors.white,
                                      minHeight: 3,
                                    ),
                                  )
                                : Container(height: 3, color: Colors.white38),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Header
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  UserAvatar(
                    imageUrl: story.userImage,
                    name: story.userName,
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(story.userName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(
                          _timeLeft(story.expiresAt),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Caption
            if (story.caption.isNotEmpty)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    story.caption,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Views count (own story)
            if (story.userId == widget.currentUid)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_outlined,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '${story.viewedBy.length} views',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.primarySoft,
        child: const Center(
          child: Icon(Icons.image_outlined,
              size: 80, color: AppColors.primary),
        ),
      );
}
