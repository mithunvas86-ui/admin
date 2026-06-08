class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final List<String> tags;
  final int kcal;
  final bool available;
  final String? imageUrl;
  final String? badge;
  final DateTime? createdAt;
  // Nutrition
  final String servingSize;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  // Availability
  final int? dailyLimit;
  final int ordersToday;
  final String lastResetDate;

  const MenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.tags,
    required this.kcal,
    required this.available,
    this.imageUrl,
    this.badge,
    this.createdAt,
    this.servingSize = '',
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.dailyLimit,
    this.ordersToday = 0,
    this.lastResetDate = '',
  });

  bool get isSoldOut =>
      !available ||
      (dailyLimit != null && dailyLimit! > 0 && ordersToday >= dailyLimit!);

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: (json['description'] as String?) ?? '',
      price: (json['price'] as num).toDouble(),
      category: json['category'] as String,
      tags: List<String>.from((json['tags'] as List<dynamic>?) ?? []),
      kcal: (json['kcal'] as int?) ?? 0,
      available: (json['available'] as bool?) ?? true,
      imageUrl: json['image_url'] as String?,
      badge: json['badge'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      servingSize: (json['serving_size'] as String?) ?? '',
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      dailyLimit: json['daily_limit'] as int?,
      ordersToday: (json['orders_today'] as int?) ?? 0,
      lastResetDate: (json['last_reset_date'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'tags': tags,
        'kcal': kcal,
        'available': available,
        'image_url': imageUrl,
        'badge': badge,
        'created_at': createdAt?.toIso8601String(),
        'serving_size': servingSize,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'daily_limit': dailyLimit,
        'orders_today': ordersToday,
        'last_reset_date': lastResetDate,
      };
}
