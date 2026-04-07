import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;
import '../models/user_model.dart';
import '../models/verification_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<UserModel?> userStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists) return UserModel.fromMap(doc.data()!, doc.id);
      return null;
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) return UserModel.fromMap(doc.data()!, doc.id);
    return null;
  }

  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final q = query.toLowerCase().trim();
    final results = await _firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: q)
        .where('username', isLessThan: '${q}z')
        .limit(20)
        .get();

    return results.docs
        .map((doc) => UserModel.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? username,
    String? bio,
  }) async {
    final Map<String, dynamic> updates = {};
    if (displayName != null) updates['displayName'] = displayName;
    if (username != null) updates['username'] = username.toLowerCase();
    if (bio != null) updates['bio'] = bio;

    await _firestore.collection('users').doc(uid).update(updates);
  }

  /// Compress image to WebP base64 and store in Firestore
  Future<void> updateProfilePhoto({
    required String uid,
    required Uint8List imageBytes,
  }) async {
    // Decode image
    img.Image? decoded = img.decodeImage(imageBytes);
    if (decoded == null) throw Exception('Could not decode image');

    // Resize to max 256x256 to keep Firestore document small
    decoded = img.copyResize(decoded, width: 256, height: 256);

    // Encode as WebP with quality 70 for high compression
    final compressed = img.encodeJpg(decoded, quality: 60);

    // Base64 encode
    final base64Str = base64Encode(compressed);

    await _firestore.collection('users').doc(uid).update({
      'photoBase64': base64Str,
    });
  }

  Future<void> updateLastSeen(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<void> changePassword({
    required String currentEmail,
    required String newPassword,
  }) async {
    // Handled via FirebaseAuth in settings screen
  }

  // ---- Verification ----
  Future<void> requestVerification({
    required String userId,
    required String username,
    required String displayName,
    required String reason,
  }) async {
    await _firestore.collection('verification_requests').add({
      'userId': userId,
      'username': username,
      'displayName': displayName,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<VerificationRequest>> getVerificationRequests() {
    return _firestore
        .collection('verification_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => VerificationRequest.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> reviewVerification({
    required String requestId,
    required String userId,
    required bool approve,
    required String reviewerId,
  }) async {
    final batch = _firestore.batch();

    batch.update(
      _firestore.collection('verification_requests').doc(requestId),
      {
        'status': approve ? 'approved' : 'rejected',
        'reviewedBy': reviewerId,
        'reviewedAt': FieldValue.serverTimestamp(),
      },
    );

    if (approve) {
      batch.update(
        _firestore.collection('users').doc(userId),
        {'isVerified': true},
      );
    }

    await batch.commit();
  }

  // ---- Suspension ----
  Future<void> suspendUser(String uid) async {
    await _firestore.collection('users').doc(uid).update({'isSuspended': true});
  }

  Future<void> unsuspendUser(String uid) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'isSuspended': false});
  }

  Future<void> submitSuspensionAppeal({
    required String userId,
    required String username,
    required String reason,
  }) async {
    await _firestore.collection('suspension_appeals').add({
      'userId': userId,
      'username': username,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<SuspensionAppeal>> getSuspensionAppeals() {
    return _firestore
        .collection('suspension_appeals')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SuspensionAppeal.fromMap(d.data(), d.id))
            .toList());
  }

  Future<void> reviewSuspensionAppeal({
    required String appealId,
    required String userId,
    required bool approve,
  }) async {
    final batch = _firestore.batch();
    batch.update(
      _firestore.collection('suspension_appeals').doc(appealId),
      {'status': approve ? 'approved' : 'rejected'},
    );
    if (approve) {
      batch.update(
        _firestore.collection('users').doc(userId),
        {'isSuspended': false},
      );
    }
    await batch.commit();
  }

  // ---- Admin ----
  Stream<List<UserModel>> getAllUsers() {
    return _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList());
  }

  Future<void> setAdminStatus(String uid, bool isAdmin) async {
    await _firestore.collection('users').doc(uid).update({'isAdmin': isAdmin});
  }

  Future<void> deleteUserData(String uid) async {
    await _firestore.collection('users').doc(uid).delete();
  }
}
