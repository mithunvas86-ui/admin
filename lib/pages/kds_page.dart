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
  final Function(String) onStatusChange;

  const _OrderCard({
    required this.orderId,
    required this.customerName,
    required this.status,
    required this.items,
    required this.imageMap,
    required this.waitMinutes,
    required this.onStatusChange,
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
