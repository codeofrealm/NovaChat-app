import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String profileImage;
  final String about;
  final bool isOnline;
  final int lastSeen;
  final int createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImage = '',
    this.about = 'Hey there! I am using NovaChat.',
    this.isOnline = false,
    required this.lastSeen,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<dynamic, dynamic> map, String uid) {
    int _toInt(dynamic v) {
      if (v is int) return v;
      if (v is Timestamp) return v.millisecondsSinceEpoch;
      return 0;
    }

    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      profileImage: map['profileImage'] ?? '',
      about: map['about'] ?? 'Hey there! I am using NovaChat.',
      isOnline: map['isOnline'] ?? false,
      lastSeen: _toInt(map['lastSeen']),
      createdAt: _toInt(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'name': name,
    'email': email,
    'phone': phone,
    'profileImage': profileImage,
    'about': about,
    'isOnline': isOnline,
    'lastSeen': lastSeen,
    'createdAt': createdAt,
  };

  UserModel copyWith({
    String? name, String? email, String? phone,
    String? profileImage, String? about,
    bool? isOnline, int? lastSeen,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      about: about ?? this.about,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt,
    );
  }
}
