import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:linkup_chat_app/models/user_model.dart';
import 'package:linkup_chat_app/services/catbox_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final CatboxService _catboxService = CatboxService();

  Stream<User?> get user => _auth.authStateChanges();

  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    required String bio,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = result.user;
      if (user != null) {
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          username: username,
          bio: bio,
          createdAt: DateTime.now(),
          lastSeen: DateTime.now(),
          isOnline: true,
          blockedUsers: [],
          restrictedUsers: [],
        );

        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        return newUser;
      }
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
    return null;
  }

  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return await getUserData(result.user!.uid);
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        UserModel? existingUser = await getUserData(user.uid);
        
        if (existingUser == null) {
          UserModel newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            username: user.displayName ?? '',
            photoURL: user.photoURL,
            bio: '',
            createdAt: DateTime.now(),
            lastSeen: DateTime.now(),
            isOnline: true,
            blockedUsers: [],
            restrictedUsers: [],
          );
          await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
          return newUser;
        }
        return existingUser;
      }
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
    return null;
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
    } catch (e) {
      print('Error getting user data: $e');
    }
    return null;
  }

  Future<void> updateProfilePicture(String uid, String imagePath) async {
    try {
      String imageUrl = await _catboxService.uploadImage(imagePath);
      await _firestore.collection('users').doc(uid).update({
        'photoURL': imageUrl,
      });
    } catch (e) {
      print('Error updating profile picture: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile(String uid, {
    String? username,
    String? bio,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (username != null) updates['username'] = username;
      if (bio != null) updates['bio'] = bio;
      
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  Future<void> updateOnlineStatus(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      'lastSeen': isOnline ? null : FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() async {
    await updateOnlineStatus(_auth.currentUser!.uid, false);
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}