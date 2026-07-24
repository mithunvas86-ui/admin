import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_admin_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/kds_empty_state.dart';

/// Subscription kitchen/prep view — split out of the former combined
/// subscription_kds_page.dart. Confirmed meals for the selected date, sorted
/// by priority: header totals (to prepare / prepared / pending, split by
/// preference), per-meal checkbox marks it PREPARED, priority stepper.
///
/// No delivery/dispatch concerns here — see subscription_delivery_page.dart.
class SubscriptionChefPage extends StatefulWidget {
  const SubscriptionChefPage({super.key});

  @override
  State<SubscriptionChefPage> createState() => _SubscriptionChefPageState();
}

class _SubscriptionChefPageState extends State<SubscriptionChefPage> {
  @override
  void initState() {
    super.initState();
    final p = context.read<SubscriptionAdminProvider>();
    p.fetchMeals();
    p.startAutoRefresh();
  }

  @override
  void dispose() {
    context.read<SubscriptionAdminProvider>().stopAutoRefresh();
    super.dispose();
  }

  int _mealsOf(Map<String, dynamic> m) {
    final sub = (m['subscriptions'] as Map?)?.cast<String, dynamic>() ?? {};
    final plan =
        (sub['subscription_plans'] as Map?)?.cast<String, dynamic>() ?? {};
    return (plan['meals_per_day'] as num?)?.toInt() ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SubscriptionAdminProvider>();
    final isManager =
        adminAuth.role == 'admin' || adminAuth.role == 'sub_manager';

    final active = p.meals
        .where((m) => ['confirmed', 'preparing', 'prepared']
            .contains(m['status']))
        .toList();

    // Totals for the kitchen header.
    int toPrepare = 0, prepared = 0;
    final byPref = <String, int>{};
    for (final m in active) {
      final n = _mealsOf(m);
      toPrepare += n;
      prepared += (m['prepared_count'] as num?)?.toInt() ?? 0;
      final sub = (m['subscriptions'] as Map?)?.cast<String, dynamic>() ?? {};
      final prefKey = (sub['food_preference'] ?? 'other') as String;
      byPref[prefKey] = (byPref[prefKey] ?? 0) + n;
    }
    final pendingCount = toPrepare - prepared;

    final d = p.kdsDate;
    final dateLabel =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('🥗 SUBSCRIPTION KITCHEN',
            style:
                GoogleFonts.chivo(fontSize: 20, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: isManager
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => context.go('/subs'),
              )
            : null,
        actions: [
          TextButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: p.kdsDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 7)),
              );
              if (picked != null) p.setKdsDate(picked);
            },
            icon: const Icon(Icons.calendar_today,
                size: 18, color: Colors.black87),
            label: Text(dateLabel,
                style: GoogleFonts.chivo(
                    fontWeight: FontWeight.w800, color: Colors.black87)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: p.fetchMeals,
          ),
        ],
      ),
      body: Column(
        children: [
          _summaryBar(toPrepare, prepared, pendingCount, byPref),
          Expanded(
            child: active.isEmpty
                ? KdsEmptyState(message: 'No confirmed meals for $dateLabel')
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: active.length,
                    itemBuilder: (_, i) => _kitchenCard(p, active[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar(
      int toPrepare, int prepared, int pending, Map<String, int> byPref) {
    Widget stat(String label, String value, Color color) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(value,
                    style: GoogleFonts.chivo(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
                Text(label,
                    style: GoogleFonts.chivo(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[700],
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              stat('TO PREPARE', '$toPrepare', Colors.blue[800]!),
              stat('PREPARED', '$prepared', Colors.green[700]!),
              stat('PENDING', '$pending', Colors.red[700]!),
            ],
          ),
          if (byPref.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: byPref.entries.map((e) {
                  // Members can each have a different assigned dish now, so
                  // there's no single "the dish" for a preference — count only.
                  final label = e.key.replaceAll('_', '-').toUpperCase();
                  return Chip(
                    label: Text('$label × ${e.value}',
                        style: GoogleFonts.chivo(
                            fontSize: 11, fontWeight: FontWeight.w800)),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _kitchenCard(SubscriptionAdminProvider p, Map<String, dynamic> m) {
    final sub = (m['subscriptions'] as Map?)?.cast<String, dynamic>() ?? {};
    final total = _mealsOf(m);
    final done = (m['prepared_count'] as num?)?.toInt() ?? 0;
    final priority = (m['priority'] as num?)?.toInt() ?? 0;
    final isPrepared = m['status'] == 'prepared';
    final prefKey = (sub['food_preference'] ?? '') as String;
    final pref = prefKey.replaceAll('_', '-').toUpperCase();
    final goal =
        ((sub['health_goal'] ?? '') as String).replaceAll('_', ' ').toUpperCase();
    final notes = (sub['health_notes'] ?? '') as String;
    // This member's own assigned dish (Meal Planner → ASSIGN tab), not a
    // shared per-preference default — each member can have a different one.
    final dish = (m['subscription_meals'] as Map?)?.cast<String, dynamic>();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isPrepared
              ? Colors.green
              : priority > 0
                  ? Colors.red
                  : Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Prepared checkbox — the chef's single tap.
            Checkbox(
              value: isPrepared,
              activeColor: Colors.green[700],
              onChanged: (v) {
                if (v == true) {
                  p.updateMeal(m['id'] as String, {
                    'status': 'prepared',
                    'prepared_count': total,
                    'prepared_at': DateTime.now().toIso8601String(),
                  });
                } else {
                  p.updateMeal(m['id'] as String,
                      {'status': 'confirmed', 'prepared_count': 0});
                }
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${sub['customer_name'] ?? 'Member'}  ${sub['member_code'] ?? ''}',
                          style: GoogleFonts.chivo(
                              fontSize: 15, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (priority > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(Icons.priority_high,
                              size: 16, color: Colors.red[700]),
                        ),
                    ],
                  ),
                  Text(
                    '$total meal${total > 1 ? 's' : ''}'
                    '${pref.isNotEmpty ? ' · $pref' : ''}'
                    '${goal.isNotEmpty ? ' · $goal' : ''}',
                    style: GoogleFonts.inter(
                        fontSize: 12.5, color: Colors.grey[800]),
                  ),
                  if (dish != null)
                    Text(
                      '🍽 ${dish['name']}',
                      style: GoogleFonts.chivo(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.indigo[800]),
                    ),
                  if (notes.isNotEmpty)
                    Text('⚠ $notes',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: Colors.deepOrange[800])),
                ],
              ),
            ),
            // Prepared x / total
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isPrepared ? Colors.green[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$done / $total',
                  style: GoogleFonts.chivo(
                      fontSize: 14, fontWeight: FontWeight.w800)),
            ),
            // Priority stepper.
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () =>
                      p.setPriority(m['id'] as String, priority + 1),
                  child: const Icon(Icons.keyboard_arrow_up, size: 22),
                ),
                Text('P$priority',
                    style: GoogleFonts.chivo(
                        fontSize: 11, fontWeight: FontWeight.w800)),
                InkWell(
                  onTap: priority > 0
                      ? () => p.setPriority(m['id'] as String, priority - 1)
                      : null,
                  child: Icon(Icons.keyboard_arrow_down,
                      size: 22,
                      color: priority > 0 ? Colors.black87 : Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
