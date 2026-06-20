import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/supabase_service.dart';

/// Admin page to set per order-type availability windows. Saved to
/// app_config.service_hours; the customer app reads it to gate ordering.
class ServiceHoursPage extends StatefulWidget {
  const ServiceHoursPage({super.key});

  @override
  State<ServiceHoursPage> createState() => _ServiceHoursPageState();
}

class _TypeHours {
  bool enabled;
  TimeOfDay open;
  TimeOfDay close;
  _TypeHours(this.enabled, this.open, this.close);
}

class _ServiceHoursPageState extends State<ServiceHoursPage> {
  static const _types = ['dine_in', 'takeaway', 'delivery'];
  static const _labels = {
    'dine_in': 'Dine In',
    'takeaway': 'Takeaway',
    'delivery': 'Delivery',
  };
  final Map<String, _TypeHours> _cfg = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  TimeOfDay _parse(String? s, TimeOfDay fb) {
    if (s == null || !s.contains(':')) return fb;
    final p = s.split(':');
    return TimeOfDay(
        hour: int.tryParse(p[0]) ?? fb.hour,
        minute: int.tryParse(p[1]) ?? fb.minute);
  }

  String _fmt24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    try {
      final res = await SupabaseService.client
          .from('app_config')
          .select('value')
          .eq('key', 'service_hours')
          .maybeSingle();
      final v = (res?['value'] as Map?)?.cast<String, dynamic>() ?? {};
      for (final t in _types) {
        final m = (v[t] as Map?)?.cast<String, dynamic>() ?? {};
        _cfg[t] = _TypeHours(
          (m['enabled'] as bool?) ?? true,
          _parse(m['open'] as String?, const TimeOfDay(hour: 9, minute: 0)),
          _parse(m['close'] as String?, const TimeOfDay(hour: 21, minute: 0)),
        );
      }
    } catch (_) {
      for (final t in _types) {
        _cfg[t] = _TypeHours(true, const TimeOfDay(hour: 9, minute: 0),
            const TimeOfDay(hour: 21, minute: 0));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final value = {
      for (final t in _types)
        t: {
          'enabled': _cfg[t]!.enabled,
          'open': _fmt24(_cfg[t]!.open),
          'close': _fmt24(_cfg[t]!.close),
        }
    };
    try {
      await SupabaseService.client.from('app_config').upsert(
        {'key': 'service_hours', 'value': value},
        onConflict: 'key',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Service hours saved ✓')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Save failed: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pick(String t, bool isOpen) async {
    final picked = await showTimePicker(
        context: context,
        initialTime: isOpen ? _cfg[t]!.open : _cfg[t]!.close);
    if (picked != null) {
      setState(() {
        if (isOpen) {
          _cfg[t]!.open = picked;
        } else {
          _cfg[t]!.close = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/')),
        title: Text('SERVICE HOURS',
            style: GoogleFonts.chivo(fontSize: 18, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  "Set when each order type is available. Outside these hours, "
                  "customers can't place that order type.",
                  style: GoogleFonts.chivo(fontSize: 12, color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                ..._types.map(_card),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text('SAVE',
                            style:
                                GoogleFonts.chivo(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _card(String t) {
    final c = _cfg[t]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_labels[t]!.toUpperCase(),
                  style: GoogleFonts.chivo(
                      fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              Switch(
                  value: c.enabled,
                  onChanged: (v) => setState(() => c.enabled = v)),
            ],
          ),
          if (c.enabled)
            Row(
              children: [
                Expanded(child: _timeBox('OPEN', c.open, () => _pick(t, true))),
                const SizedBox(width: 12),
                Expanded(
                    child: _timeBox('CLOSE', c.close, () => _pick(t, false))),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Disabled — customers cannot order ${_labels[t]}',
                  style:
                      GoogleFonts.chivo(fontSize: 12, color: Colors.red[700])),
            ),
        ],
      ),
    );
  }

  Widget _timeBox(String label, TimeOfDay t, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.chivo(fontSize: 9, color: Colors.grey[600])),
            Text(t.format(context),
                style: GoogleFonts.chivo(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
