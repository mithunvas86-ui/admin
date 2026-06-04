import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/admin_orders_provider.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminOrdersProvider>().fetchOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ANALYTICS',
            style:
                GoogleFonts.chivo(fontSize: 24, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<AdminOrdersProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Key Metrics
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'TOTAL SALES',
                        value: '₹${provider.totalSales.toStringAsFixed(0)}',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'TOTAL ORDERS',
                        value: '${provider.totalOrders}',
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'AVG ORDER VALUE',
                        value:
                            '₹${provider.totalOrders > 0 ? (provider.totalSales / provider.totalOrders).toStringAsFixed(0) : '0'}',
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'COMPLETED',
                        value: '${provider.completedOrders}',
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Order Status Chart
                Text(
                  'ORDER STATUS DISTRIBUTION',
                  style: GoogleFonts.chivo(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox(
                    height: 200,
                    child: provider.totalOrders == 0
                        ? Center(
                            child: Text('No data yet',
                                style: GoogleFonts.chivo(color: Colors.grey)),
                          )
                        : PieChart(
                            PieChartData(
                              sections: [
                                if (provider.pendingOrders > 0)
                                  PieChartSectionData(
                                    value: provider.pendingOrders.toDouble(),
                                    title:
                                        'PENDING\n${provider.pendingOrders}',
                                    color: Colors.red,
                                    titleStyle: GoogleFonts.chivo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                if (provider.preparingOrders > 0)
                                  PieChartSectionData(
                                    value: provider.preparingOrders.toDouble(),
                                    title:
                                        'PREPARING\n${provider.preparingOrders}',
                                    color: Colors.orange,
                                    titleStyle: GoogleFonts.chivo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                if (provider.completedOrders > 0)
                                  PieChartSectionData(
                                    value: provider.completedOrders.toDouble(),
                                    title:
                                        'COMPLETED\n${provider.completedOrders}',
                                    color: Colors.green,
                                    titleStyle: GoogleFonts.chivo(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                // Recent Orders List
                Text(
                  'RECENT ORDERS',
                  style: GoogleFonts.chivo(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ...provider.orders.take(5).map((order) {
                  final customerName =
                      order['customer_name'] as String? ?? 'Guest';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${order['order_number']?.toString() ?? order['id'].toString().substring(0, 8)}',
                              style: GoogleFonts.chivo(
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              customerName,
                              style: GoogleFonts.chivo(
                                  fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${order['total_price']}',
                              style: GoogleFonts.chivo(
                                  fontWeight: FontWeight.w700),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                        order['status'] as String? ?? '')
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (order['status'] as String? ?? 'pending')
                                    .toUpperCase(),
                                style: GoogleFonts.chivo(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _getStatusColor(
                                      order['status'] as String? ?? ''),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red;
      case 'preparing':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 2),
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.chivo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.chivo(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
