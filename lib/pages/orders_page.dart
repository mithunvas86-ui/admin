import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/admin_orders_provider.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  @override
  void initState() {
    super.initState();
    final provider = context.read<AdminOrdersProvider>();
    provider.fetchOrders();
    provider.startAutoRefresh();
  }

  @override
  void dispose() {
    context.read<AdminOrdersProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ORDERS',
            style:
                GoogleFonts.chivo(fontSize: 24, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<AdminOrdersProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.orders.isEmpty) {
            return Center(
              child:
                  Text('No orders yet', style: GoogleFonts.chivo(fontSize: 18)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.orders.length,
            itemBuilder: (context, index) {
              final order = provider.orders[index];
              // Support both 'customer_info' (from user app) and 'guest_customers' (legacy)
              final customer =
                  order['customer_info'] ?? order['guest_customers'] ?? {};
              // Support both 'items' (from user app) and 'order_items' (legacy)
              final items = order['items'] ?? order['order_items'] ?? [];
              final status = order['status'] ?? 'pending';
              final createdAt = order['created_at'] ??
                  order['timestamp'] ??
                  DateTime.now().toIso8601String();

              // Parse timestamp for display
              DateTime orderTime = DateTime.parse(createdAt);
              String timeDisplay =
                  '${orderTime.hour}:${orderTime.minute.toString().padLeft(2, '0')}';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                  side: BorderSide(color: Colors.black, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER #${(order['order_number'] ?? order['id'].toString().substring(0, 8)).toString().toUpperCase()}',
                                style: GoogleFonts.chivo(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                timeDisplay,
                                style: GoogleFonts.chivo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          DropdownButton<String>(
                            value: status,
                            items: [
                              'pending',
                              'confirmed',
                              'preparing',
                              'ready',
                              'completed',
                              'cancelled',
                            ]
                                .map((s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s.toUpperCase()),
                                    ))
                                .toList(),
                            onChanged: status == 'cancelled'
                                ? null
                                : (newStatus) {
                                    if (newStatus != null &&
                                        newStatus != status) {
                                      provider.updateOrderStatus(
                                          order['id'], newStatus);
                                    }
                                  },
                          ),
                        ],
                      ),
                      const Divider(thickness: 1, height: 12),
                      Text(
                        '${customer['name'] ?? 'Guest'} • ${customer['phone'] ?? 'N/A'}',
                        style: GoogleFonts.chivo(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      // Display items correctly
                      ...items.map((item) {
                        // Support different item formats
                        String itemName = item['name'] ??
                            (item['menu_items']?['name'] ?? 'Item');
                        int quantity = item['quantity'] ?? 1;
                        double price =
                            (item['price'] as num?)?.toDouble() ?? 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${quantity}x $itemName - ₹${(price * quantity).toStringAsFixed(0)}',
                            style: GoogleFonts.chivo(fontSize: 12),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL: ₹${(order['total_price'] as num?)?.toStringAsFixed(0) ?? '0'}',
                            style: GoogleFonts.chivo(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            'Payment: ${(order['payment_method'] ?? 'COD').toUpperCase()}',
                            style: GoogleFonts.chivo(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
