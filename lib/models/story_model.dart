class StoryModel {
  final String storyId;
  final String userId;
  final String userName;
  final String userImage;
  final String mediaUrl;
  final String caption;
  final int createdAt;
  final int expiresAt; // createdAt + 24h
  final List<String> viewedBy;

  const StoryModel({
    required this.storyId,
    required this.userId,
    required this.userName,
    required this.userImage,
    required this.mediaUrl,
    this.caption = '',
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
  });

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > expiresAt;

  factory StoryModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return StoryModel(
      storyId: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userImage: map['userImage'] ?? '',
      mediaUrl: map['mediaUrl'] ?? '',
      caption: map['caption'] ?? '',
      createdAt: map['createdAt'] ?? 0,
      expiresAt: map['expiresAt'] ?? 0,
      viewedBy: List<String>.from(map['viewedBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
    'storyId': storyId,
    'userId': userId,
    'userName': userName,
    'userImage': userImage,
    'mediaUrl': mediaUrl,
    'caption': caption,
    'createdAt': createdAt,
    'expiresAt': expiresAt,
    'viewedBy': viewedBy,
  };
}
