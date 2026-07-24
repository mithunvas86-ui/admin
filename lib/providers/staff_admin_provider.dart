import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

/// Staff access management: invite/revoke/reactivate logins and reset
/// passwords for `profiles` rows with a staff role (not subscription
/// `member` accounts — those live on the Members page).
///
/// Role-only edits go straight to `profiles` (RLS already restricts writes
/// to admins). Anything touching the actual login — create, ban, password —
/// goes through the `admin-manage-staff` edge function, which re-checks the
/// caller is an admin server-side.
class StaffAdminProvider extends ChangeNotifier {
  final _client = SupabaseService.client;

  static const staffRoles = [
    'admin', 'gym_manager', 'sub_manager',
    'gym_chef', 'gym_delivery', 'subs_chef', 'subs_delivery',
  ];

  bool isLoading = false;
  String? error;
  List<Map<String, dynamic>> staff = [];

  Future<void> fetchStaff() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await _client
          .from('profiles')
          .select()
          .order('email');
      staff = (rows as List)
          .cast<Map<String, dynamic>>()
          // A null role means a revoked staff account (member accounts
          // always keep role='member', so null only ever means "was staff").
          .where((p) => p['role'] == null || staffRoles.contains(p['role']))
          .toList();
      error = null;
    } catch (e) {
      error = 'Could not load staff: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<String?> _manage(Map<String, dynamic> body) async {
    try {
      final res =
          await _client.functions.invoke('admin-manage-staff', body: body);
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (data['ok'] == true) return null;
      return data['error']?.toString() ?? 'Action failed';
    } catch (e) {
      final msg = e.toString();
      return msg.length > 160 ? 'Action failed — check logs' : msg;
    }
  }

  Future<String?> invite({
    required String email,
    required String password,
    required String role,
  }) async {
    final err = await _manage({
      'action': 'invite',
      'email': email,
      'password': password,
      'role': role,
    });
    if (err == null) await fetchStaff();
    return err;
  }

  Future<String?> revoke(String profileId) async {
    final err = await _manage({'action': 'revoke', 'profile_id': profileId});
    if (err == null) await fetchStaff();
    return err;
  }

  Future<String?> reactivate(String profileId, String role) async {
    final err = await _manage({
      'action': 'reactivate',
      'profile_id': profileId,
      'role': role,
    });
    if (err == null) await fetchStaff();
    return err;
  }

  Future<String?> resetPassword(String profileId, String password) =>
      _manage({
        'action': 'reset_password',
        'profile_id': profileId,
        'password': password,
      });

  /// Change an existing staff member's role directly (no login change, so
  /// no need to go through the edge function — RLS already gates this to
  /// admins).
  Future<String?> changeRole(String profileId, String role) async {
    try {
      await _client.from('profiles').update({'role': role}).eq('id', profileId);
      await fetchStaff();
      return null;
    } catch (e) {
      return 'Could not update role: $e';
    }
  }
}
