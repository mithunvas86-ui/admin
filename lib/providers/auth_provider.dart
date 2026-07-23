import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  String? _userEmail;
  bool _isLoading = false;

  bool get isAuthenticated => _userEmail != null;
  String? get userEmail => _userEmail;
  bool get isLoading => _isLoading;

  String? _role;
  String? get role => _role;

  // Whether an 'admin' has picked Gym/Subscription on /choose-model yet this
  // session. Starts false on every fresh app load (and on logout), so the
  // chooser reappears on the next real login regardless of how the admin
  // ends up authenticated — not just via the /login-page transition.
  bool _modelChosen = false;
  bool get hasChosenModel => _modelChosen;
  void chooseModel() {
    _modelChosen = true;
    notifyListeners();
  }

  // Where this user should land / be confined to. Exhaustive on purpose —
  // anything not explicitly listed (including a retired 'chef'/'delivery'
  // value, null, or garbage) sends them back to login rather than a live
  // page; the router's _authGuard fail-closed branch signs them out before
  // this is ever reached with an unrecognized role.
  String get homeRoute {
    switch (_role) {
      case 'admin':
        return '/choose-model';
      case 'gym_manager':
        return '/';
      case 'sub_manager':
        return '/subs';
      case 'gym_chef':
        return '/kds';
      case 'gym_delivery':
        return '/orders';
      case 'subs_chef':
        return '/subs-kitchen';
      case 'subs_delivery':
        return '/subs-delivery';
      default:
        return '/login';
    }
  }

  Future<void> _loadRole() async {
    try {
      final uid = SupabaseService.client.auth.currentUser?.id;
      if (uid == null) {
        _role = null;
        return;
      }
      final res = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', uid)
          .maybeSingle();
      _role = res?['role'] as String?;
    } catch (_) {
      _role = null;
    }
  }

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
        await _loadRole();
      } catch (_) {
        await SupabaseService.client.auth.signOut();
        _userEmail = null;
        _role = null;
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
      await _loadRole();
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
      _role = null;
      _modelChosen = false;
      notifyListeners();
    } catch (e) {
      throw Exception('Logout failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// Shared instance — used by both the widget tree and the router's
/// refreshListenable so role-based redirects fire as soon as the role loads.
final adminAuth = AuthProvider();
