class VerificationRequest {
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final String reason;
  final String status; // pending, approved, rejected
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  VerificationRequest({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory VerificationRequest.fromMap(Map<String, dynamic> map, String id) {
    return VerificationRequest(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      reviewedBy: map['reviewedBy'],
      reviewedAt: map['reviewedAt'] != null
          ? (map['reviewedAt'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'reason': reason,
      'status': status,
      'createdAt': createdAt,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt,
    };
  }
}

class SuspensionAppeal {
  final String id;
  final String userId;
  final String username;
  final String reason;
  final String status; // pending, approved, rejected
  final DateTime createdAt;

  SuspensionAppeal({
    required this.id,
    required this.userId,
    required this.username,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory SuspensionAppeal.fromMap(Map<String, dynamic> map, String id) {
    return SuspensionAppeal(
      id: id,
      userId: map['userId'] ?? '',
      username: map['username'] ?? '',
      reason: map['reason'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as dynamic).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'reason': reason,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
