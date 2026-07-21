import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_admin_provider.dart';

/// No-code control room for the subscription programme:
///   PLANS      — create/edit the plans & pricing shown in the customer app
///   BANNERS    — the promo banners on the customer home page
///   WHATSAPP   — edit every automated message + API credentials + "send now"
///   AGENTS     — delivery agent roster
/// Every change here is live in production without touching code.
class SubscriptionSettingsPage extends StatefulWidget {
  const SubscriptionSettingsPage({super.key});

  @override
  State<SubscriptionSettingsPage> createState() =>
      _SubscriptionSettingsPageState();
}

class _SubscriptionSettingsPageState extends State<SubscriptionSettingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    context.read<SubscriptionAdminProvider>().fetchEditors();
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
        title: Text('SUBSCRIPTION SETTINGS',
            style:
                GoogleFonts.chivo(fontSize: 20, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/subs'),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.black87,
          indicatorColor: Colors.black87,
          isScrollable: true,
          labelStyle: GoogleFonts.chivo(fontWeight: FontWeight.w800),
          tabs: const [
            Tab(text: 'PLANS'),
            Tab(text: 'BANNERS'),
            Tab(text: 'WHATSAPP'),
            Tab(text: 'AGENTS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _plansTab(p),
          _bannersTab(p),
          _whatsappTab(p),
          _agentsTab(p),
        ],
      ),
    );
  }

  // ── PLANS ──────────────────────────────────────────────────────────────────

  Widget _plansTab(SubscriptionAdminProvider p) {
    return ListView(
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
                    style: GoogleFonts.chivo(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    '${plan['meals_per_day']} meal(s)/day'
                    '${(plan['badge'] ?? '').toString().isNotEmpty ? ' · badge: ${plan['badge']}' : ''}'
                    '${plan['active'] == false ? ' · HIDDEN' : ''}',
                    style: GoogleFonts.inter(fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: plan['active'] != false,
                      onChanged: (v) async {
                        final err = await p
                            .savePlan({'id': plan['id'], 'active': v});
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
      ],
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
    final days =
        TextEditingController(text: plan?['duration_days']?.toString() ?? '30');
    final mealsDay =
        TextEditingController(text: plan?['meals_per_day']?.toString() ?? '1');
    final badge = TextEditingController(text: plan?['badge'] as String? ?? '');
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
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextField(
                          controller: mealsDay,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Meals/day'))),
                ]),
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
    final err = await context.read<SubscriptionAdminProvider>().savePlan({
      if (plan != null) 'id': plan['id'],
      'name': name.text.trim(),
      'tagline': tagline.text.trim(),
      'description': desc.text.trim(),
      'price': double.tryParse(price.text) ?? 0,
      'compare_at_price': double.tryParse(comparePrice.text) ?? 0,
      'duration_days': int.tryParse(days.text) ?? 30,
      'meals_per_day': int.tryParse(mealsDay.text) ?? 1,
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

  // ── BANNERS ────────────────────────────────────────────────────────────────

  Widget _bannersTab(SubscriptionAdminProvider p) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ElevatedButton.icon(
          onPressed: () => _bannerDialog(),
          icon: const Icon(Icons.add),
          label: const Text('NEW BANNER'),
        ),
        const SizedBox(height: 12),
        ...p.banners.map((b) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(b['title'] as String? ?? '',
                    style: GoogleFonts.chivo(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    '${b['subtitle'] ?? ''}'
                    '${b['active'] == false ? '  · HIDDEN' : ''}',
                    style: GoogleFonts.inter(fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: b['active'] != false,
                      onChanged: (v) async {
                        final err = await p
                            .saveBanner({'id': b['id'], 'active': v});
                        if (err != null) _toast(err, ok: false);
                      },
                    ),
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _bannerDialog(banner: b)),
                    IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => p.deleteBanner(b['id'] as String)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Future<void> _bannerDialog({Map<String, dynamic>? banner}) async {
    final title =
        TextEditingController(text: banner?['title'] as String? ?? '');
    final subtitle =
        TextEditingController(text: banner?['subtitle'] as String? ?? '');
    final image =
        TextEditingController(text: banner?['image_url'] as String? ?? '');
    final cta = TextEditingController(
        text: banner?['cta_text'] as String? ?? 'See Plans');
    final color = TextEditingController(
        text: banner?['bg_color'] as String? ?? '#1B3A2D');
    final sort =
        TextEditingController(text: banner?['sort_order']?.toString() ?? '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(banner == null ? 'New banner' : 'Edit banner'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: title,
                    decoration:
                        const InputDecoration(labelText: 'Title (headline)')),
                TextField(
                    controller: subtitle,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Subtitle')),
                TextField(
                    controller: image,
                    decoration: const InputDecoration(
                        labelText: 'Image URL (optional)')),
                TextField(
                    controller: cta,
                    decoration:
                        const InputDecoration(labelText: 'Button text')),
                TextField(
                    controller: color,
                    decoration: const InputDecoration(
                        labelText: 'Background colour (hex, e.g. #1B3A2D)')),
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
    final err = await context.read<SubscriptionAdminProvider>().saveBanner({
      if (banner != null) 'id': banner['id'],
      'title': title.text.trim(),
      'subtitle': subtitle.text.trim(),
      'image_url': image.text.trim(),
      'cta_text': cta.text.trim(),
      'bg_color': color.text.trim(),
      'sort_order': int.tryParse(sort.text) ?? 0,
    });
    _toast(err ?? 'Banner saved ✅', ok: err == null);
  }

  // ── WHATSAPP ───────────────────────────────────────────────────────────────

  Widget _whatsappTab(SubscriptionAdminProvider p) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NIGHTLY AUTOMATION',
                    style: GoogleFonts.chivo(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  'Every night at the time below, the system messages each '
                  'active member asking if they want tomorrow\'s meal. '
                  'Replies (YES/NO) update the kitchen automatically.',
                  style: GoogleFonts.inter(fontSize: 13),
                ),
                const SizedBox(height: 10),
                _ReminderTimeEditor(provider: p, onToast: _toast),
                const SizedBox(height: 10),
                Text('Or trigger it right now:',
                    style: GoogleFonts.inter(fontSize: 13)),
                const SizedBox(height: 6),
                ElevatedButton.icon(
                  onPressed: () async {
                    final msg = await p.sendTonightNow();
                    if (mounted) _toast(msg ?? 'Done');
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('SEND TONIGHT\'S QUESTION NOW'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('MESSAGE TEMPLATES',
            style:
                GoogleFonts.chivo(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(
          'Placeholders: {{name}} {{date}} {{plan}} {{meal}} {{member_code}} {{cutoff_time}}',
          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
        ),
        const SizedBox(height: 8),
        ...p.templates.map((t) => _TemplateCard(
              template: t,
              onSave: (text, active) async {
                final err =
                    await p.saveTemplate(t['id'] as String, text, active);
                _toast(err ?? 'Message updated ✅', ok: err == null);
              },
            )),
        const SizedBox(height: 16),
        _CredentialsCard(provider: p, onToast: _toast),
      ],
    );
  }

  // ── AGENTS ─────────────────────────────────────────────────────────────────

  Widget _agentsTab(SubscriptionAdminProvider p) {
    final name = TextEditingController();
    final phone = TextEditingController();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Agent name'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: phone,
                        decoration:
                            const InputDecoration(labelText: 'Phone'))),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty) return;
                    p.addAgent(name.text.trim(), phone.text.trim());
                    name.clear();
                    phone.clear();
                  },
                  child: const Text('ADD'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...p.agents.map((a) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.delivery_dining,
                    color:
                        a['active'] != false ? Colors.green : Colors.grey),
                title: Text(a['name'] as String? ?? '',
                    style: GoogleFonts.chivo(fontWeight: FontWeight.w700)),
                subtitle: Text(a['phone'] as String? ?? ''),
                trailing: Switch(
                  value: a['active'] != false,
                  onChanged: (v) => p.toggleAgent(a['id'] as String, v),
                ),
              ),
            )),
      ],
    );
  }
}

/// Inline editor for one WhatsApp template.
class _TemplateCard extends StatefulWidget {
  final Map<String, dynamic> template;
  final Future<void> Function(String text, bool active) onSave;

  const _TemplateCard({required this.template, required this.onSave});

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  late final TextEditingController _text = TextEditingController(
      text: widget.template['message_text'] as String? ?? '');
  late bool _active = widget.template['active'] != false;
  bool _dirty = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.template['title'] as String? ?? '',
                      style: GoogleFonts.chivo(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                ),
                Switch(
                  value: _active,
                  onChanged: (v) => setState(() {
                    _active = v;
                    _dirty = true;
                  }),
                ),
              ],
            ),
            TextField(
              controller: _text,
              maxLines: null,
              style: GoogleFonts.inter(fontSize: 13.5),
              onChanged: (_) => setState(() => _dirty = true),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            if (_dirty)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ElevatedButton(
                    onPressed: () async {
                      await widget.onSave(_text.text, _active);
                      if (mounted) setState(() => _dirty = false);
                    },
                    child: const Text('SAVE MESSAGE'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Editable send time (IST) for the nightly meal-reminder WhatsApp message.
/// Stored in app_config; the edge function polls every 5 minutes and only
/// actually sends once past this time each day.
class _ReminderTimeEditor extends StatefulWidget {
  final SubscriptionAdminProvider provider;
  final void Function(String, {bool ok}) onToast;

  const _ReminderTimeEditor({required this.provider, required this.onToast});

  @override
  State<_ReminderTimeEditor> createState() => _ReminderTimeEditorState();
}

class _ReminderTimeEditorState extends State<_ReminderTimeEditor> {
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    widget.provider.loadMealReminderTime().then((v) {
      if (!mounted) return;
      setState(() {
        _time = TimeOfDay(hour: v['hour'] ?? 20, minute: v['minute'] ?? 0);
        _loaded = true;
      });
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final err =
        await widget.provider.saveMealReminderTime(_time.hour, _time.minute);
    widget.onToast(err ?? 'Reminder time saved ✅', ok: err == null);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loaded ? _pickTime : null,
            icon: const Icon(Icons.schedule),
            label: Text(_loaded ? _time.format(context) : 'Loading…'),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loaded ? _save : null,
          child: const Text('SAVE TIME'),
        ),
      ],
    );
  }
}

/// WhatsApp Business API credentials (stored in app_config, used by the
/// automation edge functions). Filled in once the numbers arrive from Meta.
class _CredentialsCard extends StatefulWidget {
  final SubscriptionAdminProvider provider;
  final void Function(String, {bool ok}) onToast;

  const _CredentialsCard({required this.provider, required this.onToast});

  @override
  State<_CredentialsCard> createState() => _CredentialsCardState();
}

class _CredentialsCardState extends State<_CredentialsCard> {
  final _token = TextEditingController();
  final _phoneId = TextEditingController();
  bool _loaded = false;
  bool _hideToken = true;

  @override
  void initState() {
    super.initState();
    widget.provider.loadWhatsAppConfig().then((v) {
      if (!mounted) return;
      setState(() {
        _token.text = (v['access_token'] ?? '') as String;
        _phoneId.text = (v['phone_number_id'] ?? '') as String;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _token.dispose();
    _phoneId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WHATSAPP API CREDENTIALS',
                style: GoogleFonts.chivo(
                    fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 4),
            Text(
              'From Meta Business → WhatsApp → API Setup. Messages start '
              'flowing automatically once these are saved.',
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[700]),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _token,
              obscureText: _hideToken,
              enabled: _loaded,
              decoration: InputDecoration(
                labelText: 'Access token',
                suffixIcon: IconButton(
                  icon: Icon(
                      _hideToken ? Icons.visibility : Icons.visibility_off,
                      size: 20),
                  onPressed: () => setState(() => _hideToken = !_hideToken),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneId,
              enabled: _loaded,
              decoration:
                  const InputDecoration(labelText: 'Phone number ID'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final err = await widget.provider.saveWhatsAppConfig({
                  'access_token': _token.text.trim(),
                  'phone_number_id': _phoneId.text.trim(),
                });
                widget.onToast(err ?? 'Credentials saved ✅', ok: err == null);
              },
              child: const Text('SAVE CREDENTIALS'),
            ),
          ],
        ),
      ),
    );
  }
}
