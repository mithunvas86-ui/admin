import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_admin_provider.dart';

/// Subscription management: pending approvals + active members.
/// Approving creates the member's app login (email + password) via the
/// admin-manage-member edge function.
class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    final p = context.read<SubscriptionAdminProvider>();
    p.fetchSubscriptions();
    p.fetchEditors(); // plans for the "add member" dialog
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green[700] : Colors.red[700],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SubscriptionAdminProvider>();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('SUBSCRIPTIONS',
            style:
                GoogleFonts.chivo(fontSize: 22, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.soup_kitchen, color: Colors.black87),
            tooltip: 'Subscription kitchen',
            onPressed: () => context.go('/subs-kds'),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87),
            tooltip: 'Plans, banners & WhatsApp',
            onPressed: () => context.go('/subs-settings'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: p.fetchSubscriptions,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.black87,
          indicatorColor: Colors.black87,
          labelStyle: GoogleFonts.chivo(fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: 'APPROVALS (${p.pending.length})'),
            Tab(text: 'MEMBERS (${p.members.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMemberDialog,
        icon: const Icon(Icons.person_add),
        label: Text('ADD MEMBER',
            style: GoogleFonts.chivo(fontWeight: FontWeight.w800)),
      ),
      body: p.isLoading && p.pending.isEmpty && p.members.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _list(p.pending, isPending: true),
                _list(p.members, isPending: false),
              ],
            ),
    );
  }

  Widget _list(List<Map<String, dynamic>> rows, {required bool isPending}) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          isPending ? 'No subscriptions waiting for approval' : 'No members yet',
          style: GoogleFonts.chivo(fontSize: 16, color: Colors.grey[600]),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () =>
          context.read<SubscriptionAdminProvider>().fetchSubscriptions(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: rows.length,
        itemBuilder: (_, i) => _SubCard(
          sub: rows[i],
          isPending: isPending,
          onApprove: () => _approveDialog(rows[i]),
          onReject: () => _rejectDialog(rows[i]),
          onRemove: () => _removeDialog(rows[i]),
          onResetPassword: () => _resetPasswordDialog(rows[i]),
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Future<void> _approveDialog(Map<String, dynamic> sub) async {
    final email = TextEditingController(text: (sub['email'] ?? '') as String);
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve & create login'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'This activates ${sub['customer_name']}\'s plan and creates their '
              'app login. Share the credentials with them on WhatsApp.',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: email,
              decoration: const InputDecoration(labelText: 'Login email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: password,
              decoration: const InputDecoration(
                  labelText: 'Password (min 8 characters)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('APPROVE')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await context.read<SubscriptionAdminProvider>().approve(
          subscriptionId: sub['id'] as String,
          email: email.text.trim(),
          password: password.text,
        );
    _toast(err ?? 'Member approved and login created ✅', ok: err == null);
  }

  Future<void> _rejectDialog(Map<String, dynamic> sub) async {
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject subscription'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REJECT'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await context
        .read<SubscriptionAdminProvider>()
        .reject(sub['id'] as String, reason.text.trim());
    _toast(err ?? 'Rejected', ok: err == null);
  }

  Future<void> _removeDialog(Map<String, dynamic> sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text(
            'This cancels ${sub['customer_name']}\'s subscription and disables '
            'their login. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await context
        .read<SubscriptionAdminProvider>()
        .removeMember(sub['id'] as String);
    _toast(err ?? 'Member removed', ok: err == null);
  }

  Future<void> _resetPasswordDialog(Map<String, dynamic> sub) async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset member password'),
        content: TextField(
          controller: password,
          decoration:
              const InputDecoration(labelText: 'New password (min 8 chars)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('RESET')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await context
        .read<SubscriptionAdminProvider>()
        .resetPassword(sub['id'] as String, password.text);
    _toast(err ?? 'Password updated', ok: err == null);
  }

  Future<void> _addMemberDialog() async {
    final p = context.read<SubscriptionAdminProvider>();
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    final address = TextEditingController();
    String? planId = p.plans.isNotEmpty ? p.plans.first['id'] as String : null;
    String pref = 'veg';
    String goal = 'balanced_nutrition';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add member manually'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: planId,
                    items: p.plans
                        .map((pl) => DropdownMenuItem(
                              value: pl['id'] as String,
                              child: Text('${pl['name']} — ₹${pl['price']}'),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => planId = v),
                    decoration: const InputDecoration(labelText: 'Plan'),
                  ),
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Full name')),
                  TextField(
                      controller: phone,
                      decoration: const InputDecoration(
                          labelText: 'WhatsApp number')),
                  TextField(
                      controller: email,
                      decoration:
                          const InputDecoration(labelText: 'Login email')),
                  TextField(
                      controller: password,
                      decoration: const InputDecoration(
                          labelText: 'Password (min 8 chars)')),
                  TextField(
                      controller: address,
                      decoration: const InputDecoration(
                          labelText: 'Delivery address')),
                  DropdownButtonFormField<String>(
                    value: pref,
                    items: const [
                      DropdownMenuItem(value: 'veg', child: Text('Vegetarian')),
                      DropdownMenuItem(
                          value: 'non_veg', child: Text('Non-Vegetarian')),
                      DropdownMenuItem(
                          value: 'eggetarian', child: Text('Eggetarian')),
                      DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
                    ],
                    onChanged: (v) => setState(() => pref = v ?? 'veg'),
                    decoration:
                        const InputDecoration(labelText: 'Food preference'),
                  ),
                  DropdownButtonFormField<String>(
                    value: goal,
                    items: const [
                      DropdownMenuItem(
                          value: 'weight_loss', child: Text('Weight loss')),
                      DropdownMenuItem(
                          value: 'muscle_gain', child: Text('Muscle gain')),
                      DropdownMenuItem(
                          value: 'balanced_nutrition',
                          child: Text('Balanced nutrition')),
                      DropdownMenuItem(
                          value: 'diabetic_friendly',
                          child: Text('Diabetic friendly')),
                      DropdownMenuItem(
                          value: 'general_fitness',
                          child: Text('General fitness')),
                    ],
                    onChanged: (v) =>
                        setState(() => goal = v ?? 'balanced_nutrition'),
                    decoration:
                        const InputDecoration(labelText: 'Health goal'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('CREATE')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted || planId == null) return;
    final err = await p.addMember({
      'plan_id': planId,
      'customer_name': name.text.trim(),
      'phone': phone.text.trim(),
      'email': email.text.trim(),
      'password': password.text,
      'food_preference': pref,
      'health_goal': goal,
      'delivery_address': {'address': address.text.trim()},
    });
    _toast(err ?? 'Member created ✅', ok: err == null);
  }
}

class _SubCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  final bool isPending;
  final VoidCallback onApprove, onReject, onRemove, onResetPassword;

  const _SubCard({
    required this.sub,
    required this.isPending,
    required this.onApprove,
    required this.onReject,
    required this.onRemove,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final plan =
        (sub['subscription_plans'] as Map?)?.cast<String, dynamic>() ?? {};
    final address =
        (sub['delivery_address'] as Map?)?.cast<String, dynamic>() ?? {};
    final incomplete = sub['status'] == 'payment_received';
    final chips = <String>[
      if ((sub['food_preference'] ?? '').toString().isNotEmpty)
        sub['food_preference'].toString().replaceAll('_', '-').toUpperCase(),
      if ((sub['health_goal'] ?? '').toString().isNotEmpty)
        sub['health_goal'].toString().replaceAll('_', ' ').toUpperCase(),
      if ((sub['member_code'] ?? '').toString().isNotEmpty)
        sub['member_code'].toString(),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (sub['customer_name'] ?? '').toString().isEmpty
                        ? '(details not submitted yet)'
                        : sub['customer_name'].toString(),
                    style: GoogleFonts.chivo(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: incomplete
                        ? Colors.orange[100]
                        : isPending
                            ? Colors.amber[100]
                            : Colors.green[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (sub['status'] ?? '')
                        .toString()
                        .replaceAll('_', ' ')
                        .toUpperCase(),
                    style: GoogleFonts.chivo(
                        fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${plan['name'] ?? 'Plan'} · ₹${sub['amount_paid'] ?? plan['price'] ?? '—'}'
              '${sub['phone'] != null && '${sub['phone']}'.isNotEmpty ? ' · ${sub['phone']}' : ''}'
              '${sub['email'] != null && '${sub['email']}'.isNotEmpty ? ' · ${sub['email']}' : ''}',
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800]),
            ),
            if ((address['address'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '📍 ${address['address']}'
                  '${(address['city'] ?? '').toString().isNotEmpty ? ', ${address['city']}' : ''}'
                  '${(address['pincode'] ?? '').toString().isNotEmpty ? ' — ${address['pincode']}' : ''}',
                  style:
                      GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[700]),
                ),
              ),
            if ((sub['health_notes'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('⚠ ${sub['health_notes']}',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: Colors.deepOrange[800])),
              ),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: chips
                      .map((c) => Chip(
                            label: Text(c,
                                style: GoogleFonts.chivo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ),
            if (!isPending && sub['end_date'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Valid ${sub['start_date']} → ${sub['end_date']}',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: Colors.grey[600])),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: isPending
                  ? [
                      TextButton(
                        onPressed: onReject,
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('REJECT'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: incomplete ? null : onApprove,
                        icon: const Icon(Icons.check, size: 16),
                        label: Text(
                            incomplete ? 'AWAITING DETAILS' : 'APPROVE',
                            style: GoogleFonts.chivo(
                                fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: onResetPassword,
                        child: const Text('RESET PASSWORD'),
                      ),
                      TextButton(
                        onPressed: onRemove,
                        style:
                            TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('REMOVE'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
