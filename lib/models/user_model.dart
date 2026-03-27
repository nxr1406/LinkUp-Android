import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String avatarUrl;
  final String bio;
  final bool isOnline;
  final Timestamp? lastSeen;
  final List<String> blockedUsers;
  final bool notificationsEnabled;

  UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    this.avatarUrl = '',
    this.bio = '',
    this.isOnline = false,
    this.lastSeen,
    this.blockedUsers = const [],
    this.notificationsEnabled = true,
  });

  factory UserModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
      bio: data['bio'] ?? '',
      isOnline: data['isOnline'] ?? false,
      lastSeen: data['lastSeen'],
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      notificationsEnabled: data['notificationsEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'fullName': fullName,
        'username': username,
        'email': email,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'isOnline': isOnline,
        'lastSeen': lastSeen,
        'blockedUsers': blockedUsers,
        'notificationsEnabled': notificationsEnabled,
      };
}
