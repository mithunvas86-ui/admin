import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static String _getUrl() {
    try {
      if (!kIsWeb && dotenv.isInitialized) {
        return dotenv.env['SUPABASE_URL'] ??
            'https://pahanghosyepfuwcfexg.supabase.co';
      }
    } catch (_) {}
    return 'https://pahanghosyepfuwcfexg.supabase.co';
  }

  static String _getAnonKey() {
    try {
      if (!kIsWeb && dotenv.isInitialized) {
        return dotenv.env['SUPABASE_ANON_KEY'] ??
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhaGFuZ2hvc3llcGZ1d2NmZXhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwNjI3NTQsImV4cCI6MjA5NTYzODc1NH0.HQpxZSWo0Um1JDZuSZpzHQnDDpSzC5-XiaNPyT-12MI';
      }
    } catch (_) {}
    return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBhaGFuZ2hvc3llcGZ1d2NmZXhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAwNjI3NTQsImV4cCI6MjA5NTYzODc1NH0.HQpxZSWo0Um1JDZuSZpzHQnDDpSzC5-XiaNPyT-12MI';
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _getUrl(),
      anonKey: _getAnonKey(),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;

  static const String tableMenuItems = 'menu_items';
  static const String tableOrders = 'orders';
  static const String tableOrderItems = 'order_items';
  static const String tableProfiles = 'profiles';
  static const String tableGuestCustomers = 'guest_customers';
  static const String tableAnalyticsEvents = 'analytics_events';
  static const String bucketMenuImages = 'menu-images';
}
