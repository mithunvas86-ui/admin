import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

class GuestCustomer {
  final String name;
  final String phone;
  final DateTime createdAt;

  GuestCustomer({
    required this.name,
    required this.phone,
    required this.createdAt,
  });

  factory GuestCustomer.fromJson(Map<String, dynamic> json) {
    return GuestCustomer(
      name: json['customer_name'] as String? ?? '',
      phone: json['customer_phone'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CustomerInfoProvider extends ChangeNotifier {
  List<GuestCustomer> _customers = [];
  bool _isLoading = false;
  String? _error;

  List<GuestCustomer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCustomers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseService.client
          .from('orders')
          .select('customer_name, customer_phone, created_at')
          .order('created_at', ascending: false);

      // Deduplicate by phone number, keeping the most recent entry
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (final item in response as List) {
        final phone = item['customer_phone'] as String? ?? '';
        if (seen.add(phone)) {
          unique.add(item as Map<String, dynamic>);
        }
      }

      _customers = unique.map((item) => GuestCustomer.fromJson(item)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
}
