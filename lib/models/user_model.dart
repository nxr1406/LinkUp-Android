import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String? photoURL;
  final String? bio;
  final DateTime createdAt;
  final DateTime lastSeen;
  final bool isOnline;
  final List<String> blockedUsers;
  final List<String> restrictedUsers;
  final Map<String, dynamic>? vanishModeSettings;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    this.photoURL,
    this.bio,
    required this.createdAt,
    required this.lastSeen,
    required this.isOnline,
    required this.blockedUsers,
    required this.restrictedUsers,
    this.vanishModeSettings,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'photoURL': photoURL,
      'bio': bio,
      'createdAt': createdAt,
      'lastSeen': lastSeen,
      'isOnline': isOnline,
      'blockedUsers': blockedUsers,
      'restrictedUsers': restrictedUsers,
      'vanishModeSettings': vanishModeSettings,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      photoURL: map['photoURL'],
      bio: map['bio'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (map['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: map['isOnline'] ?? false,
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      restrictedUsers: List<String>.from(map['restrictedUsers'] ?? []),
      vanishModeSettings: map['vanishModeSettings'],
    );
  }
}
