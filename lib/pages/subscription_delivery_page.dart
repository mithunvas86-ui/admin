// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_admin_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/kds_empty_state.dart';

/// Subscription delivery/dispatch view — split out of the former combined
/// subscription_kds_page.dart. Prepared meals: assign a delivery agent, then
/// move the meal through out_for_delivery → delivered.
///
/// No kitchen/prep concerns here — see subscription_chef_page.dart.
class SubscriptionDeliveryPage extends StatefulWidget {
  const SubscriptionDeliveryPage({super.key});

  @override
  State<SubscriptionDeliveryPage> createState() =>
      _SubscriptionDeliveryPageState();
}

class _SubscriptionDeliveryPageState extends State<SubscriptionDeliveryPage> {
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
    context.read<SubscriptionAdminProvider>().stopAutoRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SubscriptionAdminProvider>();
    final isManager =
        adminAuth.role == 'admin' || adminAuth.role == 'sub_manager';

    final forDelivery = p.meals
        .where((m) => ['prepared', 'out_for_delivery', 'delivered']
            .contains(m['status']))
        .toList();

    final d = p.kdsDate;
    final dateLabel =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('🚚 SUBSCRIPTION DELIVERY',
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
      body: forDelivery.isEmpty
          ? const KdsEmptyState(message: 'Nothing ready for delivery yet')
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: forDelivery.length,
              itemBuilder: (_, i) =>
                  _deliveryCard(p, forDelivery[i], isManager),
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
                    initialValue: agentId,
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
