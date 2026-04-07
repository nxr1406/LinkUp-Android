import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    // Check username uniqueness
    final usernameQuery = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.toLowerCase())
        .get();

    if (usernameQuery.docs.isNotEmpty) {
      throw Exception('Username already taken');
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = UserModel(
      uid: credential.user!.uid,
      username: username.toLowerCase(),
      displayName: displayName,
      email: email,
      isVerified: false,
      isAdmin: false,
      isSuspended: false,
      createdAt: DateTime.now(),
      lastSeen: DateTime.now(),
    );

    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .set(user.toMap());

    return user;
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    // Step 1: Firebase Auth sign in
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = credential.user!.uid;

    // Step 2: Update lastSeen — non-fatal, don't block login on failure
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .update({'lastSeen': FieldValue.serverTimestamp()});
    } catch (_) {
      // Ignore — user may not have a Firestore doc yet or offline
    }

    // Step 3: Check suspension — also non-fatal if Firestore unavailable
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!, doc.id);
        if (user.isSuspended) {
          await _auth.signOut();
          throw Exception('Your account has been suspended.');
        }
        return user;
      }
    } catch (e) {
      // If it's a suspension error, rethrow it
      if (e.toString().contains('suspended')) rethrow;
      // Otherwise ignore Firestore errors — Auth succeeded, stream will navigate
    }

    // Auth succeeded; AuthWrapper will navigate via authStateChanges
    return null;
  }

  Future<void> signOut() async {
    try {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({'lastSeen': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserModel?> getCurrentUserModel() async {
    if (_auth.currentUser == null) return null;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
    } catch (_) {}
    return null;
  }
}
