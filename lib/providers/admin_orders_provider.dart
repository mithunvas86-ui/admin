import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AdminOrdersProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;

  void startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchOrders();
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('*')
          .order('created_at', ascending: false);

      _orders = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching orders: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await SupabaseService.client
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);

      await fetchOrders();
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  int get totalOrders => _orders.length;
  int get pendingOrders => _orders.where((o) => o['status'] == 'pending').length;
  int get preparingOrders => _orders.where((o) => o['status'] == 'preparing').length;
  int get completedOrders => _orders.where((o) => o['status'] == 'completed').length;

  double get totalSales {
    return _orders.fold(0.0, (sum, order) => sum + (order['total_price'] ?? 0.0));
  }
}
