import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/subscription_admin_provider.dart';

/// MEAL PLANNER — admin/manager customise the subscription meals here.
/// Mirrors the dining menu-management panel, but for the SEPARATE
/// subscription catalogue (`subscription_meals`), since the subscription
/// model runs its own kitchen while sharing the single customer website.
///
///   MEAL LIBRARY — CRUD dishes: photo, description, preference, macros.
///   DAILY MENU   — assign the dish served on a date, per food preference.
///                  Feeds the KDS, the member app and the WhatsApp message.
class SubscriptionMealsPage extends StatefulWidget {
  const SubscriptionMealsPage({super.key});

  @override
  State<SubscriptionMealsPage> createState() => _SubscriptionMealsPageState();
}

class _SubscriptionMealsPageState extends State<SubscriptionMealsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  DateTime _menuDate = DateTime.now().add(const Duration(days: 1));

  static const _prefs = [
    ('veg', 'VEGETARIAN', Colors.green),
    ('non_veg', 'NON-VEG', Colors.red),
    ('eggetarian', 'EGGETARIAN', Colors.orange),
    ('vegan', 'VEGAN', Colors.teal),
  ];

  @override
  void initState() {
    super.initState();
    final p = context.read<SubscriptionAdminProvider>();
    p.fetchMealLibrary();
    p.fetchSchedule(_menuDate);
    p.fetchGroups();
    p.fetchSubscriptions();
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
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
        title: Text('MEAL PLANNER',
            style:
                GoogleFonts.chivo(fontSize: 20, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => context.go('/subs'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              p.fetchMealLibrary();
              p.fetchSchedule(_menuDate);
              p.fetchGroups();
              p.fetchSubscriptions();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.black87,
          indicatorColor: Colors.black87,
          labelStyle: GoogleFonts.chivo(fontWeight: FontWeight.w800),
          tabs: [
            Tab(text: 'MEAL LIBRARY (${p.mealLibrary.length})'),
            const Tab(text: 'DAILY MENU'),
            const Tab(text: 'ASSIGN'),
          ],
        ),
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _dishDialog(),
              icon: const Icon(Icons.add),
              label: Text('NEW DISH',
                  style: GoogleFonts.chivo(fontWeight: FontWeight.w800)),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [_libraryTab(p), _dailyMenuTab(p), _assignTab(p)],
      ),
    );
  }

  // ── MEAL LIBRARY ───────────────────────────────────────────────────────────

  Widget _libraryTab(SubscriptionAdminProvider p) {
    if (p.mealLibrary.isEmpty) {
      return Center(
        child: Text('No dishes yet — add your first one',
            style: GoogleFonts.chivo(fontSize: 15, color: Colors.grey[600])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: p.mealLibrary.length,
      itemBuilder: (_, i) {
        final dish = p.mealLibrary[i];
        final prefMeta = _prefs.firstWhere(
          (x) => x.$1 == dish['food_preference'],
          orElse: () => ('all', 'ALL DIETS', Colors.blueGrey),
        );
        final img = (dish['image_url'] ?? '') as String;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: img.isNotEmpty
                      ? Image.network(img,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imgPlaceholder())
                      : _imgPlaceholder(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dish['name'] as String? ?? '',
                          style: GoogleFonts.chivo(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      if ((dish['description'] ?? '').toString().isNotEmpty)
                        Text(dish['description'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 12.5, color: Colors.grey[700])),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        children: [
                          _chip(prefMeta.$2, prefMeta.$3),
                          if ((dish['kcal'] ?? 0) != 0)
                            _chip('${dish['kcal']} KCAL', Colors.blueGrey),
                          if ((dish['protein'] ?? 0) != 0)
                            _chip('${dish['protein']}g PROTEIN', Colors.indigo),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: dish['active'] != false,
                  onChanged: (v) async {
                    final err = await p
                        .saveMealDish({'id': dish['id'], 'active': v});
                    if (err != null) _toast(err, ok: false);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _dishDialog(dish: dish),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(dish),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 64,
        height: 64,
        color: Colors.grey[300],
        child: const Icon(Icons.restaurant, color: Colors.white70),
      );

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: GoogleFonts.chivo(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );

  Future<void> _confirmDelete(Map<String, dynamic> dish) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${dish['name']}"?'),
        content: const Text(
            'It will also disappear from any day it was scheduled on.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context
          .read<SubscriptionAdminProvider>()
          .deleteMealDish(dish['id'] as String);
    }
  }

  Future<void> _dishDialog({Map<String, dynamic>? dish}) async {
    final name = TextEditingController(text: dish?['name'] as String? ?? '');
    final desc =
        TextEditingController(text: dish?['description'] as String? ?? '');
    final kcal = TextEditingController(text: '${dish?['kcal'] ?? ''}');
    final protein = TextEditingController(text: '${dish?['protein'] ?? ''}');
    final carbs = TextEditingController(text: '${dish?['carbs'] ?? ''}');
    final fat = TextEditingController(text: '${dish?['fat'] ?? ''}');
    final serving =
        TextEditingController(text: dish?['serving_size'] as String? ?? '');
    String pref = dish?['food_preference'] as String? ?? 'all';
    Uint8List? imageBytes;
    final picker = ImagePicker();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(dish == null ? 'New dish' : 'Edit dish'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Photo
                  InkWell(
                    onTap: () async {
                      final picked = await picker.pickImage(
                          source: ImageSource.gallery, maxWidth: 1200);
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setState(() => imageBytes = bytes);
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imageBytes != null
                          ? Image.memory(imageBytes!, fit: BoxFit.cover)
                          : ((dish?['image_url'] ?? '')
                                  .toString()
                                  .isNotEmpty
                              ? Image.network(dish!['image_url'] as String,
                                  fit: BoxFit.cover)
                              : const Center(
                                  child: Icon(Icons.add_a_photo,
                                      color: Colors.grey))),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: name,
                      decoration:
                          const InputDecoration(labelText: 'Dish name')),
                  TextField(
                      controller: desc,
                      maxLines: 2,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  DropdownButtonFormField<String>(
                    initialValue: pref,
                    items: const [
                      DropdownMenuItem(
                          value: 'all', child: Text('All diets')),
                      DropdownMenuItem(value: 'veg', child: Text('Vegetarian')),
                      DropdownMenuItem(
                          value: 'non_veg', child: Text('Non-Vegetarian')),
                      DropdownMenuItem(
                          value: 'eggetarian', child: Text('Eggetarian')),
                      DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
                    ],
                    onChanged: (v) => setState(() => pref = v ?? 'all'),
                    decoration:
                        const InputDecoration(labelText: 'Suitable for'),
                  ),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: kcal,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'kcal'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: protein,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Protein g'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: carbs,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Carbs g'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: fat,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'Fat g'))),
                  ]),
                  TextField(
                      controller: serving,
                      decoration: const InputDecoration(
                          labelText: 'Serving size (e.g. 400 g)')),
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
      ),
    );
    if (ok != true || !mounted) return;
    if (name.text.trim().isEmpty) {
      _toast('Dish name is required', ok: false);
      return;
    }
    final err = await context.read<SubscriptionAdminProvider>().saveMealDish(
      {
        if (dish != null) 'id': dish['id'],
        'name': name.text.trim(),
        'description': desc.text.trim(),
        'food_preference': pref,
        'kcal': int.tryParse(kcal.text) ?? 0,
        'protein': double.tryParse(protein.text) ?? 0,
        'carbs': double.tryParse(carbs.text) ?? 0,
        'fat': double.tryParse(fat.text) ?? 0,
        'serving_size': serving.text.trim(),
      },
      imageFile: imageBytes,
    );
    _toast(err ?? 'Dish saved ✅', ok: err == null);
  }

  // ── DAILY MENU ─────────────────────────────────────────────────────────────

  Widget _dailyMenuTab(SubscriptionAdminProvider p) {
    final dateLabel =
        '${_menuDate.day.toString().padLeft(2, '0')}/${_menuDate.month.toString().padLeft(2, '0')}/${_menuDate.year}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text('Menu for $dateLabel',
                style: GoogleFonts.chivo(fontWeight: FontWeight.w800)),
            subtitle: Text(
                'Add every dish available this day, per preference. Then use '
                'the ASSIGN tab to give a specific one to a member or group.',
                style: GoogleFonts.inter(fontSize: 12.5)),
            trailing: ElevatedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _menuDate,
                  firstDate:
                      DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) {
                  setState(() => _menuDate = picked);
                  p.fetchSchedule(picked);
                }
              },
              child: const Text('CHANGE DATE'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ..._prefs.map((prefMeta) {
          final (key, label, color) = prefMeta;
          final scheduled = p.scheduleByPref[key] ?? const [];
          final scheduledIds =
              scheduled.map((r) => r['meal_id'] as String).toSet();
          // Dishes suitable for this preference (its own tag, or 'all') not
          // already on the day's menu — the "+ add" picker's choices.
          final addable = p.mealLibrary
              .where((d) =>
                  d['active'] != false &&
                  !scheduledIds.contains(d['id']) &&
                  (d['food_preference'] == key ||
                      d['food_preference'] == 'all'))
              .toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chip(label, color),
                  const SizedBox(height: 10),
                  if (scheduled.isEmpty)
                    Text('No dishes added yet',
                        style: GoogleFonts.inter(
                            fontSize: 13, color: Colors.grey[600]))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: scheduled.map((row) {
                        final dish =
                            (row['subscription_meals'] as Map?)?.cast<String, dynamic>();
                        final mealId = row['meal_id'] as String;
                        return Chip(
                          label: Text(dish?['name'] as String? ?? 'Dish'),
                          backgroundColor: color.withValues(alpha: 0.12),
                          onDeleted: () async {
                            final err = await p.removeDishFromSchedule(
                                _menuDate, key, mealId);
                            if (err != null) _toast(err, ok: false);
                          },
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 8),
                  if (addable.isNotEmpty)
                    DropdownButton<String>(
                      value: null,
                      hint: const Text('+ Add dish'),
                      isDense: true,
                      items: addable
                          .map((d) => DropdownMenuItem<String>(
                                value: d['id'] as String,
                                child: Text(
                                    '${d['name']}${(d['kcal'] ?? 0) != 0 ? '  ·  ${d['kcal']} kcal' : ''}'),
                              ))
                          .toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        final err =
                            await p.addDishToSchedule(_menuDate, key, v);
                        if (err != null) _toast(err, ok: false);
                      },
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ── ASSIGN ─────────────────────────────────────────────────────────────────

  Widget _assignTab(SubscriptionAdminProvider p) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('GROUPS',
                        style: GoogleFonts.chivo(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _groupDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('NEW GROUP'),
                    ),
                  ],
                ),
                if (p.groups.isEmpty)
                  Text('No groups yet — create one to bulk-assign dishes',
                      style: GoogleFonts.inter(
                          fontSize: 12.5, color: Colors.grey[600]))
                else
                  ...p.groups.map((g) {
                    final count = p.members
                        .where((m) => m['group_id'] == g['id'])
                        .length;
                    final prefMeta = _prefs.firstWhere(
                        (x) => x.$1 == g['food_preference'],
                        orElse: () => ('', '', Colors.grey));
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(g['name'] as String? ?? ''),
                      subtitle: Text('${prefMeta.$2} · $count member(s)'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _groupDialog(group: g),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                size: 18, color: Colors.red),
                            onPressed: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text('Delete "${g['name']}"?'),
                                  content: const Text(
                                      'Members lose this group tag; any '
                                      'dishes already assigned to them are '
                                      'unaffected.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[700]),
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text('DELETE'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await p.deleteGroup(g['id'] as String);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ASSIGN TO A GROUP',
                    style: GoogleFonts.chivo(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 8),
                _GroupAssignRow(provider: p, date: _menuDate, onToast: _toast),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ASSIGN TO ONE MEMBER',
                    style: GoogleFonts.chivo(
                        fontWeight: FontWeight.w800, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Overrides that member\'s group assignment for this day.',
                    style:
                        GoogleFonts.inter(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 8),
                _MemberAssignRow(provider: p, date: _menuDate, onToast: _toast),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _groupDialog({Map<String, dynamic>? group}) async {
    final name = TextEditingController(text: group?['name'] as String? ?? '');
    String pref = group?['food_preference'] as String? ?? 'veg';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(group == null ? 'New group' : 'Edit group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Group name')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: pref,
                items: _prefs
                    .map((x) => DropdownMenuItem(
                        value: x.$1, child: Text(x.$2)))
                    .toList(),
                onChanged: (v) => setState(() => pref = v ?? pref),
                decoration: const InputDecoration(labelText: 'Food preference'),
              ),
            ],
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
      ),
    );
    if (ok != true || !mounted) return;
    if (name.text.trim().isEmpty) {
      _toast('Group name is required', ok: false);
      return;
    }
    final err = await context.read<SubscriptionAdminProvider>().saveGroup({
      if (group != null) 'id': group['id'],
      'name': name.text.trim(),
      'food_preference': pref,
    });
    _toast(err ?? 'Group saved ✅', ok: err == null);
  }
}

/// Pick a group + a dish (filtered to the group's preference) → bulk assign.
class _GroupAssignRow extends StatefulWidget {
  final SubscriptionAdminProvider provider;
  final DateTime date;
  final void Function(String, {bool ok}) onToast;

  const _GroupAssignRow(
      {required this.provider, required this.date, required this.onToast});

  @override
  State<_GroupAssignRow> createState() => _GroupAssignRowState();
}

class _GroupAssignRowState extends State<_GroupAssignRow> {
  String? _groupId;
  String? _mealId;

  @override
  Widget build(BuildContext context) {
    final groups = widget.provider.groups;
    if (groups.isEmpty) {
      return Text('Create a group above first',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]));
    }
    final group = groups.firstWhere((g) => g['id'] == _groupId,
        orElse: () => const {});
    final pref = group['food_preference'] as String?;
    final dishes = pref == null
        ? const <Map<String, dynamic>>[]
        : (widget.provider.scheduleByPref[pref] ?? const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _groupId,
          hint: const Text('Pick a group'),
          items: groups
              .map((g) => DropdownMenuItem(
                  value: g['id'] as String, child: Text(g['name'] as String)))
              .toList(),
          onChanged: (v) => setState(() {
            _groupId = v;
            _mealId = null;
          }),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        if (_groupId != null)
          dishes.isEmpty
              ? Text('No dishes on this day\'s menu for that preference yet',
                  style:
                      GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[600]))
              : DropdownButtonFormField<String>(
                  initialValue: _mealId,
                  hint: const Text('Pick a dish'),
                  items: dishes
                      .map((r) => DropdownMenuItem(
                            value: r['meal_id'] as String,
                            child: Text((r['subscription_meals']
                                    as Map?)?['name'] as String? ??
                                'Dish'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _mealId = v),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (_groupId == null || _mealId == null)
              ? null
              : () async {
                  final err = await widget.provider
                      .assignMealToGroup(_groupId!, widget.date, _mealId!);
                  widget.onToast(err ?? 'Assigned to group ✅', ok: err == null);
                },
          child: const Text('ASSIGN TO GROUP'),
        ),
      ],
    );
  }
}

/// Pick a member + a dish (filtered to their preference) → individual assign.
class _MemberAssignRow extends StatefulWidget {
  final SubscriptionAdminProvider provider;
  final DateTime date;
  final void Function(String, {bool ok}) onToast;

  const _MemberAssignRow(
      {required this.provider, required this.date, required this.onToast});

  @override
  State<_MemberAssignRow> createState() => _MemberAssignRowState();
}

class _MemberAssignRowState extends State<_MemberAssignRow> {
  String? _subscriptionId;
  String? _mealId;
  String? _currentDishName;
  bool _loadingCurrent = false;

  Future<void> _loadCurrent(String subscriptionId) async {
    setState(() => _loadingCurrent = true);
    final row =
        await widget.provider.fetchMemberAssignment(subscriptionId, widget.date);
    if (!mounted) return;
    setState(() {
      _currentDishName =
          (row?['subscription_meals'] as Map?)?['name'] as String?;
      _loadingCurrent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.provider.members;
    if (members.isEmpty) {
      return Text('No active members yet',
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]));
    }
    final member = members.firstWhere((m) => m['id'] == _subscriptionId,
        orElse: () => const {});
    final pref = member['food_preference'] as String?;
    final dishes = pref == null
        ? const <Map<String, dynamic>>[]
        : (widget.provider.scheduleByPref[pref] ?? const []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _subscriptionId,
          hint: const Text('Pick a member'),
          items: members
              .map((m) => DropdownMenuItem(
                    value: m['id'] as String,
                    child: Text((m['customer_name'] as String?) ?? 'Unnamed'),
                  ))
              .toList(),
          onChanged: (v) {
            setState(() {
              _subscriptionId = v;
              _mealId = null;
              _currentDishName = null;
            });
            if (v != null) _loadCurrent(v);
          },
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        if (_subscriptionId != null) ...[
          const SizedBox(height: 6),
          Text(
            _loadingCurrent
                ? 'Checking current assignment…'
                : 'Currently assigned: ${_currentDishName ?? '— none —'}',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
        const SizedBox(height: 8),
        if (_subscriptionId != null)
          dishes.isEmpty
              ? Text('No dishes on this day\'s menu for that preference yet',
                  style:
                      GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[600]))
              : DropdownButtonFormField<String>(
                  initialValue: _mealId,
                  hint: const Text('Pick a dish'),
                  items: dishes
                      .map((r) => DropdownMenuItem(
                            value: r['meal_id'] as String,
                            child: Text((r['subscription_meals']
                                    as Map?)?['name'] as String? ??
                                'Dish'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _mealId = v),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: (_subscriptionId == null || _mealId == null)
              ? null
              : () async {
                  final err = await widget.provider.assignMealToMember(
                      _subscriptionId!, widget.date, _mealId!);
                  widget.onToast(err ?? 'Assigned ✅', ok: err == null);
                  if (err == null) await _loadCurrent(_subscriptionId!);
                },
          child: const Text('ASSIGN TO MEMBER'),
        ),
      ],
    );
  }
}
