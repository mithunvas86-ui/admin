import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/menu_item.dart';
import '../services/supabase_service.dart';

const _kCategoriesKey = 'admin_categories';
const _kDefaultCategories = [
  'Appetizers', 'Main', 'Desserts', 'Beverages', 'Snacks', 'Salads'
];

class AdminMenuProvider extends ChangeNotifier {
  List<MenuItem> _items = [];
  List<String> _customCategories = List.from(_kDefaultCategories);
  bool _isLoading = false;
  String _selectedCategory = 'All';

  List<MenuItem> get items => _items;
  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  List<String> get categories {
    final fromItems = _items.map((i) => i.category).toSet();
    final all = {..._customCategories, ...fromItems}.toList();
    all.sort();
    return all;
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_kCategoriesKey);
    if (saved != null) _customCategories = saved;
  }

  Future<void> _saveCategories() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kCategoriesKey, _customCategories);
  }

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _customCategories.contains(trimmed)) return;
    _customCategories.add(trimmed);
    await _saveCategories();
    notifyListeners();
  }

  Future<void> removeCategory(String name) async {
    _customCategories.remove(name);
    await _saveCategories();
    notifyListeners();
  }

  Future<void> fetchAll() async {
    _isLoading = true;
    notifyListeners();
    await _loadCategories();
    try {
      final response = await SupabaseService.client
          .from(SupabaseService.tableMenuItems)
          .select()
          .order('category');
      _items =
          (response as List).map((json) => MenuItem.fromJson(json)).toList();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addItem({
    required String name,
    required double price,
    required String category,
    String? description,
    String? badge,
    dynamic imageFile,
    bool available = true,
    int kcal = 0,
    String servingSize = '',
    double protein = 0,
    double carbs = 0,
    double fat = 0,
    double fiber = 0,
    int? dailyLimit,
    bool customizable = true,
  }) async {
    String? imageUrl;
    if (imageFile != null &&
        ((imageFile is File) ||
            (imageFile is Uint8List && imageFile.isNotEmpty))) {
      try {
        imageUrl = await _uploadImage(imageFile);
      } catch (_) {}
    }

    await SupabaseService.client.from(SupabaseService.tableMenuItems).insert({
      'name': name,
      'price': price,
      'category': category,
      'description': description ?? '',
      'image_url': imageUrl,
      'available': available,
      'customizable': customizable,
      'kcal': kcal,
      'serving_size': servingSize,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      if (dailyLimit != null && dailyLimit > 0) 'daily_limit': dailyLimit,
      'orders_today': 0,
      'last_reset_date': '',
      if (badge != null && badge.isNotEmpty) 'badge': badge,
    });
    await fetchAll();
  }

  Future<void> updateItem({
    required String itemId,
    required String name,
    required double price,
    String? description,
    String? category,
    String? badge,
    dynamic imageFile,
    bool? available,
    int? kcal,
    String? servingSize,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    int? dailyLimit,
    bool clearDailyLimit = false,
    bool? customizable,
  }) async {
    final updateData = <String, dynamic>{
      'name': name,
      'price': price,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      'badge': (badge != null && badge.isNotEmpty) ? badge : null,
      if (available != null) 'available': available,
      if (customizable != null) 'customizable': customizable,
      if (kcal != null) 'kcal': kcal,
      if (servingSize != null) 'serving_size': servingSize,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      if (fiber != null) 'fiber': fiber,
      'daily_limit':
          clearDailyLimit ? null : (dailyLimit != null && dailyLimit > 0 ? dailyLimit : null),
    };

    if (imageFile != null &&
        ((imageFile is File) ||
            (imageFile is Uint8List && imageFile.isNotEmpty))) {
      try {
        final imageUrl = await _uploadImage(imageFile);
        updateData['image_url'] = imageUrl;
      } catch (_) {}
    }

    await SupabaseService.client
        .from(SupabaseService.tableMenuItems)
        .update(updateData)
        .eq('id', itemId);
    await fetchAll();
  }

  Future<void> resetTodayCount(String itemId) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.tableMenuItems)
          .update({'orders_today': 0, 'available': true})
          .eq('id', itemId);
      await fetchAll();
    } catch (_) {}
  }

  Future<String> _uploadImage(dynamic imageFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    String fileName;
    dynamic uploadData;

    if (imageFile is File) {
      fileName = 'menu_${timestamp}_${p.basename(imageFile.path)}';
      uploadData = imageFile;
    } else if (imageFile is Uint8List) {
      fileName = 'menu_${timestamp}_image.jpg';
      uploadData = imageFile;
    } else {
      throw Exception('Invalid image type');
    }

    await SupabaseService.client.storage
        .from('menu-images')
        .uploadBinary(fileName, uploadData);

    return SupabaseService.client.storage
        .from('menu-images')
        .getPublicUrl(fileName);
  }

  void selectCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  Future<void> toggleAvailability(String itemId, bool available) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.tableMenuItems)
          .update({'available': available})
          .eq('id', itemId);
      await fetchAll();
    } catch (_) {}
  }

  /// Sets the "Featured Creation" shown on the customer menu hero.
  /// Only one item can be featured at a time, so selecting one clears any
  /// previously featured dish. Pass [featured] = false to clear it.
  Future<void> setFeatured(String itemId, bool featured) async {
    try {
      if (featured) {
        // Clear the currently featured item (if any).
        await SupabaseService.client
            .from(SupabaseService.tableMenuItems)
            .update({'featured': false})
            .eq('featured', true);
      }
      await SupabaseService.client
          .from(SupabaseService.tableMenuItems)
          .update({'featured': featured})
          .eq('id', itemId);
      await fetchAll();
    } catch (e) {
      debugPrint('setFeatured error: $e');
    }
  }

  Future<void> deleteItem(String itemId) async {
    try {
      await SupabaseService.client
          .from(SupabaseService.tableMenuItems)
          .delete()
          .eq('id', itemId);
      _items.removeWhere((item) => item.id == itemId);
      notifyListeners();
    } catch (_) {}
  }
}
