import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LinkUpAuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  StreamSubscription? _userDataSub;

  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;

  LinkUpAuthProvider() {
    _auth.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    _currentUser = user;
    _userDataSub?.cancel();

    if (user != null) {
      // Set online status
      _db.doc('users/${user.uid}').set({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});

      // Listen to user data
      _userDataSub = _db.doc('users/${user.uid}').snapshots().listen((snap) {
        if (snap.exists) {
          _userData = snap.data();
          notifyListeners();
        }
      });
    } else {
      _userData = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setOffline() async {
    if (_currentUser != null) {
      await _db.doc('users/${_currentUser!.uid}').set({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});
    }
  }

  Future<void> signOut() async {
    await setOffline();
    await _auth.signOut();
  }

  @override
  void dispose() {
    _userDataSub?.cancel();
    super.dispose();
  }
}
