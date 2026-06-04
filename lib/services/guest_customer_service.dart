import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Guest Customer tracking service for admin - reads customer data saved by user app
class AdminGuestCustomerService {
  static const String _customersKey = 'shared_guest_customers';
  late SharedPreferences _prefs;

  AdminGuestCustomerService();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get all guest customers saved by user app
  List<Map<String, dynamic>> getAllCustomers() {
    try {
      List<String> customersJson = _prefs.getStringList(_customersKey) ?? [];
      print('✅ Retrieved ${customersJson.length} guest customers');
      return customersJson
          .map((customer) => jsonDecode(customer) as Map<String, dynamic>)
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (e) {
      print('❌ Error getting customers: $e');
      return [];
    }
  }

  /// Get total customers
  int getTotalCustomers() {
    try {
      return getAllCustomers().length;
    } catch (e) {
      return 0;
    }
  }

  /// Get total customer spending
  double getTotalCustomerSpending() {
    try {
      final customers = getAllCustomers();
      return customers.fold<double>(
        0.0,
        (sum, customer) => sum + ((customer['total_spent'] as num?)?.toDouble() ?? 0.0),
      );
    } catch (e) {
      return 0.0;
    }
  }

  /// Export customers as CSV
  String exportCustomersAsCSV() {
    try {
      final customers = getAllCustomers();
      final header = 'ID,Name,Phone,Email,Order Type,Total Spent,Created At\n';
      
      final rows = customers.map((c) {
        return [
          c['id'] ?? '',
          c['name'] ?? '',
          c['phone'] ?? '',
          c['email'] ?? '',
          c['order_type'] ?? '',
          c['total_spent'] ?? '0',
          c['created_at'] ?? '',
        ].map((v) => '"$v"').join(',');
      }).join('\n');

      return header + rows;
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Export customers as JSON
  String exportCustomersAsJson() {
    try {
      final customers = getAllCustomers();
      return jsonEncode({
        'total_customers': customers.length,
        'total_spent': getTotalCustomerSpending(),
        'export_date': DateTime.now().toIso8601String(),
        'customers': customers,
      });
    } catch (e) {
      return '{"error": "$e"}';
    }
  }
}
