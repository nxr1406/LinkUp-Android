import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    // Step 1: Create Firebase Auth account first (so request.auth exists)
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);

    try {
      // Step 2: Now check username uniqueness (auth exists → Firestore read allowed)
      final q = await _db
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .get();
      if (q.docs.isNotEmpty) {
        // Username taken → delete the auth account we just created, then throw
        await cred.user!.delete();
        throw Exception('Username already taken');
      }

      final user = UserModel(
        uid: cred.user!.uid,
        username: username.toLowerCase(),
        displayName: displayName,
        email: email,
        role: 'user',
        isVerified: false,
        isAdmin: false,
        isSuspended: false,
        createdAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );

    await _db.collection('users').doc(cred.user!.uid).set(user.toMap());
      return user;
    } catch (e) {
      // If anything after auth creation fails, clean up the auth account
      try { await cred.user!.delete(); } catch (_) {}
      rethrow;
    }
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    // ── Step 1: Firebase Auth ─────────────────────────────────
    final cred = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    final uid = cred.user!.uid;

    // ── Step 2: online status + lastSeen ─────────────────────────
    _db.collection('users').doc(uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    }).catchError((_) {});

    // ── Step 3: Suspension check (non-blocking on Firestore fail) ──
    try {
      final doc = await _db.collection('users').doc(uid).get()
          .timeout(const Duration(seconds: 5));
      if (doc.exists) {
        final user = UserModel.fromMap(doc.data()!, doc.id);
        if (user.isSuspended) {
          await _auth.signOut();
          throw Exception('SUSPENDED');
        }
        return user;
      }
    } catch (e) {
      if (e.toString().contains('SUSPENDED')) rethrow;
      // Firestore timeout or offline → Auth still succeeded,
      // authStateChanges will trigger navigation
    }
    return null;
  }

  Future<void> signOut() async {
    try {
      if (_auth.currentUser != null) {
        await _db.collection('users').doc(_auth.currentUser!.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {}
    await _auth.signOut();
  }

  /// Call on app resume / foreground
  Future<void> setOnline(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Call on app pause / background / dispose
  Future<void> setOffline(String uid) async {
    try {
      await _db.collection('users').doc(uid).update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
