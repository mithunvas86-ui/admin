import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/admin_orders_provider.dart';
import '../services/supabase_service.dart';

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

            const SizedBox(height: 20),
            const _SecurityActivityCard(),

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
            const SizedBox(height: 12),
            _MenuButton(
              label: 'SETTINGS',
              icon: Icons.settings,
              onTap: () => context.go('/service-hours'),
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

// Security monitoring card — reads the audit_log (admin-only) for the last 24h.
class _SecurityActivityCard extends StatefulWidget {
  const _SecurityActivityCard();

  @override
  State<_SecurityActivityCard> createState() => _SecurityActivityCardState();
}

class _SecurityActivityCardState extends State<_SecurityActivityCard> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final since = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toIso8601String();
      final res = await SupabaseService.client
          .from('audit_log')
          .select('event,detail,ip,created_at')
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() {
          _events = List<Map<String, dynamic>>.from(res);
          _loading = false;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks =
        _events.where((e) => e['event'] == 'rate_limit_block').length;
    final payFails =
        _events.where((e) => e['event'] == 'payment_verify_fail').length;
    final alert = blocks > 0 || payFails > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alert ? Colors.red.shade50 : Colors.grey.shade50,
        border: Border.all(
            color: alert ? Colors.red.shade300 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alert ? Icons.warning_amber_rounded : Icons.shield_outlined,
                  size: 18,
                  color: alert ? Colors.red.shade700 : Colors.grey.shade700),
              const SizedBox(width: 6),
              Text('SECURITY ACTIVITY (24h)',
                  style:
                      GoogleFonts.chivo(fontSize: 13, fontWeight: FontWeight.w800)),
              const Spacer(),
              InkWell(
                onTap: () {
                  setState(() => _loading = true);
                  _load();
                },
                child: const Icon(Icons.refresh, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            Text('Loading…',
                style: GoogleFonts.chivo(fontSize: 12, color: Colors.grey))
          else if (_failed)
            Text('Run MONITORING.sql to enable the audit log.',
                style: GoogleFonts.chivo(fontSize: 11, color: Colors.grey))
          else ...[
            Row(
              children: [
                _miniStat('FLOODS BLOCKED', blocks, Colors.red),
                const SizedBox(width: 20),
                _miniStat('FAILED PAYMENT CHECKS', payFails, Colors.orange),
              ],
            ),
            const SizedBox(height: 10),
            if (_events.isEmpty)
              Text('No security events in the last 24h ✓',
                  style: GoogleFonts.chivo(
                      fontSize: 12, color: Colors.green.shade800))
            else
              ..._events.take(8).map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text('• ${_fmt(e)}',
                        style: GoogleFonts.chivo(
                            fontSize: 11, color: Colors.grey.shade800)),
                  )),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value',
            style: GoogleFonts.chivo(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: value > 0 ? color : Colors.grey)),
        Text(label,
            style: GoogleFonts.chivo(fontSize: 9, color: Colors.grey.shade700)),
      ],
    );
  }

  String _fmt(Map<String, dynamic> e) {
    final t =
        DateTime.tryParse(e['created_at']?.toString() ?? '')?.toLocal();
    final time = t != null
        ? '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
        : '';
    final ev = (e['event'] ?? '').toString().replaceAll('_', ' ');
    final ip = e['ip'] != null ? '  ${e['ip']}' : '';
    return '$time  $ev$ip';
  }
}
