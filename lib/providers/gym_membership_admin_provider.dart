import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// Gold membership management for the gym-model admin side — deliberately
/// separate from SubscriptionAdminProvider (Elite) to keep the two models'
/// admin state independent, same as their tables/RLS/roles already are.
class GymMembershipAdminProvider extends ChangeNotifier {
  final _client = SupabaseService.client;

  List<Map<String, dynamic>> plans = [];
  List<Map<String, dynamic>> memberships = [];
  bool isLoading = false;

  Future<void> fetchAll() async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _client.from('gym_membership_plans').select().order('sort_order'),
        _client
            .from('gym_memberships')
            .select('*, gym_membership_plans(name)')
            .eq('status', 'active')
            .order('created_at', ascending: false),
      ]);
      plans = (results[0] as List).cast<Map<String, dynamic>>();
      memberships = (results[1] as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // shown as empty state
    }
    isLoading = false;
    notifyListeners();
  }

  Future<String?> savePlan(Map<String, dynamic> plan) async {
    try {
      final data = Map<String, dynamic>.from(plan);
      final id = data.remove('id');
      data['updated_at'] = DateTime.now().toIso8601String();
      if (id == null) {
        await _client.from('gym_membership_plans').insert(data);
      } else {
        await _client.from('gym_membership_plans').update(data).eq('id', id);
      }
      await fetchAll();
      return null;
    } catch (e) {
      return 'Could not save plan: $e';
    }
  }
}
