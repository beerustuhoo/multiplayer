import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService api;
  final SocketService socket;

  UserModel? _user;
  String? _token;
  bool _isLoading = true;
  String? _error;
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  AuthProvider({required this.api, required this.socket}) {
    _restoreSession();
  }

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _user != null;
  String? get error => _error;

  Future<void> _restoreSession() async {
    try {
      await _firebaseAuth.authStateChanges().first;
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('auth_token');
      if (saved != null) {
        _token = saved;
        api.setToken(saved);
        final res = await api.getMe();
        if (res.containsKey('user')) {
          _user = UserModel.fromJson(res['user'] as Map<String, dynamic>);
          await socket.connect(saved);
        } else {
          await _clearSession();
        }
      }
    } catch (_) {
      await _clearSession();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> register(String email, String password, String username) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
          email: email, password: password);
      await _firebaseAuth.currentUser?.sendEmailVerification();
      final idToken = await _firebaseAuth.currentUser?.getIdToken();
      if (idToken == null) {
        _error = 'Unable to retrieve Firebase token';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final res = await api.firebaseSync(idToken, username: username);
      if (res.containsKey('error')) {
        if (res.containsKey('details')) {
          _error = (res['details'] as List).join('\n');
        } else {
          _error = res['error'] as String;
        }
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _token = res['token'] as String;
      _user = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      api.setToken(_token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await socket.connect(_token!);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Registration failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
          email: email, password: password);
      final idToken = await _firebaseAuth.currentUser?.getIdToken(true);
      if (idToken == null) {
        _error = 'Unable to retrieve Firebase token';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final res = await api.firebaseSync(idToken);
      if (res.containsKey('error')) {
        _error = res['error'] as String;
        _isLoading = false;
        notifyListeners();
        return false;
      }
      _token = res['token'] as String;
      _user = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      api.setToken(_token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      await socket.connect(_token!);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Login failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyEmail() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      final current = _firebaseAuth.currentUser;
      if (current == null || !current.emailVerified) {
        _error = 'Email not verified yet. Check your inbox and refresh.';
        notifyListeners();
        return false;
      }
      final idToken = await current.getIdToken(true);
      if (idToken == null) {
        _error = 'Unable to retrieve Firebase token';
        notifyListeners();
        return false;
      }
      final res = await api.firebaseSync(idToken);
      _token = res['token'] as String;
      _user = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      api.setToken(_token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', _token!);
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseAuthError(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Verification failed. Try resending the email.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendVerification() async {
    try {
      await _firebaseAuth.currentUser?.sendEmailVerification();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseAuthError(e);
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Failed to resend verification email.';
      notifyListeners();
      return false;
    }
  }

  Future<String?> forgotPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return 'If the email exists, a reset email has been sent';
    } on FirebaseAuthException catch (e) {
      _error = _mapFirebaseAuthError(e);
      notifyListeners();
      return _error;
    } catch (_) {
      return 'Connection error';
    }
  }

  Future<bool> resetPassword(
      String email, String token, String newPassword) async {
    _error = 'Password reset is handled via the email link sent by Firebase.';
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    socket.disconnect();
    await _firebaseAuth.signOut();
    await _clearSession();
    notifyListeners();
  }

  Future<void> _clearSession() async {
    _token = null;
    _user = null;
    api.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
}
