// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_admin_provider.dart';
import '../providers/auth_provider.dart';

/// Subscription Kitchen Display + delivery assignment.
///
/// KITCHEN tab — confirmed meals for the selected date, sorted by priority:
///   • header totals: to prepare / prepared / pending, split by preference
///   • per-meal checkbox marks it PREPARED, ▲▼ adjusts priority
/// DELIVERY tab — prepared meals: assign a delivery agent, then move the meal
/// through out_for_delivery → delivered.
class SubscriptionKdsPage extends StatefulWidget {
  const SubscriptionKdsPage({super.key});

  @override
  State<SubscriptionKdsPage> createState() => _SubscriptionKdsPageState();
}

class _SubscriptionKdsPageState extends State<SubscriptionKdsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    final p = context.read<SubscriptionAdminProvider>();
    p.fetchMeals();
    p.fetchEditors(); // delivery agents for the assignment dropdown
    p.startAutoRefresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
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
    final isManager = adminAuth.role == 'admin' || adminAuth.role == 'sub_manager';

    final active = p.meals
        .where((m) => ['confirmed', 'preparing', 'prepared']
            .contains(m['status']))
        .toList();
    final forDelivery = p.meals
        .where((m) => ['prepared', 'out_for_delivery', 'delivered']
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
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.black87,
          indicatorColor: Colors.black87,
          labelStyle: GoogleFonts.chivo(fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: 'KITCHEN (${active.length})'),
            Tab(text: 'DELIVERY (${forDelivery.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── KITCHEN ─────────────────────────────────────────────────────
          Column(
            children: [
              _summaryBar(toPrepare, prepared, pendingCount, byPref),
              Expanded(
                child: active.isEmpty
                    ? _empty('No confirmed meals for $dateLabel')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: active.length,
                        itemBuilder: (_, i) =>
                            _kitchenCard(p, active[i], isManager),
                      ),
              ),
            ],
          ),
          // ── DELIVERY ────────────────────────────────────────────────────
          forDelivery.isEmpty
              ? _empty('Nothing ready for delivery yet')
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: forDelivery.length,
                  itemBuilder: (_, i) =>
                      _deliveryCard(p, forDelivery[i], isManager),
                ),
        ],
      ),
    );
  }

  Widget _empty(String msg) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.done_all, size: 64, color: Colors.green),
            const SizedBox(height: 12),
            Text(msg,
                style: GoogleFonts.chivo(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700])),
          ],
        ),
      );

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
                  final p = context.read<SubscriptionAdminProvider>();
                  final dish = (p.scheduleByPref[e.key]?['subscription_meals']
                          as Map?)?['name'] as String?;
                  final label = e.key.replaceAll('_', '-').toUpperCase();
                  return Chip(
                    label: Text(
                        '$label × ${e.value}${dish != null ? '  ·  $dish' : ''}',
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

  Widget _kitchenCard(
      SubscriptionAdminProvider p, Map<String, dynamic> m, bool isManager) {
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
    // Today's scheduled dish for this member's preference (Meal Planner).
    final dish = (p.scheduleByPref[prefKey]?['subscription_meals'] as Map?)
        ?.cast<String, dynamic>();

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
            // Priority stepper (manager or chef).
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

  /// Same delivery-address block as the main admin KDS: blue "DELIVER TO"
  /// panel with street / landmark / city — pincode and an OPEN IN MAPS link
  /// built from the map-picker pin (maps_link or lat/lng).
  Widget _deliveryAddressBlock(Map<String, dynamic> deliveryAddress) {
    final street = (deliveryAddress['address'] ?? '').toString();
    final landmark = (deliveryAddress['landmark'] ?? '').toString();
    final city = (deliveryAddress['city'] ?? '').toString();
    final pincode = (deliveryAddress['pincode'] ?? '').toString();
    final cityLine = [city, pincode].where((v) => v.isNotEmpty).join(' — ');
    final mapsUrl = () {
      final link = (deliveryAddress['maps_link'] ?? '').toString();
      if (link.isNotEmpty) return link;
      final lat = (deliveryAddress['latitude'] ?? '').toString();
      final lng = (deliveryAddress['longitude'] ?? '').toString();
      if (lat.isNotEmpty && lng.isNotEmpty) {
        return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      }
      return '';
    }();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: const Color(0xFFE3F2FD),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 13, color: Color(0xFF1565C0)),
              const SizedBox(width: 4),
              Text(
                'DELIVER TO',
                style: GoogleFonts.chivo(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1565C0),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          if (street.isNotEmpty)
            Text(
              street,
              style: GoogleFonts.chivo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (landmark.isNotEmpty)
            Text(
              'Near: $landmark',
              style: GoogleFonts.chivo(fontSize: 11, color: Colors.black54),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (cityLine.isNotEmpty)
            Text(
              cityLine,
              style: GoogleFonts.chivo(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87),
            ),
          if (mapsUrl.isNotEmpty) ...[
            const SizedBox(height: 5),
            InkWell(
              onTap: () => html.window.open(mapsUrl, '_blank'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.navigation,
                      size: 13, color: Color(0xFF1565C0)),
                  const SizedBox(width: 4),
                  Text('OPEN IN MAPS',
                      style: GoogleFonts.chivo(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1565C0),
                          letterSpacing: 0.5,
                          decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _deliveryCard(
      SubscriptionAdminProvider p, Map<String, dynamic> m, bool isManager) {
    final sub = (m['subscriptions'] as Map?)?.cast<String, dynamic>() ?? {};
    final address =
        (sub['delivery_address'] as Map?)?.cast<String, dynamic>() ?? {};
    final status = (m['status'] ?? '') as String;
    final agentId = m['delivery_agent_id'] as String?;
    final activeAgents =
        p.agents.where((a) => a['active'] != false).toList();
    // Keep an already-assigned (now inactive) agent selectable so the
    // dropdown value stays valid.
    if (agentId != null && !activeAgents.any((a) => a['id'] == agentId)) {
      final match = p.agents.where((a) => a['id'] == agentId);
      if (match.isNotEmpty) activeAgents.add(match.first);
    }

    final statusColor = switch (status) {
      'prepared' => Colors.orange[800]!,
      'out_for_delivery' => Colors.blue[800]!,
      _ => Colors.green[700]!,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${sub['customer_name'] ?? 'Member'} · ${sub['phone'] ?? ''}',
                    style: GoogleFonts.chivo(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.chivo(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: statusColor)),
                ),
              ],
            ),
            if (address.isNotEmpty) ...[
              const SizedBox(height: 8),
              _deliveryAddressBlock(address),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: agentId,
                    hint: const Text('Assign delivery agent'),
                    isDense: true,
                    items: activeAgents
                        .map((a) => DropdownMenuItem(
                              value: a['id'] as String,
                              child: Text('${a['name']}'),
                            ))
                        .toList(),
                    onChanged: isManager && status != 'delivered'
                        ? (v) => p.assignAgent(m['id'] as String, v)
                        : null,
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (status == 'prepared')
                  ElevatedButton(
                    onPressed: agentId == null
                        ? null
                        : () => p.setMealStatus(
                            m['id'] as String, 'out_for_delivery'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white),
                    child: Text('SEND OUT',
                        style:
                            GoogleFonts.chivo(fontWeight: FontWeight.w800)),
                  )
                else if (status == 'out_for_delivery')
                  ElevatedButton(
                    onPressed: () =>
                        p.setMealStatus(m['id'] as String, 'delivered'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white),
                    child: Text('DELIVERED',
                        style:
                            GoogleFonts.chivo(fontWeight: FontWeight.w800)),
                  )
                else
                  const Icon(Icons.done_all, color: Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
