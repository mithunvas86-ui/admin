import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/menu_item.dart';
import '../providers/admin_menu_provider.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  @override
  void initState() {
    super.initState();
    context.read<AdminMenuProvider>().fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu Manager',
            style: GoogleFonts.chivo(
                fontSize: 24, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () => _openItemForm(context, null),
              icon: const Icon(Icons.add),
              label: const Text('Add Product'),
            ),
          ),
        ],
      ),
      body: Consumer<AdminMenuProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CategoryBar(provider: provider),
              const Divider(height: 1),
              Expanded(
                child: provider.items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.restaurant_menu,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('No menu items yet',
                                style: GoogleFonts.chivo(fontSize: 18)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _openItemForm(context, null),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Product'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: provider.items.length,
                        itemBuilder: (context, index) =>
                            _MenuItemCard(
                              item: provider.items[index],
                              provider: provider,
                              onEdit: () => _openItemForm(
                                  context, provider.items[index]),
                              onDelete: () => _showDeleteConfirm(
                                  context, provider.items[index].id),
                            ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openItemForm(BuildContext context, MenuItem? existing) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ItemFormDialog(existing: existing),
    );
  }

  void _showDeleteConfirm(BuildContext context, String itemId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<AdminMenuProvider>().deleteItem(itemId);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu item card
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final AdminMenuProvider provider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuItemCard({
    required this.item,
    required this.provider,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasLimit = item.dailyLimit != null && item.dailyLimit! > 0;
    final progress =
        hasLimit ? (item.ordersToday / item.dailyLimit!).clamp(0.0, 1.0) : 0.0;
    final isClosed = item.isSoldOut;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isClosed ? Colors.red.shade300 : Colors.transparent,
          width: isClosed ? 1.5 : 0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imageUrl != null
                      ? Image.network(item.imageUrl!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder())
                      : _imagePlaceholder(),
                ),
                if (isClosed)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        color: Colors.black54,
                        child: const Icon(Icons.notifications_off,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: GoogleFonts.chivo(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isClosed ? Colors.grey : null,
                    ),
                  ),
                ),
                if (isClosed)
                  const Icon(Icons.notifications_off,
                      size: 16, color: Colors.orange),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.category}  •  ₹${item.price.toStringAsFixed(0)}',
                  style: GoogleFonts.chivo(fontSize: 12, color: Colors.grey),
                ),
                if (hasLimit)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${item.ordersToday}/${item.dailyLimit} orders today',
                      style: GoogleFonts.chivo(
                        fontSize: 11,
                        color: isClosed ? Colors.red : Colors.blueGrey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: item.available,
                  onChanged: (val) =>
                      provider.toggleAvailability(item.id, val),
                  activeColor: Colors.green,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) async {
                    if (action == 'edit') onEdit();
                    if (action == 'delete') onDelete();
                    if (action == 'reset') {
                      await provider.resetTodayCount(item.id);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit')),
                    if (hasLimit)
                      const PopupMenuItem(
                          value: 'reset',
                          child: Text('Reset Today\'s Count')),
                    const PopupMenuItem(
                        value: 'delete',
                        child:
                            Text('Delete', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ],
            ),
          ),
          // Daily limit progress bar
          if (hasLimit)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: progress >= 1.0
                          ? Colors.red
                          : progress >= 0.8
                              ? Colors.orange
                              : Colors.green,
                    ),
                  ),
                  if (isClosed)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_off,
                              size: 13, color: Colors.red),
                          const SizedBox(width: 4),
                          Text(
                            'Item closed — daily limit reached',
                            style: GoogleFonts.chivo(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.image, color: Colors.grey),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit item dialog
// ─────────────────────────────────────────────────────────────────────────────

class _ItemFormDialog extends StatefulWidget {
  final MenuItem? existing;
  const _ItemFormDialog({this.existing});

  @override
  State<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<_ItemFormDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _servingCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fiberCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();

  String? _badge;
  bool _available = true;
  bool _hasLimit = false;
  File? _imageFile;
  Uint8List? _imageBytes;
  String _category = '';
  bool _saving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _priceCtrl.text = e.price.toStringAsFixed(0);
      _descCtrl.text = e.description;
      _category = e.category;
      _badge = e.badge;
      _available = e.available;
      _servingCtrl.text = e.servingSize;
      _kcalCtrl.text = e.kcal > 0 ? e.kcal.toString() : '';
      _proteinCtrl.text = e.protein > 0 ? e.protein.toStringAsFixed(1) : '';
      _carbsCtrl.text = e.carbs > 0 ? e.carbs.toStringAsFixed(1) : '';
      _fatCtrl.text = e.fat > 0 ? e.fat.toStringAsFixed(1) : '';
      _fiberCtrl.text = e.fiber > 0 ? e.fiber.toStringAsFixed(1) : '';
      _hasLimit = e.dailyLimit != null && e.dailyLimit! > 0;
      _limitCtrl.text = _hasLimit ? e.dailyLimit.toString() : '';
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _servingCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (!kIsWeb) _imageFile = File(picked.path);
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _save(BuildContext ctx) async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);

    final provider = ctx.read<AdminMenuProvider>();
    final dynamic imgArg = kIsWeb ? _imageBytes : _imageFile;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final kcal = int.tryParse(_kcalCtrl.text) ?? 0;
    final protein = double.tryParse(_proteinCtrl.text) ?? 0;
    final carbs = double.tryParse(_carbsCtrl.text) ?? 0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0;
    final fiber = double.tryParse(_fiberCtrl.text) ?? 0;
    final limit =
        _hasLimit ? (int.tryParse(_limitCtrl.text) ?? 0) : null;

    try {
      if (widget.existing == null) {
        await provider.addItem(
          name: _nameCtrl.text.trim(),
          price: price,
          category: _category,
          description: _descCtrl.text,
          badge: _badge,
          imageFile: imgArg,
          available: _available,
          kcal: kcal,
          servingSize: _servingCtrl.text,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: fiber,
          dailyLimit: limit,
        );
      } else {
        await provider.updateItem(
          itemId: widget.existing!.id,
          name: _nameCtrl.text.trim(),
          price: price,
          description: _descCtrl.text,
          category: _category,
          badge: _badge,
          imageFile: imgArg,
          available: _available,
          kcal: kcal,
          servingSize: _servingCtrl.text,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: fiber,
          dailyLimit: limit,
          clearDailyLimit: !_hasLimit,
        );
      }
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(widget.existing == null
              ? 'Product added successfully!'
              : 'Product updated successfully!'),
        ));
        Navigator.pop(ctx);
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AdminMenuProvider>();
    final categories = provider.categories;
    if (_category.isEmpty) {
      _category = categories.isNotEmpty ? categories.first : 'Main';
    }
    if (!categories.contains(_category)) {
      _category = categories.isNotEmpty ? categories.first : 'Main';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                children: [
                  Text(
                    widget.existing == null ? 'Add Menu Item' : 'Edit Menu Item',
                    style: GoogleFonts.chivo(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // ── Tabs ─────────────────────────────────────────────
            TabBar(
              controller: _tabs,
              labelStyle: GoogleFonts.chivo(
                  fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'BASIC INFO'),
                Tab(text: 'NUTRITION'),
                Tab(text: 'AVAILABILITY'),
              ],
            ),
            const Divider(height: 1),
            // ── Tab Content ──────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _BasicTab(
                    nameCtrl: _nameCtrl,
                    priceCtrl: _priceCtrl,
                    descCtrl: _descCtrl,
                    category: _category,
                    categories: categories,
                    badge: _badge,
                    imageBytes: _imageBytes,
                    existingImageUrl: widget.existing?.imageUrl,
                    onCategoryChanged: (v) =>
                        setState(() => _category = v ?? _category),
                    onBadgeChanged: (v) => setState(() => _badge = v),
                    onPickImage: _pickImage,
                  ),
                  _NutritionTab(
                    servingCtrl: _servingCtrl,
                    kcalCtrl: _kcalCtrl,
                    proteinCtrl: _proteinCtrl,
                    carbsCtrl: _carbsCtrl,
                    fatCtrl: _fatCtrl,
                    fiberCtrl: _fiberCtrl,
                  ),
                  _AvailabilityTab(
                    available: _available,
                    hasLimit: _hasLimit,
                    limitCtrl: _limitCtrl,
                    ordersToday: widget.existing?.ordersToday ?? 0,
                    onAvailableChanged: (v) =>
                        setState(() => _available = v),
                    onHasLimitChanged: (v) =>
                        setState(() => _hasLimit = v),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Actions ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saving ? null : () => _save(context),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(widget.existing == null ? 'Add' : 'Update'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Basic Info ───────────────────────────────────────────────────────────

class _BasicTab extends StatelessWidget {
  final TextEditingController nameCtrl, priceCtrl, descCtrl;
  final String category;
  final List<String> categories;
  final String? badge;
  final Uint8List? imageBytes;
  final String? existingImageUrl;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onBadgeChanged;
  final VoidCallback onPickImage;

  const _BasicTab({
    required this.nameCtrl,
    required this.priceCtrl,
    required this.descCtrl,
    required this.category,
    required this.categories,
    required this.badge,
    required this.imageBytes,
    required this.existingImageUrl,
    required this.onCategoryChanged,
    required this.onBadgeChanged,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(
                labelText: 'Item Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: priceCtrl,
            decoration: const InputDecoration(
                labelText: 'Price (₹)',
                prefixText: '₹',
                border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: categories.contains(category) ? category : categories.first,
            decoration: const InputDecoration(
                labelText: 'Category', border: OutlineInputBorder()),
            items: categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: onCategoryChanged,
          ),
          const SizedBox(height: 12),
          // Badge selector
          Row(
            children: [
              Text('Badge:',
                  style: GoogleFonts.chivo(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              _BadgeChip(
                label: 'VEG',
                color: Colors.green,
                selected: badge == 'VEG',
                onTap: () => onBadgeChanged(badge == 'VEG' ? null : 'VEG'),
              ),
              const SizedBox(width: 8),
              _BadgeChip(
                label: 'NON-VEG',
                color: Colors.red,
                selected: badge == 'NON-VEG',
                onTap: () =>
                    onBadgeChanged(badge == 'NON-VEG' ? null : 'NON-VEG'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Image
          Row(
            children: [
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(imageBytes!,
                      height: 100, width: 100, fit: BoxFit.cover),
                )
              else if (existingImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(existingImageUrl!,
                      height: 100, width: 100, fit: BoxFit.cover),
                )
              else
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.image, size: 40, color: Colors.grey),
                ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.photo_library),
                label: const Text('Pick Image'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab: Nutrition ─────────────────────────────────────────────────────────────

class _NutritionTab extends StatelessWidget {
  final TextEditingController servingCtrl, kcalCtrl, proteinCtrl, carbsCtrl,
      fatCtrl, fiberCtrl;

  const _NutritionTab({
    required this.servingCtrl,
    required this.kcalCtrl,
    required this.proteinCtrl,
    required this.carbsCtrl,
    required this.fatCtrl,
    required this.fiberCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nutrition Information',
              style: GoogleFonts.chivo(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('All values are per serving',
              style: GoogleFonts.chivo(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 14),
          TextField(
            controller: servingCtrl,
            decoration: const InputDecoration(
                labelText: 'Serving Size',
                hintText: 'e.g. 300g, 1 bowl, 250ml',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: kcalCtrl,
            decoration: const InputDecoration(
                labelText: 'Calories (kcal)',
                suffixText: 'kcal',
                border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          Text('Macronutrients',
              style: GoogleFonts.chivo(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: proteinCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Protein',
                      suffixText: 'g',
                      border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: carbsCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Carbs',
                      suffixText: 'g',
                      border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: fatCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Fat',
                      suffixText: 'g',
                      border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: fiberCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Fiber',
                      suffixText: 'g',
                      border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab: Availability ──────────────────────────────────────────────────────────

class _AvailabilityTab extends StatelessWidget {
  final bool available;
  final bool hasLimit;
  final TextEditingController limitCtrl;
  final int ordersToday;
  final ValueChanged<bool> onAvailableChanged;
  final ValueChanged<bool> onHasLimitChanged;

  const _AvailabilityTab({
    required this.available,
    required this.hasLimit,
    required this.limitCtrl,
    required this.ordersToday,
    required this.onAvailableChanged,
    required this.onHasLimitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enable/Disable toggle
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                  color: available ? Colors.green : Colors.red, width: 1.5),
              borderRadius: BorderRadius.circular(8),
              color: (available ? Colors.green : Colors.red)
                  .withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Icon(
                  available ? Icons.check_circle : Icons.notifications_off,
                  color: available ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        available ? 'Item is ENABLED' : 'Item is DISABLED',
                        style: GoogleFonts.chivo(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: available ? Colors.green : Colors.red,
                        ),
                      ),
                      Text(
                        available
                            ? 'Customers can order this item'
                            : 'Item is hidden with a bell icon — not orderable',
                        style: GoogleFonts.chivo(
                            fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: available,
                  onChanged: onAvailableChanged,
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Daily limit
          Row(
            children: [
              Text('Daily Order Limit',
                  style: GoogleFonts.chivo(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              const Spacer(),
              Switch(
                value: hasLimit,
                onChanged: onHasLimitChanged,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set the maximum number of orders per day. '
            'Once reached, the item is automatically disabled with a bell icon.',
            style: GoogleFonts.chivo(fontSize: 12, color: Colors.grey[600]),
          ),
          if (hasLimit) ...[
            const SizedBox(height: 12),
            TextField(
              controller: limitCtrl,
              decoration: const InputDecoration(
                labelText: 'Max orders per day',
                hintText: 'e.g. 50',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.format_list_numbered),
              ),
              keyboardType: TextInputType.number,
            ),
            if (ordersToday > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Today: $ordersToday orders placed so far',
                      style: GoogleFonts.chivo(
                          fontSize: 12, color: Colors.blue.shade800),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category bar
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryBar extends StatelessWidget {
  final AdminMenuProvider provider;
  const _CategoryBar({required this.provider});

  void _showAddCategoryDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g. Pasta, Grills…'),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                context.read<AdminMenuProvider>().addCategory(ctrl.text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = provider.categories;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return Chip(
                  label: Text(cat,
                      style: GoogleFonts.chivo(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    final count = provider.items
                        .where((i) => i.category == cat)
                        .length;
                    if (count > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            '$cat has $count item(s). Remove items first.'),
                        backgroundColor: Colors.orange,
                      ));
                    } else {
                      provider.removeCategory(cat);
                    }
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Category',
              onPressed: () => _showAddCategoryDialog(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge chip
// ─────────────────────────────────────────────────────────────────────────────

class _BadgeChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _BadgeChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
