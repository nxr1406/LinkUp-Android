class UserModel {
  final String uid;
  final String username;
  final String displayName;
  final String email;
  final String? photoBase64;
  final bool isVerified;
  final bool isAdmin;
  final bool isSuspended;
  final DateTime createdAt;
  final DateTime? lastSeen;

  UserModel({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.email,
    this.photoBase64,
    this.isVerified = false,
    this.isAdmin = false,
    this.isSuspended = false,
    required this.createdAt,
    this.lastSeen,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      email: map['email'] ?? '',
      photoBase64: map['photoBase64'],
      isVerified: map['isVerified'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
      isSuspended: map['isSuspended'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'displayName': displayName,
      'email': email,
      'photoBase64': photoBase64,
      'isVerified': isVerified,
      'isAdmin': isAdmin,
      'isSuspended': isSuspended,
      'createdAt': createdAt,
      'lastSeen': lastSeen,
    };
  }

  UserModel copyWith({
    String? displayName,
    String? username,
    String? photoBase64,
    bool? isVerified,
    bool? isAdmin,
    bool? isSuspended,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email,
      photoBase64: photoBase64 ?? this.photoBase64,
      isVerified: isVerified ?? this.isVerified,
      isAdmin: isAdmin ?? this.isAdmin,
      isSuspended: isSuspended ?? this.isSuspended,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
