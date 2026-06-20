import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_orders_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Timer _refreshTimer;
  DateTime _lastUpdated = DateTime.now();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    // Initialize provider and fetch orders with a small delay
    Future.microtask(() {
      if (mounted) {
        context.read<AdminOrdersProvider>().fetchOrders();
        context.read<AdminOrdersProvider>().startAutoRefresh();
      }
    });
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        setState(() => _lastUpdated = DateTime.now());
      }
    });
  }

  Future<void> _manualRefresh() async {
    setState(() => _isRefreshing = true);
    await context.read<AdminOrdersProvider>().fetchOrders();
    setState(() {
      _lastUpdated = DateTime.now();
      _isRefreshing = false;
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    context.read<AdminOrdersProvider>().stopAutoRefresh();
    super.dispose();
  }

  String _getTimeSinceUpdate() {
    final now = DateTime.now();
    final diff = now.difference(_lastUpdated);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 60,
          width: 200,
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isRefreshing ? Colors.green : Colors.black87,
            ),
            onPressed: _isRefreshing ? null : _manualRefresh,
            tooltip: 'Updated: ${_getTimeSinceUpdate()}',
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) => PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined, color: Colors.black87),
              onSelected: (value) async {
                if (value == 'logout') {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) context.go('/login');
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    auth.userEmail ?? '',
                    style: GoogleFonts.chivo(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 18),
                      const SizedBox(width: 8),
                      Text('Logout', style: GoogleFonts.chivo(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DASHBOARD', style: GoogleFonts.chivo(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 24),

            // Stats Row
            Consumer<AdminOrdersProvider>(
              builder: (context, provider, _) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: "TODAY'S SALES",
                            value: '₹${provider.totalSales.toStringAsFixed(0)}',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'PENDING ORDERS',
                            value: '${provider.pendingOrders}',
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            label: 'PREPARING',
                            value: '${provider.preparingOrders}',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            label: 'COMPLETED',
                            value: '${provider.completedOrders}',
                            color: Colors.purple,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),
            Text('MANAGEMENT', style: GoogleFonts.chivo(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            const SizedBox(height: 16),

            // Menu buttons in column
            _MenuButton(
              label: 'ORDERS',
              icon: Icons.receipt,
              onTap: () => context.go('/orders'),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              label: 'MENU',
              icon: Icons.restaurant_menu,
              onTap: () => context.go('/menu'),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              label: 'CUSTOMERS',
              icon: Icons.people,
              onTap: () => context.go('/customers'),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              label: 'ANALYTICS',
              icon: Icons.analytics,
              onTap: () => context.go('/analytics'),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              label: 'KITCHEN DISPLAY',
              icon: Icons.display_settings,
              onTap: () => context.go('/kds'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!, width: 2),
        color: color.withValues(alpha: 0.1),
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
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 2),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Colors.black),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.chivo(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
