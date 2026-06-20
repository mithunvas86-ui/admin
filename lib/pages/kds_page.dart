import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/admin_orders_provider.dart';
import '../providers/admin_menu_provider.dart';

class KDSPage extends StatefulWidget {
  const KDSPage({super.key});

  @override
  State<KDSPage> createState() => _KDSPageState();
}

class _KDSPageState extends State<KDSPage> {
  @override
  void initState() {
    super.initState();
    final ordersProvider = context.read<AdminOrdersProvider>();
    ordersProvider.fetchOrders();
    ordersProvider.startAutoRefresh();
    context.read<AdminMenuProvider>().fetchAll();
  }

  @override
  void dispose() {
    context.read<AdminOrdersProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          '🔴 KITCHEN DISPLAY',
          style: GoogleFonts.chivo(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: Consumer2<AdminOrdersProvider, AdminMenuProvider>(
        builder: (context, ordersProvider, menuProvider, _) {
          // Build image URL lookup map
          final imageMap = <String, String?>{};
          for (final item in menuProvider.items) {
            imageMap[item.id] = item.imageUrl;
          }

          final activeOrders = ordersProvider.orders
              .where((o) =>
                  o['status'] == 'pending' || o['status'] == 'preparing')
              .toList();

          if (activeOrders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.done_all, size: 80, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'ALL ORDERS COMPLETE!',
                    style: GoogleFonts.chivo(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: activeOrders.length,
            itemBuilder: (context, index) {
              final order = activeOrders[index];
              final status = order['status'] as String? ?? 'pending';
              final items = order['items'] as List<dynamic>? ?? [];
              final customerName =
                  order['customer_name'] as String? ?? 'Guest';
              final orderType = (order['order_type'] as String?) ?? '';
              final customerInfo =
                  (order['customer_info'] as Map?)?.cast<String, dynamic>() ??
                      {};
              // Address can be top-level or nested in customer_info.
              final deliveryAddress = (order['delivery_address'] as Map?)
                      ?.cast<String, dynamic>() ??
                  (customerInfo['delivery_address'] as Map?)
                      ?.cast<String, dynamic>() ??
                  <String, dynamic>{};
              final createdAt =
                  DateTime.tryParse(order['created_at'] as String? ?? '') ??
                      DateTime.now();
              final waitTime = DateTime.now().difference(createdAt);

              return _OrderCard(
                orderId: order['order_number']?.toString() ??
                    order['id'].toString().substring(0, 8),
                customerName: customerName,
                status: status,
                items: items,
                imageMap: imageMap,
                waitMinutes: waitTime.inMinutes,
                orderType: orderType,
                deliveryAddress: deliveryAddress,
                onStatusChange: (newStatus) {
                  ordersProvider.updateOrderStatus(
                      order['id'] as String, newStatus);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final String orderId;
  final String customerName;
  final String status;
  final List<dynamic> items;
  final Map<String, String?> imageMap;
  final int waitMinutes;
  final String orderType;
  final Map<String, dynamic> deliveryAddress;
  final Function(String) onStatusChange;

  const _OrderCard({
    required this.orderId,
    required this.customerName,
    required this.status,
    required this.items,
    required this.imageMap,
    required this.waitMinutes,
    required this.onStatusChange,
    this.orderType = '',
    this.deliveryAddress = const {},
  });

  Color get statusColor {
    switch (status) {
      case 'pending':
        return Colors.red;
      case 'preparing':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  bool get isDelivery => orderType.toLowerCase() == 'delivery';

  /// White pill in the header showing the order type, emphasized for delivery.
  Widget _typeBadge() {
    IconData icon;
    String label;
    switch (orderType.toLowerCase()) {
      case 'delivery':
        icon = Icons.delivery_dining;
        label = 'DELIVERY';
        break;
      case 'takeaway':
        icon = Icons.takeout_dining;
        label = 'TAKEAWAY';
        break;
      default:
        icon = Icons.restaurant;
        label = 'DINE IN';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: statusColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.chivo(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact address block for delivery orders (street / landmark / city — pincode).
  Widget _deliveryAddressBlock() {
    final street = (deliveryAddress['address'] ?? '').toString();
    final landmark = (deliveryAddress['landmark'] ?? '').toString();
    final city = (deliveryAddress['city'] ?? '').toString();
    final pincode = (deliveryAddress['pincode'] ?? '').toString();
    final cityLine =
        [city, pincode].where((v) => v.isNotEmpty).join(' — ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFFE3F2FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 13, color: Color(0xFF1565C0)),
              const SizedBox(width: 4),
              Text(
                'DELIVER TO',
                style: GoogleFonts.chivo(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1565C0),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (street.isNotEmpty)
            Text(
              street,
              style: GoogleFonts.chivo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (landmark.isNotEmpty)
            Text(
              'Near: $landmark',
              style: GoogleFonts.chivo(fontSize: 11, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (cityLine.isNotEmpty)
            Text(
              cityLine,
              style: GoogleFonts.chivo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: statusColor, width: 4),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(8),
            color: statusColor,
            child: Column(
              children: [
                Text(
                  orderId,
                  style: GoogleFonts.chivo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  customerName.toUpperCase(),
                  style: GoogleFonts.chivo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (orderType.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  _typeBadge(),
                ],
              ],
            ),
          ),
          // Items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: items.map((item) {
                  final name = item['name'] as String? ?? 'Item';
                  final qty = item['quantity'] ?? 1;
                  final menuItemId = item['menu_item_id'] as String?;
                  final imageUrl =
                      menuItemId != null ? imageMap[menuItemId] : null;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        if (imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              imageUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 40,
                                height: 40,
                                color: Colors.grey[700],
                                child: const Icon(Icons.fastfood,
                                    size: 20, color: Colors.white54),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.fastfood,
                                size: 20, color: Colors.white54),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${qty}x $name',
                            style: GoogleFonts.chivo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Delivery address (delivery orders only)
          if (isDelivery && deliveryAddress.isNotEmpty)
            _deliveryAddressBlock(),
          // Timer
          Container(
            padding: const EdgeInsets.all(8),
            color: statusColor.withValues(alpha: 0.2),
            child: Text(
              '⏱ ${waitMinutes}m',
              style: GoogleFonts.chivo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: statusColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Action Button
          GestureDetector(
            onTap: () {
              if (status == 'pending') {
                onStatusChange('preparing');
              } else if (status == 'preparing') {
                onStatusChange('confirmed');
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.green,
              child: Text(
                status == 'pending' ? 'START' : 'READY',
                style: GoogleFonts.chivo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
