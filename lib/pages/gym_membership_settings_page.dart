import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/gym_membership_admin_provider.dart';

/// Gold membership plans — gym-model-only, mirrors the PLANS tab of
/// SubscriptionSettingsPage (Elite) but scoped to gym_membership_plans and
/// with the extra discount_percent field Gold needs and Elite doesn't.
class GymMembershipSettingsPage extends StatefulWidget {
  const GymMembershipSettingsPage({super.key});

  @override
  State<GymMembershipSettingsPage> createState() =>
      _GymMembershipSettingsPageState();
}

class _GymMembershipSettingsPageState
    extends State<GymMembershipSettingsPage> {
  @override
  void initState() {
    super.initState();
    context.read<GymMembershipAdminProvider>().fetchAll();
  }

  void _toast(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green[700] : Colors.red[700],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GymMembershipAdminProvider>();
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('GOLD MEMBERSHIP',
            style:
                GoogleFonts.chivo(fontSize: 20, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/'),
        ),
      ),
      body: p.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ElevatedButton.icon(
                  onPressed: () => _planDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('NEW PLAN'),
                ),
                const SizedBox(height: 12),
                ...p.plans.map((plan) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                            '${plan['name']} — ₹${plan['price']} / ${plan['duration_days']} days',
                            style:
                                GoogleFonts.chivo(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            '${plan['discount_percent']}% off gym orders'
                            '${(plan['badge'] ?? '').toString().isNotEmpty ? ' · badge: ${plan['badge']}' : ''}'
                            '${plan['active'] == false ? ' · HIDDEN' : ''}',
                            style: GoogleFonts.inter(fontSize: 13)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: plan['active'] != false,
                              onChanged: (v) async {
                                final err = await p.savePlan(
                                    {'id': plan['id'], 'active': v});
                                if (err != null) _toast(err, ok: false);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _planDialog(plan: plan),
                            ),
                          ],
                        ),
                      ),
                    )),
                const SizedBox(height: 24),
                Text('ACTIVE MEMBERS',
                    style: GoogleFonts.chivo(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                if (p.memberships.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No active Gold members yet.'),
                  ),
                ...p.memberships.map((m) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(m['customer_name'] as String? ?? '',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            '${(m['gym_membership_plans'] as Map?)?['name'] ?? ''} · '
                            'valid till ${m['end_date']} · ${m['member_code'] ?? ''}',
                            style: GoogleFonts.inter(fontSize: 13)),
                      ),
                    )),
              ],
            ),
    );
  }

  Future<void> _planDialog({Map<String, dynamic>? plan}) async {
    final name = TextEditingController(text: plan?['name'] as String? ?? '');
    final tagline =
        TextEditingController(text: plan?['tagline'] as String? ?? '');
    final desc =
        TextEditingController(text: plan?['description'] as String? ?? '');
    final price =
        TextEditingController(text: plan?['price']?.toString() ?? '');
    final comparePrice = TextEditingController(
        text: (plan?['compare_at_price'] ?? '').toString() == '0'
            ? ''
            : (plan?['compare_at_price'] ?? '').toString());
    final days = TextEditingController(
        text: plan?['duration_days']?.toString() ?? '30');
    final discount = TextEditingController(
        text: plan?['discount_percent']?.toString() ?? '10');
    final badge =
        TextEditingController(text: plan?['badge'] as String? ?? '');
    final features = TextEditingController(
        text: ((plan?['features'] as List?) ?? []).join('\n'));
    final sort =
        TextEditingController(text: plan?['sort_order']?.toString() ?? '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plan == null ? 'New plan' : 'Edit plan'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name')),
                TextField(
                    controller: tagline,
                    decoration: const InputDecoration(labelText: 'Tagline')),
                TextField(
                    controller: desc,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Description')),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: price,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Price ₹'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: comparePrice,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Normal price ₹',
                              helperText: 'Shows "SAVE X%"'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: days,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Days'))),
                ]),
                TextField(
                    controller: discount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Discount % on gym orders',
                        helperText: 'Applied automatically at checkout + free delivery')),
                TextField(
                    controller: badge,
                    decoration: const InputDecoration(
                        labelText: 'Badge (e.g. MOST POPULAR — optional)')),
                TextField(
                    controller: features,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        labelText: 'Features — one per line')),
                TextField(
                    controller: sort,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Sort order')),
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
              child: const Text('SAVE')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await context.read<GymMembershipAdminProvider>().savePlan({
      if (plan != null) 'id': plan['id'],
      'name': name.text.trim(),
      'tagline': tagline.text.trim(),
      'description': desc.text.trim(),
      'price': double.tryParse(price.text) ?? 0,
      'compare_at_price': double.tryParse(comparePrice.text) ?? 0,
      'duration_days': int.tryParse(days.text) ?? 30,
      'discount_percent': double.tryParse(discount.text) ?? 0,
      'badge': badge.text.trim(),
      'features': features.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      'sort_order': int.tryParse(sort.text) ?? 0,
    });
    _toast(err ?? 'Plan saved ✅', ok: err == null);
  }
}
