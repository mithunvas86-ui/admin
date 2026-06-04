import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
            style: GoogleFonts.chivo(fontSize: 24, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () => _showAddItemDialog(context),
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
              // Category chips row
              _CategoryBar(provider: provider),
              const Divider(height: 1),
              // Menu items list
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
                              onPressed: () => _showAddItemDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Product'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.items.length,
                        itemBuilder: (context, index) {
                          final item = provider.items[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: ListTile(
                              leading: item.imageUrl != null
                                  ? Image.network(item.imageUrl!,
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover)
                                  : Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey[300]),
                              title: Text(item.name),
                              subtitle: Text('₹${item.price}'),
                              trailing: PopupMenuButton(
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    child: const Text('Edit'),
                                    onTap: () =>
                                        _showEditItemDialog(context, item),
                                  ),
                                  PopupMenuItem(
                                    child: const Text('Delete'),
                                    onTap: () =>
                                        _showDeleteConfirm(context, item.id),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddItemDialog(BuildContext context) {
    final provider = context.read<AdminMenuProvider>();
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? selectedBadge;
    File? selectedImage;
    Uint8List? imageBytes;
    final picker = ImagePicker();

    // Use first available category as default
    String category =
        provider.categories.isNotEmpty ? provider.categories.first : 'Main';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final categories = provider.categories;
          if (!categories.contains(category)) {
            category = categories.isNotEmpty ? categories.first : 'Main';
          }

          return AlertDialog(
            title: const Text('Add Menu Item'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Item Name'),
                  ),
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: descCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: categories.contains(category)
                        ? category
                        : categories.first,
                    decoration:
                        const InputDecoration(labelText: 'Category'),
                    items: categories
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => category = val ?? category),
                  ),
                  const SizedBox(height: 12),
                  // Veg / Non-Veg badge selector
                  Row(
                    children: [
                      const Text('Badge:',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 12),
                      _BadgeChip(
                        label: 'VEG',
                        color: Colors.green,
                        selected: selectedBadge == 'VEG',
                        onTap: () => setDialogState(() =>
                            selectedBadge =
                                selectedBadge == 'VEG' ? null : 'VEG'),
                      ),
                      const SizedBox(width: 8),
                      _BadgeChip(
                        label: 'NON-VEG',
                        color: Colors.red,
                        selected: selectedBadge == 'NON-VEG',
                        onTap: () => setDialogState(() =>
                            selectedBadge =
                                selectedBadge == 'NON-VEG' ? null : 'NON-VEG'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (imageBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(imageBytes!,
                          height: 150, width: 150, fit: BoxFit.cover),
                    )
                  else
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image,
                          size: 64, color: Colors.grey),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pickedFile =
                          await picker.pickImage(source: ImageSource.gallery);
                      if (pickedFile != null) {
                        final bytes = await pickedFile.readAsBytes();
                        if (!kIsWeb) selectedImage = File(pickedFile.path);
                        setDialogState(() => imageBytes = bytes);
                      }
                    },
                    icon: const Icon(Icons.photo),
                    label: const Text('Pick Image'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isNotEmpty &&
                      priceCtrl.text.isNotEmpty) {
                    try {
                      await ctx.read<AdminMenuProvider>().addItem(
                            name: nameCtrl.text,
                            price: double.parse(priceCtrl.text),
                            description: descCtrl.text,
                            category: category,
                            badge: selectedBadge,
                            imageFile: kIsWeb ? imageBytes : selectedImage,
                          );
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content: Text('Product added successfully!')),
                        );
                        Navigator.pop(ctx);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    }
                  }
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditItemDialog(BuildContext context, dynamic item) {
    final provider = context.read<AdminMenuProvider>();
    final nameCtrl = TextEditingController(text: item.name);
    final priceCtrl = TextEditingController(text: item.price.toString());
    final descCtrl = TextEditingController(text: item.description as String? ?? '');
    String category = item.category as String;
    String? selectedBadge = item.badge as String?;
    File? selectedImage;
    Uint8List? imageBytes;
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final categories = provider.categories;
          if (!categories.contains(category)) {
            category = categories.isNotEmpty ? categories.first : 'Main';
          }
          return AlertDialog(
          title: const Text('Edit Menu Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                ),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Price'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categories.contains(category) ? category : categories.first,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => category = val ?? category),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Badge:', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 12),
                    _BadgeChip(
                      label: 'VEG',
                      color: Colors.green,
                      selected: selectedBadge == 'VEG',
                      onTap: () => setDialogState(() =>
                          selectedBadge = selectedBadge == 'VEG' ? null : 'VEG'),
                    ),
                    const SizedBox(width: 8),
                    _BadgeChip(
                      label: 'NON-VEG',
                      color: Colors.red,
                      selected: selectedBadge == 'NON-VEG',
                      onTap: () => setDialogState(() =>
                          selectedBadge = selectedBadge == 'NON-VEG' ? null : 'NON-VEG'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (imageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(imageBytes!,
                        height: 150, width: 150, fit: BoxFit.cover),
                  )
                else if (item.imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item.imageUrl!,
                        height: 150, width: 150, fit: BoxFit.cover),
                  )
                else
                  Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        const Icon(Icons.image, size: 64, color: Colors.grey),
                  ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final pickedFile =
                        await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      if (!kIsWeb) selectedImage = File(pickedFile.path);
                      setDialogState(() => imageBytes = bytes);
                    }
                  },
                  icon: const Icon(Icons.photo),
                  label: const Text('Pick Image'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ctx.read<AdminMenuProvider>().updateItem(
                        itemId: item.id,
                        name: nameCtrl.text,
                        price: double.parse(priceCtrl.text),
                        description: descCtrl.text,
                        category: category,
                        badge: selectedBadge,
                        imageFile: kIsWeb ? imageBytes : selectedImage,
                      );
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('Product updated successfully!')),
                    );
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
        },
      ),
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
          decoration: const InputDecoration(hintText: 'e.g. Pasta, Grills…'),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    final itemsInCat =
                        provider.items.where((i) => i.category == cat).length;
                    if (itemsInCat > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '$cat has $itemsInCat item(s). Remove items first.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } else {
                      provider.removeCategory(cat);
                    }
                  },
                );
              },
            ),
          ),
          // + button to add new category
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
