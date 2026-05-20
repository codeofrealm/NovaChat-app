class GroupModel {
  final String groupId;
  final String name;
  final String description;
  final String groupImage;
  final String createdBy;
  final List<String> members;
  final List<String> admins;
  final String lastMessage;
  final int lastMessageTime;
  final int createdAt;

  const GroupModel({
    required this.groupId,
    required this.name,
    this.description = '',
    this.groupImage = '',
    required this.createdBy,
    required this.members,
    required this.admins,
    this.lastMessage = '',
    this.lastMessageTime = 0,
    required this.createdAt,
  });

  factory GroupModel.fromMap(Map<dynamic, dynamic> map, String id) {
    return GroupModel(
      groupId: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      groupImage: map['groupImage'] ?? '',
      createdBy: map['createdBy'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      admins: List<String>.from(map['admins'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] ?? 0,
      createdAt: map['createdAt'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'groupId': groupId,
    'name': name,
    'description': description,
    'groupImage': groupImage,
    'createdBy': createdBy,
    'members': members,
    'admins': admins,
    'lastMessage': lastMessage,
    'lastMessageTime': lastMessageTime,
    'createdAt': createdAt,
  };
}
