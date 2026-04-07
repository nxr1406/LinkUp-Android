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
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .update({'lastSeen': FieldValue.serverTimestamp()});

    final doc = await _firestore
        .collection('users')
        .doc(credential.user!.uid)
        .get();

    if (doc.exists) {
      final user = UserModel.fromMap(doc.data()!, doc.id);
      if (user.isSuspended) {
        await _auth.signOut();
        throw Exception('Your account has been suspended.');
      }
      return user;
    }
    return null;
  }

  Future<void> signOut() async {
    if (_auth.currentUser != null) {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'lastSeen': FieldValue.serverTimestamp()});
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<UserModel?> getCurrentUserModel() async {
    if (_auth.currentUser == null) return null;
    final doc = await _firestore
        .collection('users')
        .doc(_auth.currentUser!.uid)
        .get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }
}
