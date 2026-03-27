import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _currentUser;
  UserModel? _userData;
  bool _loading = true;

  StreamSubscription? _authSub;
  StreamSubscription? _userDataSub;

  User? get currentUser => _currentUser;
  UserModel? get userData => _userData;
  bool get loading => _loading;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authSub = _auth.authStateChanges().listen((user) async {
      _currentUser = user;
      _userDataSub?.cancel();

      if (user != null) {
        // Listen to user document
        _userDataSub = _db.collection('users').doc(user.uid).snapshots().listen(
          (doc) {
            if (doc.exists) {
              _userData = UserModel.fromDoc(doc);
              notifyListeners();
            }
          },
          onError: (e) => debugPrint('Error fetching user data: $e'),
        );

        // Mark online
        try {
          await _db.collection('users').doc(user.uid).update({
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error updating online status: $e');
        }

        // Cleanup expired messages (async)
        _cleanupExpiredMessages(user.uid);
      } else {
        _userData = null;
      }

      _loading = false;
      notifyListeners();
    });
  }

  Future<void> setOffline() async {
    if (_currentUser != null) {
      try {
        await _db.collection('users').doc(_currentUser!.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error setting offline: $e');
      }
    }
  }

  Future<void> setOnline() async {
    if (_currentUser != null) {
      try {
        await _db.collection('users').doc(_currentUser!.uid).update({
          'isOnline': true,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Error setting online: $e');
      }
    }
  }

  Future<void> _cleanupExpiredMessages(String uid) async {
    try {
      final chatsSnap = await _db
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      final now = DateTime.now();
      for (final chatDoc in chatsSnap.docs) {
        final msgsSnap = await _db
            .collection('messages')
            .doc(chatDoc.id)
            .collection('msgs')
            .where('expiresAt', isLessThanOrEqualTo: Timestamp.fromDate(now))
            .get();

        if (msgsSnap.docs.isNotEmpty) {
          final batch = _db.batch();
          for (final msg in msgsSnap.docs) {
            batch.delete(msg.reference);
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('Cleanup failed: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDataSub?.cancel();
    super.dispose();
  }
}
