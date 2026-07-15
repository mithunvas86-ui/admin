import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// State + actions for the whole subscription section of the admin panel:
/// approvals, members, the subscription KDS, delivery assignment, and the
/// no-code editors (plans / banners / WhatsApp templates / credentials).
///
/// Privileged actions (create login, remove member…) go through the
/// `admin-manage-member` edge function, which re-verifies the caller's role
/// server-side — the client role check is only for UX.
class SubscriptionAdminProvider extends ChangeNotifier {
  final _client = SupabaseService.client;

  bool isLoading = false;
  String? error;

  List<Map<String, dynamic>> pending = [];
  List<Map<String, dynamic>> members = [];
  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> banners = [];
  List<Map<String, dynamic>> templates = [];
  List<Map<String, dynamic>> agents = [];
  List<Map<String, dynamic>> meals = []; // meal_confirmations for [kdsDate]

  /// The date the kitchen is looking at (defaults to today).
  DateTime kdsDate = DateTime.now();

  Timer? _refreshTimer;

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Fetchers ───────────────────────────────────────────────────────────────

  Future<void> fetchSubscriptions() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final rows = await _client
          .from('subscriptions')
          .select('*, subscription_plans(name,duration_days,meals_per_day,price)')
          .inFilter('status',
              ['pending_approval', 'active', 'paused', 'payment_received'])
          .order('created_at', ascending: false);
      final all = (rows as List).cast<Map<String, dynamic>>();
      pending = all
          .where((s) =>
              s['status'] == 'pending_approval' ||
              s['status'] == 'payment_received')
          .toList();
      members = all
          .where((s) => s['status'] == 'active' || s['status'] == 'paused')
          .toList();
    } catch (e) {
      error = 'Could not load subscriptions: $e';
    }
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchMeals() async {
    try {
      final rows = await _client
          .from('meal_confirmations')
          .select(
              '*, subscriptions(customer_name,phone,food_preference,health_goal,health_notes,delivery_address,member_code, subscription_plans(name,meals_per_day)), delivery_agents(name)')
          .eq('meal_date', _d(kdsDate))
          .order('priority', ascending: false)
          .order('created_at');
      meals = (rows as List).cast<Map<String, dynamic>>();
      error = null;
    } catch (e) {
      error = 'Could not load meals: $e';
    }
    notifyListeners();
  }

  void setKdsDate(DateTime d) {
    kdsDate = d;
    fetchMeals();
  }

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 20), (_) => fetchMeals());
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

  Future<void> fetchEditors() async {
    try {
      final results = await Future.wait([
        _client.from('subscription_plans').select().order('sort_order'),
        _client.from('subscription_banners').select().order('sort_order'),
        _client.from('whatsapp_templates').select().order('title'),
        _client.from('delivery_agents').select().order('name'),
      ]);
      plans = (results[0] as List).cast<Map<String, dynamic>>();
      banners = (results[1] as List).cast<Map<String, dynamic>>();
      templates = (results[2] as List).cast<Map<String, dynamic>>();
      agents = (results[3] as List).cast<Map<String, dynamic>>();
      error = null;
    } catch (e) {
      error = 'Could not load settings: $e';
    }
    notifyListeners();
  }

  // ── Member lifecycle (edge function — server re-checks the role) ──────────

  Future<String?> _manage(Map<String, dynamic> body) async {
    try {
      final res =
          await _client.functions.invoke('admin-manage-member', body: body);
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (data['ok'] == true) return null;
      return data['error']?.toString() ?? 'Action failed';
    } catch (e) {
      final msg = e.toString();
      // FunctionsHttpError carries the server's message in details.
      return msg.length > 160 ? 'Action failed — check logs' : msg;
    }
  }

  Future<String?> approve({
    required String subscriptionId,
    required String email,
    required String password,
  }) async {
    final err = await _manage({
      'action': 'approve',
      'subscription_id': subscriptionId,
      'email': email,
      'password': password,
    });
    if (err == null) await fetchSubscriptions();
    return err;
  }

  Future<String?> reject(String subscriptionId, String reason) async {
    final err = await _manage({
      'action': 'reject',
      'subscription_id': subscriptionId,
      'reason': reason,
    });
    if (err == null) await fetchSubscriptions();
    return err;
  }

  Future<String?> removeMember(String subscriptionId) async {
    final err = await _manage({
      'action': 'remove',
      'subscription_id': subscriptionId,
    });
    if (err == null) await fetchSubscriptions();
    return err;
  }

  Future<String?> addMember(Map<String, dynamic> fields) async {
    final err = await _manage({'action': 'add_manual', ...fields});
    if (err == null) await fetchSubscriptions();
    return err;
  }

  Future<String?> resetPassword(String subscriptionId, String password) =>
      _manage({
        'action': 'reset_password',
        'subscription_id': subscriptionId,
        'password': password,
      });

  // ── KDS / delivery actions (RLS: staff update) ─────────────────────────────

  Future<void> updateMeal(String id, Map<String, dynamic> fields) async {
    try {
      await _client
          .from('meal_confirmations')
          .update({...fields, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);
      await fetchMeals();
    } catch (e) {
      error = 'Update failed: $e';
      notifyListeners();
    }
  }

  Future<void> setMealStatus(String id, String status) {
    final fields = <String, dynamic>{'status': status};
    if (status == 'prepared') {
      fields['prepared_at'] = DateTime.now().toIso8601String();
    }
    if (status == 'delivered') {
      fields['delivered_at'] = DateTime.now().toIso8601String();
    }
    return updateMeal(id, fields);
  }

  Future<void> setPriority(String id, int priority) =>
      updateMeal(id, {'priority': priority});

  Future<void> assignAgent(String id, String? agentId) =>
      updateMeal(id, {'delivery_agent_id': agentId});

  // ── Delivery agents ────────────────────────────────────────────────────────

  Future<void> addAgent(String name, String phone) async {
    try {
      await _client.from('delivery_agents').insert({
        'name': name,
        'phone': phone,
      });
      await fetchEditors();
    } catch (e) {
      error = 'Could not add agent: $e';
      notifyListeners();
    }
  }

  Future<void> toggleAgent(String id, bool active) async {
    try {
      await _client
          .from('delivery_agents')
          .update({'active': active}).eq('id', id);
      await fetchEditors();
    } catch (_) {}
  }

  // ── No-code editors ────────────────────────────────────────────────────────

  Future<String?> savePlan(Map<String, dynamic> plan) async {
    try {
      final data = Map<String, dynamic>.from(plan);
      final id = data.remove('id');
      data['updated_at'] = DateTime.now().toIso8601String();
      if (id == null) {
        await _client.from('subscription_plans').insert(data);
      } else {
        await _client.from('subscription_plans').update(data).eq('id', id);
      }
      await fetchEditors();
      return null;
    } catch (e) {
      return 'Could not save plan: $e';
    }
  }

  Future<String?> saveBanner(Map<String, dynamic> banner) async {
    try {
      final data = Map<String, dynamic>.from(banner);
      final id = data.remove('id');
      if (id == null) {
        await _client.from('subscription_banners').insert(data);
      } else {
        await _client.from('subscription_banners').update(data).eq('id', id);
      }
      await fetchEditors();
      return null;
    } catch (e) {
      return 'Could not save banner: $e';
    }
  }

  Future<void> deleteBanner(String id) async {
    try {
      await _client.from('subscription_banners').delete().eq('id', id);
      await fetchEditors();
    } catch (_) {}
  }

  Future<String?> saveTemplate(String id, String text, bool active) async {
    try {
      await _client.from('whatsapp_templates').update({
        'message_text': text,
        'active': active,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', id);
      await fetchEditors();
      return null;
    } catch (e) {
      return 'Could not save template: $e';
    }
  }

  // ── WhatsApp credentials (app_config) ──────────────────────────────────────

  Future<Map<String, dynamic>> loadWhatsAppConfig() async {
    try {
      final row = await _client
          .from('app_config')
          .select('value')
          .eq('key', 'whatsapp_credentials')
          .maybeSingle();
      return (row?['value'] as Map?)?.cast<String, dynamic>() ?? {};
    } catch (_) {
      return {};
    }
  }

  Future<String?> saveWhatsAppConfig(Map<String, dynamic> value) async {
    try {
      await _client.from('app_config').upsert({
        'key': 'whatsapp_credentials',
        'value': value,
        'description': 'WhatsApp Business API credentials',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'key');
      return null;
    } catch (e) {
      return 'Could not save credentials: $e';
    }
  }

  /// Manual trigger of the nightly job ("Send now" in the panel).
  Future<String?> sendTonightNow() async {
    try {
      final res = await _client.functions
          .invoke('send-daily-meal-whatsapp', body: {'source': 'manual'});
      final data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      if (data['ok'] == true) {
        final sent = data['sent'] ?? 0;
        final n = data['members'] ?? 0;
        final cfg = data['configured'] == true;
        return cfg
            ? 'Done — $sent of $n members messaged.'
            : 'Meal rows created for $n members, but WhatsApp is NOT configured yet.';
      }
      return data['error']?.toString() ?? 'Job failed';
    } catch (e) {
      return 'Job failed: $e';
    }
  }
}
