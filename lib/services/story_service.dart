import 'package:firebase_database/firebase_database.dart';
import '../models/story_model.dart';

class StoryService {
  final _db = FirebaseDatabase.instance.ref();

  Future<void> addStory(StoryModel story) async {
    try {
      await _db.child('stories/${story.userId}/${story.storyId}').set(story.toMap());
    } catch (_) {}
  }

  Future<void> markViewed(String userId, String storyId, String viewerId) async {
    try {
      await _db.child('stories/$userId/$storyId/viewedBy/$viewerId').set(true);
    } catch (_) {}
  }

  // Returns all non-expired stories grouped by userId
  Stream<Map<String, List<StoryModel>>> storiesStream() {
    return _db.child('stories').onValue.asBroadcastStream().map((event) {
      if (!event.snapshot.exists) return <String, List<StoryModel>>{};
      final now = DateTime.now().millisecondsSinceEpoch;
      final result = <String, List<StoryModel>>{};
      final usersMap = event.snapshot.value as Map;

      for (final userEntry in usersMap.entries) {
        final uid = userEntry.key as String;
        final storiesMap = userEntry.value as Map;
        final stories = <StoryModel>[];

        for (final storyEntry in storiesMap.entries) {
          final story = StoryModel.fromMap(
            storyEntry.value as Map,
            storyEntry.key as String,
          );
          if (story.expiresAt > now) stories.add(story);
        }

        if (stories.isNotEmpty) {
          stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          result[uid] = stories;
        }
      }
      return result;
    }).handleError((_) => <String, List<StoryModel>>{});
  }

  // Delete expired stories (call periodically)
  Future<void> cleanExpiredStories() async {
    try {
      final snap = await _db.child('stories').get();
      if (!snap.exists) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final usersMap = snap.value as Map;
      for (final userEntry in usersMap.entries) {
        final storiesMap = userEntry.value as Map;
        for (final storyEntry in storiesMap.entries) {
          final expiresAt = (storyEntry.value as Map)['expiresAt'] as int? ?? 0;
          if (expiresAt < now) {
            await _db.child('stories/${userEntry.key}/${storyEntry.key}').remove();
          }
        }
      }
    } catch (_) {}
  }
}
