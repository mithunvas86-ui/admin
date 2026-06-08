import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/admin_orders_provider.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    final provider = context.read<AdminOrdersProvider>();
    provider.fetchOrders();
    provider.startAutoRefresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    context.read<AdminOrdersProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ORDERS',
            style: GoogleFonts.chivo(
                fontSize: 24, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelStyle: GoogleFonts.chivo(
              fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long), text: 'ALL ORDERS'),
            Tab(
                icon: Icon(Icons.delivery_dining),
                text: 'DELIVERIES'),
          ],
        ),
      ),
      body: Consumer<AdminOrdersProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = provider.orders;
          final deliveryOrders = allOrders
              .where((o) =>
                  (o['order_type'] ?? '').toString().toLowerCase() ==
                  'delivery')
              .toList();

          return TabBarView(
            controller: _tabs,
            children: [
              // ── ALL ORDERS ─────────────────────────────────────
              _OrderList(
                orders: allOrders,
                provider: provider,
                emptyMessage: 'No orders yet',
              ),
              // ── DELIVERIES ─────────────────────────────────────
              _DeliveryList(
                orders: deliveryOrders,
                provider: provider,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// All orders list
// ─────────────────────────────────────────────────────────────────────────────

class _OrderList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final AdminOrdersProvider provider;
  final String emptyMessage;

  const _OrderList({
    required this.orders,
    required this.provider,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
          child: Text(emptyMessage,
              style: GoogleFonts.chivo(fontSize: 18, color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) =>
          _OrderCard(order: orders[index], provider: provider),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deliveries list
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryList extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final AdminOrdersProvider provider;

  const _DeliveryList({required this.orders, required this.provider});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delivery_dining, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No delivery orders yet',
                style: GoogleFonts.chivo(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    // Summary banner
    final pending = orders
        .where((o) => (o['status'] ?? '') == 'pending')
        .length;
    final outForDelivery = orders
        .where((o) => (o['status'] ?? '') == 'out_for_delivery')
        .length;
    final completed = orders
        .where((o) => (o['status'] ?? '') == 'completed')
        .length;

    return Column(
      children: [
        // Stats strip
        Container(
          color: const Color(0xFF0D47A1),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            children: [
              _StatChip(
                  label: 'PENDING', value: pending, color: Colors.orange),
              const SizedBox(width: 12),
              _StatChip(
                  label: 'EN ROUTE',
                  value: outForDelivery,
                  color: Colors.lightBlueAccent),
              const SizedBox(width: 12),
              _StatChip(
                  label: 'DELIVERED',
                  value: completed,
                  color: Colors.greenAccent),
              const Spacer(),
              Text('${orders.length} TOTAL',
                  style: GoogleFonts.chivo(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) =>
                _DeliveryOrderCard(order: orders[index], provider: provider),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color, width: 1)),
          child: Text('$value $label',
              style: GoogleFonts.chivo(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standard order card (for All Orders tab)
// ─────────────────────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final AdminOrdersProvider provider;

  const _OrderCard({required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    final customer =
        order['customer_info'] ?? order['guest_customers'] ?? {};
    final items = order['items'] ?? order['order_items'] ?? [];
    final status = order['status'] ?? 'pending';
    final orderType = (order['order_type'] ?? '').toString().toLowerCase();
    final isDelivery = orderType == 'delivery';

    final createdAt = order['created_at'] ??
        order['timestamp'] ??
        DateTime.now().toIso8601String();
    final orderTime = DateTime.parse(createdAt);
    final timeDisplay =
        '${orderTime.hour}:${orderTime.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(
          color: isDelivery
              ? const Color(0xFF1565C0)
              : Colors.black,
          width: isDelivery ? 2 : 2,
        ),
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
                    Row(
                      children: [
                        if (isDelivery) ...[
                          const Icon(Icons.delivery_dining,
                              size: 16, color: Color(0xFF1565C0)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          'ORDER #${(order['order_number'] ?? order['id'].toString().substring(0, 8)).toString().toUpperCase()}',
                          style: GoogleFonts.chivo(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: isDelivery
                                ? const Color(0xFF1565C0)
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Text(timeDisplay,
                        style: GoogleFonts.chivo(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600])),
                  ],
                ),
                DropdownButton<String>(
                  value: status,
                  items: _statusOptions(isDelivery)
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.toUpperCase().replaceAll('_', ' ')),
                          ))
                      .toList(),
                  onChanged: status == 'cancelled'
                      ? null
                      : (newStatus) {
                          if (newStatus != null && newStatus != status) {
                            provider.updateOrderStatus(order['id'], newStatus);
                          }
                        },
                ),
              ],
            ),
            const Divider(thickness: 1, height: 12),
            Text(
              '${customer['name'] ?? 'Guest'}  •  ${customer['phone'] ?? 'N/A'}',
              style: GoogleFonts.chivo(
                  fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...items.map((item) {
              final itemName = item['name'] ??
                  (item['menu_items']?['name'] ?? 'Item');
              final quantity = item['quantity'] ?? 1;
              final price =
                  (item['price'] as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${quantity}x $itemName  —  ₹${(price * quantity).toStringAsFixed(0)}',
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
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.green),
                ),
                Text(
                  '${orderType.toUpperCase().replaceAll('_', ' ')}  •  ${(order['payment_method'] ?? 'COD').toString().toUpperCase()}',
                  style: GoogleFonts.chivo(
                      fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delivery order card (for Deliveries tab — shows address prominently)
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final AdminOrdersProvider provider;

  const _DeliveryOrderCard(
      {required this.order, required this.provider});

  @override
  Widget build(BuildContext context) {
    final customer =
        order['customer_info'] ?? order['guest_customers'] ?? {};
    final items = order['items'] ?? order['order_items'] ?? [];
    final status = order['status'] ?? 'pending';

    // Address can be at top level or inside customer_info
    final addr = (order['delivery_address'] as Map?)?.cast<String, dynamic>() ??
        (customer['delivery_address'] as Map?)?.cast<String, dynamic>() ??
        {};

    final createdAt = order['created_at'] ??
        order['timestamp'] ??
        DateTime.now().toIso8601String();
    final orderTime = DateTime.parse(createdAt);
    final timeDisplay =
        '${orderTime.hour}:${orderTime.minute.toString().padLeft(2, '0')}';

    final statusColor = _deliveryStatusColor(status);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: statusColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 10),
            color: statusColor,
            child: Row(
              children: [
                const Icon(Icons.delivery_dining,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORDER #${(order['order_number'] ?? order['id'].toString().substring(0, 8)).toString().toUpperCase()}',
                      style: GoogleFonts.chivo(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5),
                    ),
                    Text(timeDisplay,
                        style: GoogleFonts.chivo(
                            fontSize: 10, color: Colors.white70)),
                  ],
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: status,
                  dropdownColor: Colors.grey[900],
                  style: GoogleFonts.chivo(
                      color: Colors.white, fontWeight: FontWeight.w700),
                  iconEnabledColor: Colors.white,
                  underline: const SizedBox.shrink(),
                  items: _statusOptions(true)
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(
                              s.toUpperCase().replaceAll('_', ' '),
                              style: GoogleFonts.chivo(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ))
                      .toList(),
                  onChanged: status == 'cancelled'
                      ? null
                      : (newStatus) {
                          if (newStatus != null && newStatus != status) {
                            provider.updateOrderStatus(order['id'], newStatus);
                          }
                        },
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer
                Row(
                  children: [
                    const Icon(Icons.person, size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      '${customer['name'] ?? 'Guest'}  •  ${customer['phone'] ?? 'N/A'}',
                      style: GoogleFonts.chivo(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Delivery address block
                if (addr.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      border:
                          Border.all(color: const Color(0xFF1565C0), width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 14, color: Color(0xFF1565C0)),
                            const SizedBox(width: 4),
                            Text('DELIVERY ADDRESS',
                                style: GoogleFonts.chivo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1565C0),
                                    letterSpacing: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if ((addr['address'] ?? '').toString().isNotEmpty)
                          Text(addr['address'].toString(),
                              style: GoogleFonts.chivo(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        if ((addr['landmark'] ?? '').toString().isNotEmpty)
                          Text('Near: ${addr['landmark']}',
                              style: GoogleFonts.chivo(
                                  fontSize: 12, color: Colors.grey[700])),
                        if ((addr['city'] ?? '').toString().isNotEmpty ||
                            (addr['pincode'] ?? '').toString().isNotEmpty)
                          Text(
                            [
                              addr['city'],
                              addr['pincode']
                            ].where((v) => v != null && v.toString().isNotEmpty)
                                .join(' — '),
                            style: GoogleFonts.chivo(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800]),
                          ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.orange.shade50,
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            size: 14, color: Colors.orange),
                        const SizedBox(width: 6),
                        Text('No address provided',
                            style: GoogleFonts.chivo(
                                fontSize: 12, color: Colors.orange)),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),
                const Divider(height: 1, thickness: 1),
                const SizedBox(height: 8),

                // Items
                ...items.map((item) {
                  final itemName = item['name'] ??
                      (item['menu_items']?['name'] ?? 'Item');
                  final quantity = item['quantity'] ?? 1;
                  final price =
                      (item['price'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '${quantity}x $itemName  —  ₹${(price * quantity).toStringAsFixed(0)}',
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
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade700),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      color: Colors.grey.shade200,
                      child: Text(
                        (order['payment_method'] ?? 'ONLINE')
                            .toString()
                            .toUpperCase(),
                        style: GoogleFonts.chivo(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

List<String> _statusOptions(bool isDelivery) => isDelivery
    ? [
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'out_for_delivery',
        'completed',
        'cancelled',
      ]
    : [
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'completed',
        'cancelled',
      ];

Color _deliveryStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return Colors.orange.shade700;
    case 'confirmed':
      return const Color(0xFF1565C0);
    case 'preparing':
      return const Color(0xFF6A1B9A);
    case 'ready':
      return const Color(0xFF2E7D32);
    case 'out_for_delivery':
      return const Color(0xFF00838F);
    case 'completed':
      return const Color(0xFF1B5E20);
    case 'cancelled':
      return Colors.red.shade700;
    default:
      return Colors.grey.shade600;
  }
}
