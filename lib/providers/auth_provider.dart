import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _userEmail;
  bool _isLoading = false;

  bool get isAuthenticated => _userEmail != null;
  String? get userEmail => _userEmail;
  bool get isLoading => _isLoading;

  // Try to restore session on init
  AuthProvider() {
    _checkExistingSession();
  }

  Future<void> _checkExistingSession() async {
    try {
      final session = SupabaseService.client.auth.currentSession;
      if (session != null) {
        _userEmail = session.user.email;
        notifyListeners();
      }
    } catch (e) {
      print('Error checking session: $e');
    }
  }

  Future<void> loginWithSupabase({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _userEmail = response.user!.email;
        notifyListeners();
      } else {
        throw Exception('Login failed');
      }
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('invalid') || msg.contains('credentials') || msg.contains('invalid_credentials')) {
        throw Exception('Incorrect email or password');
      }
      throw Exception('Login failed. Please try again.');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await SupabaseService.client.auth.signOut();
      _userEmail = null;
      notifyListeners();
    } catch (e) {
      throw Exception('Logout failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
