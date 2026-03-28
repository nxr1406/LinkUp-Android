import 'package:flutter/material.dart';
import 'package:linkup_chat_app/models/user_model.dart';
import 'package:linkup_chat_app/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.user.listen((user) async {
      if (user != null) {
        _currentUser = await _authService.getUserData(user.uid);
        notifyListeners();
      } else {
        _currentUser = null;
        notifyListeners();
      }
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    required String bio,
  }) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.signUpWithEmail(
        email: email,
        password: password,
        username: username,
        bio: bio,
      );
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      _currentUser = await _authService.signInWithEmail(
        email: email,
        password: password,
      );
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    _setLoading(true);
    try {
      _currentUser = await _authService.signInWithGoogle();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateProfilePicture(String imagePath) async {
    if (_currentUser != null) {
      await _authService.updateProfilePicture(_currentUser!.uid, imagePath);
      _currentUser = await _authService.getUserData(_currentUser!.uid);
      notifyListeners();
    }
  }

  Future<void> updateProfile({
    String? username,
    String? bio,
  }) async {
    if (_currentUser != null) {
      await _authService.updateUserProfile(
        _currentUser!.uid,
        username: username,
        bio: bio,
      );
      _currentUser = await _authService.getUserData(_currentUser!.uid);
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}