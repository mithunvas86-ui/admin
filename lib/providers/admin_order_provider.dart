import 'package:flutter/material.dart';
import '../services/shared_orders_service.dart';

class AdminOrderProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  final _sharedOrders = SharedOrdersService();
  bool _initialized = false;

  List<Map<String, dynamic>> get orders => _orders;
  bool get isLoading => _isLoading;

  // Delayed initialization to ensure SharedPreferences is ready
  Future<void> initialize() async {
    if (_initialized) return;
    await Future.delayed(const Duration(milliseconds: 500));
    _initialized = true;
    await fetchOrders();
    print('✅ AdminOrderProvider initialized and orders fetched');
  }

  Future<void> fetchOrders() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Get orders from shared storage
      _orders = _sharedOrders.getAllOrders();
      // Sort by created_at descending
      _orders.sort((a, b) =>
          DateTime.parse(b['created_at'] as String)
              .compareTo(DateTime.parse(a['created_at'] as String)));
    } catch (e) {
      print('Error fetching orders: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _sharedOrders.updateOrderStatus(orderId, newStatus);
      await fetchOrders();
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  int get totalOrders => _orders.length;
  int get pendingOrders => _orders.where((o) => o['status'] == 'pending').length;
  int get preparingOrders => _orders.where((o) => o['status'] == 'preparing').length;
  int get completedOrders => _orders.where((o) => o['status'] == 'completed').length;

  double get totalSales {
    return _orders.fold<double>(
      0.0,
      (sum, order) => sum + ((order['total_price'] as num?)?.toDouble() ?? 0.0),
    );
  }
}
