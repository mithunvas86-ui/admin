import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SharedOrdersService {
  static final _instance = SharedOrdersService._internal();
  late SharedPreferences _prefs;
  static const String _ordersKey = 'shared_all_orders';

  factory SharedOrdersService() {
    return _instance;
  }

  SharedOrdersService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Save order to shared orders list (accessible to admin)
  Future<void> saveOrderToShared({
    required String orderId,
    required Map<String, dynamic> orderData,
  }) async {
    try {
      List<String> allOrders = _prefs.getStringList(_ordersKey) ?? [];

      final order = {
        ...orderData,
        'id': orderId,
        'timestamp': DateTime.now().toIso8601String(),
      };

      allOrders.add(jsonEncode(order));
      await _prefs.setStringList(_ordersKey, allOrders);
      print('Order saved to shared storage: $orderId');
    } catch (e) {
      print('Error saving to shared storage: $e');
    }
  }

  /// Get all orders (for admin dashboard)
  List<Map<String, dynamic>> getAllOrders() {
    try {
      List<String> ordersJson = _prefs.getStringList(_ordersKey) ?? [];
      print('✅ Retrieved ${ordersJson.length} orders from shared storage');
      final orders = ordersJson
          .map((order) => jsonDecode(order) as Map<String, dynamic>)
          .toList()
          .cast<Map<String, dynamic>>();
      print('DEBUG: Orders loaded: ${orders.map((o) => o['id']).toList()}');
      return orders;
    } catch (e) {
      print('❌ Error getting orders: $e');
      return [];
    }
  }

  /// Get orders by status
  List<Map<String, dynamic>> getOrdersByStatus(String status) {
    try {
      final all = getAllOrders();
      return all.where((order) => order['status'] == status).toList();
    } catch (e) {
      print('Error filtering orders: $e');
      return [];
    }
  }

  /// Update order status
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      List<String> allOrders = _prefs.getStringList(_ordersKey) ?? [];

      allOrders = allOrders.map((orderJson) {
        final order = jsonDecode(orderJson) as Map<String, dynamic>;
        if (order['id'] == orderId) {
          order['status'] = newStatus;
          order['updated_at'] = DateTime.now().toIso8601String();
        }
        return jsonEncode(order);
      }).toList();

      await _prefs.setStringList(_ordersKey, allOrders);
      print('Order status updated: $orderId → $newStatus');
    } catch (e) {
      print('Error updating order status: $e');
    }
  }

  /// Get customer info from order
  Map<String, dynamic>? getCustomerInfo(String orderId) {
    try {
      final order = getAllOrders().firstWhere(
        (o) => o['id'] == orderId,
        orElse: () => {},
      );
      return order['customer_info'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Get total sales
  double getTotalSales() {
    try {
      final orders = getAllOrders();
      return orders.fold<double>(
        0,
        (sum, order) => sum + ((order['total_price'] as num?)?.toDouble() ?? 0),
      );
    } catch (e) {
      return 0;
    }
  }

  /// Get completed orders count
  int getCompletedOrdersCount() {
    try {
      return getOrdersByStatus('completed').length;
    } catch (e) {
      return 0;
    }
  }

  /// Get pending orders count
  int getPendingOrdersCount() {
    try {
      return getOrdersByStatus('pending').length;
    } catch (e) {
      return 0;
    }
  }

  /// Get preparing orders count
  int getPreparingOrdersCount() {
    try {
      return getOrdersByStatus('preparing').length;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all orders (for testing)
  Future<void> clearAllOrders() async {
    await _prefs.remove(_ordersKey);
    print('All shared orders cleared');
  }

  /// Debug: Print all orders
  void debugPrintAllOrders() {
    try {
      final orders = getAllOrders();
      print('=== DEBUG: Total Orders in Shared Storage: ${orders.length} ===');
      for (var i = 0; i < orders.length; i++) {
        final order = orders[i];
        print('Order $i: ${order['id']} - Status: ${order['status']} - Total: ${order['total_price']}');
      }
      print('=== END DEBUG ===');
    } catch (e) {
      print('Error debugging orders: $e');
    }
  }
}
