class Order {
  final String id;
  final String userId;
  final String status;
  final double total;
  final List<dynamic> items;
  final String? tableNumber;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Order({
    required this.id,
    required this.userId,
    required this.status,
    required this.total,
    required this.items,
    this.tableNumber,
    required this.createdAt,
    this.completedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String,
      total: (json['total'] as num).toDouble(),
      items: json['items'] as List<dynamic>? ?? [],
      tableNumber: json['table_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'status': status,
    'total': total,
    'items': items,
    'table_number': tableNumber,
    'created_at': createdAt.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
  };
}
