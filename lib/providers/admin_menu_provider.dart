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
      _items = (response as List).map((json) => MenuItem.fromJson(json)).toList();
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
      'available': true,
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
  }) async {
    final updateData = <String, dynamic>{
      'name': name,
      'price': price,
      if (description != null) 'description': description,
      if (category != null) 'category': category,
      'badge': (badge != null && badge.isNotEmpty) ? badge : null,
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
