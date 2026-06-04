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
  });

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
  };
}
