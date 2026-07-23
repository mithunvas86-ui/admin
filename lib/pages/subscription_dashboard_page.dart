import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_admin_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/model_switcher.dart';

/// Subscription DASHBOARD — same visual template as the main admin dashboard
/// (stat cards + black-bordered menu buttons). This is the sub_manager's
/// landing page; Members, Kitchen Display and Settings are separate pages.
class SubscriptionDashboardPage extends StatefulWidget {
  const SubscriptionDashboardPage({super.key});

  @override
  State<SubscriptionDashboardPage> createState() =>
      _SubscriptionDashboardPageState();
}

class _SubscriptionDashboardPageState
    extends State<SubscriptionDashboardPage> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    final p = context.read<SubscriptionAdminProvider>();
    p.setKdsDate(DateTime.now()); // today's meals for the stat cards
    await p.fetchSubscriptions();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final isFullAdmin = adminAuth.role == 'admin';

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
        // Full admins arrived from the main dashboard — give them a way back.
        leading: isFullAdmin
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => context.go('/'),
              )
            : null,
        actions: [
          const ModelSwitcher(current: 'subscription'),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isRefreshing ? Colors.green : Colors.black87,
            ),
            onPressed: _isRefreshing ? null : _refresh,
          ),
          Consumer<AuthProvider>(
            builder: (context, auth, _) => PopupMenuButton<String>(
              icon: const Icon(Icons.account_circle_outlined,
                  color: Colors.black87),
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
                    style: GoogleFonts.chivo(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 18),
                      const SizedBox(width: 8),
                      Text('Logout',
                          style: GoogleFonts.chivo(
                              fontWeight: FontWeight.w600)),
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
        child: Consumer<SubscriptionAdminProvider>(
          builder: (context, p, _) {
            // Today's meal pipeline numbers.
            final todayMeals = p.meals;
            final confirmed = todayMeals
                .where((m) => ['confirmed', 'preparing', 'prepared',
                      'out_for_delivery', 'delivered']
                    .contains(m['status']))
                .length;
            final prepared = todayMeals
                .where((m) => ['prepared', 'out_for_delivery', 'delivered']
                    .contains(m['status']))
                .length;
            final pendingKitchen = confirmed - prepared;
            // Paid revenue across active memberships.
            double revenue = 0;
            for (final s in p.members) {
              revenue += (s['amount_paid'] as num?)?.toDouble() ?? 0;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SUBSCRIPTION DASHBOARD',
                    style: GoogleFonts.chivo(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 24),

                // Stats
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'ACTIVE MEMBERS',
                        value: '${p.members.length}',
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'PENDING APPROVALS',
                        value: '${p.pending.length}',
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
                        label: "TODAY'S MEALS",
                        value: '$confirmed',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'PREPARED / PENDING',
                        value: '$prepared / $pendingKitchen',
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'MEMBERSHIP REVENUE',
                        value: '₹${revenue.toStringAsFixed(0)}',
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                Text('MANAGEMENT',
                    style: GoogleFonts.chivo(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 16),

                _MenuButton(
                  label: 'MEMBERS',
                  icon: Icons.people,
                  badge: p.pending.isNotEmpty ? '${p.pending.length}' : null,
                  onTap: () => context.go('/subs-members'),
                ),
                const SizedBox(height: 12),
                _MenuButton(
                  label: 'MEAL PLANNER',
                  icon: Icons.restaurant_menu,
                  onTap: () => context.go('/subs-meals'),
                ),
                const SizedBox(height: 12),
                _MenuButton(
                  label: 'KITCHEN DISPLAY',
                  icon: Icons.soup_kitchen,
                  onTap: () => context.go('/subs-kitchen'),
                ),
                const SizedBox(height: 12),
                _MenuButton(
                  label: 'DELIVERY',
                  icon: Icons.delivery_dining,
                  onTap: () => context.go('/subs-delivery'),
                ),
                const SizedBox(height: 12),
                _MenuButton(
                  label: 'SETTINGS',
                  icon: Icons.settings,
                  onTap: () => context.go('/subs-settings'),
                ),
              ],
            );
          },
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
              fontSize: 26,
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
  final String? badge;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.badge,
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
            if (badge != null) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: GoogleFonts.chivo(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
            const Spacer(),
            const Icon(Icons.arrow_forward, color: Colors.black),
          ],
        ),
      ),
    );
  }
}
