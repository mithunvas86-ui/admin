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
      if (session == null) return;
      try {
        // Validate the stored session. If the refresh token is dead (e.g. the
        // user was deleted/recreated), this throws — so we sign out rather than
        // keep sending an invalid token that makes EVERY query return 401/empty.
        await SupabaseService.client.auth.refreshSession();
        _userEmail = SupabaseService.client.auth.currentSession?.user.email;
      } catch (_) {
        await SupabaseService.client.auth.signOut();
        _userEmail = null;
      }
      notifyListeners();
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

      // A real login MUST return a session — if it's null, there's no token,
      // so every later query would run as anonymous (and RLS hides everything).
      if (response.session == null) {
        throw Exception(
            'No session returned — the account is likely unconfirmed. '
            'Turn off "Confirm email" or auto-confirm the user.');
      }
      _userEmail = response.user?.email;
      notifyListeners();
    } catch (e) {
      // Surface the REAL reason (e.g. "Email not confirmed",
      // "Invalid login credentials") instead of a generic message.
      final raw = e
          .toString()
          .replaceAll('AuthException: ', '')
          .replaceAll('Exception: ', '')
          .trim();
      throw Exception(raw.isEmpty ? 'Login failed' : raw);
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
