import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AdminOrdersProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  Timer? _refreshTimer;

  /// Order ids seen on the previous fetch, used to detect newly arrived orders.
  Set<String> _knownOrderIds = {};

  /// True once the first fetch has established a baseline. The very first load
  /// must NOT fire [onNewOrder] for the orders that already exist.
  bool _baselineSet = false;

  /// Called when one or more brand-new (pending) orders appear between fetches.
  /// The KDS page uses this to play the kitchen notification sound.
  VoidCallback? onNewOrder;

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

      // Detect newly arrived orders. New orders are inserted as 'pending', so a
      // pending id we have not seen before means a fresh order just came in.
      final currentIds = _orders
          .map((o) => o['id']?.toString())
          .whereType<String>()
          .toSet();
      final hasNewPending = _orders.any((o) =>
          o['status'] == 'pending' &&
          !_knownOrderIds.contains(o['id']?.toString()));
      _knownOrderIds = currentIds;
      if (_baselineSet && hasNewPending) {
        onNewOrder?.call();
      }
      _baselineSet = true;
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
