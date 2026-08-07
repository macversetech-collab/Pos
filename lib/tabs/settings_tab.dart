import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models.dart';
import '../widgets/anchored_dropdown.dart';

class SettingsTab extends StatefulWidget {
  final List<CakeSize> sizes;
  final List<CakeItem> items;
  final PrinterSettings settings;
  final VoidCallback onSaveSettings;
  final ValueChanged<CakeSize> onAddSize;
  final void Function(String id, String name, int price) onEditSize;
  final ValueChanged<String> onDeleteSize;
  final ValueChanged<CakeItem> onAddItem;
  final ValueChanged<String> onDeleteItem;
  final void Function(String id, String newName) onEditItemName;
  final void Function(String itemId, String size, String variant, int price)
  onSavePricing;
  final void Function(String itemId, String size, String variant)
  onDeletePricing;

  const SettingsTab({
    super.key,
    required this.sizes,
    required this.items,
    required this.settings,
    required this.onSaveSettings,
    required this.onAddSize,
    required this.onEditSize,
    required this.onDeleteSize,
    required this.onAddItem,
    required this.onDeleteItem,
    required this.onEditItemName,
    required this.onSavePricing,
    required this.onDeletePricing,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final TextEditingController _sizeNameController = TextEditingController();
  final TextEditingController _sizePriceController = TextEditingController();
  final TextEditingController _itemNameController = TextEditingController();

  @override
  void dispose() {
    _sizeNameController.dispose();
    _sizePriceController.dispose();
    _itemNameController.dispose();
    super.dispose();
  }

  void _showEditSizeDialog(CakeSize size) {
    final nameCtrl = TextEditingController(text: size.name);
    final priceCtrl = TextEditingController(text: size.basePrice.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Edit Size: ${size.name}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D241E),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: AppDecorations.input(
                  labelText: 'Size Dimension Name',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: AppDecorations.input(labelText: 'Base Price (MMK)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D241E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final newName = nameCtrl.text.trim();
                final newPrice = int.tryParse(priceCtrl.text) ?? 0;
                if (newName.isNotEmpty) {
                  widget.onEditSize(size.id, newName, newPrice);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INVENTORY & LAYOUT CONFIGURATOR',
            style: TextStyle(
              color: Color(0xFF2D241E),
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure cake catalog parameters and customize printing voucher templates',
            style: TextStyle(color: Color(0xFF8C7E6A), fontSize: 11),
          ),
          const SizedBox(height: 16),

          // 1. CAKE SIZES METADATA CARD
          _buildCard(
            title: 'Cake Sizes (Metadata Only)',
            badgeText: '${widget.sizes.length} SIZES AVAILABLE',
            children: [
              // Config Tip Alert Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFD4A373).withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Color(0xFFD4A373),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Configuration Tip: One or more sizes have non-zero base prices, but individual size prices are ignored. Use Cake Item & Size Combos below for pricing configurations.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF8C7E6A),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Sizes List
              ...widget.sizes.map((size) {
                return _buildListRow(
                  label: size.name,
                  price: size.basePrice,
                  onEdit: () => _showEditSizeDialog(size),
                  onDelete: () => widget.onDeleteSize(size.id),
                );
              }),
              const SizedBox(height: 12),

              // Add Size Form Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _sizeNameController,
                      decoration: AppDecorations.input(
                        hintText: 'New Size (e.g. 12 inch)',
                        filled: true,
                        fillColor: const Color(0xFFFAF9F6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _sizePriceController,
                      keyboardType: TextInputType.number,
                      decoration: AppDecorations.input(
                        hintText: 'Base Price (MMK)',
                        filled: true,
                        fillColor: const Color(0xFFFAF9F6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D241E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final name = _sizeNameController.text.trim();
                      final price =
                          int.tryParse(_sizePriceController.text) ?? 0;
                      if (name.isNotEmpty) {
                        widget.onAddSize(
                          CakeSize(
                            id: 'size-${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            basePrice: price,
                          ),
                        );
                        _sizeNameController.clear();
                        _sizePriceController.clear();
                      }
                    },
                    child: const Text(
                      '+ ADD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. CAKE ITEM & SIZE CATALOG CARD
          _buildCard(
            title: 'Cake Item & Size Catalog',
            badgeText: '${widget.items.length} ITEMS AVAILABLE',
            children: [
              // Dynamic Item-Variant Catalog List
              ...widget.items.map((item) {
                return _ItemCatalogCard(
                  item: item,
                  sizes: widget.sizes,
                  onEditName: (newName) =>
                      widget.onEditItemName(item.id, newName),
                  onDeleteItem: () => widget.onDeleteItem(item.id),
                  onSavePricing: (size, variant, price) =>
                      widget.onSavePricing(item.id, size, variant, price),
                  onDeletePricing: (size, variant) =>
                      widget.onDeletePricing(item.id, size, variant),
                );
              }),
              const SizedBox(height: 12),

              // Add Parent Item Form Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _itemNameController,
                      decoration: AppDecorations.input(
                        hintText: 'e.g. Red Velvet Cake',
                        filled: true,
                        fillColor: const Color(0xFFFAF9F6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D241E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final name = _itemNameController.text.trim();
                      if (name.isNotEmpty) {
                        widget.onAddItem(
                          CakeItem(
                            id: 'item-${DateTime.now().millisecondsSinceEpoch}',
                            name: name,
                            sizes: [],
                            variants: [],
                            pricing: {},
                          ),
                        );
                        _itemNameController.clear();
                      }
                    },
                    child: const Text(
                      '+ CREATE ITEM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. VOUCHER PRINTING TEMPLATE/SHOP PROFILE CONFIG CARD
          _buildCard(
            title: 'Bakery Shop Profile Config',
            children: [
              TextFormField(
                initialValue: widget.settings.bakeryName,
                decoration: AppDecorations.input(
                  labelText: 'Shop Bakery Name',
                  hintText: 'e.g. Sweet Bloom Artisan Bakery',
                ),
                onChanged: (val) => widget.settings.bakeryName = val.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: widget.settings.footerNotes,
                maxLines: 2,
                decoration: AppDecorations.input(
                  labelText: 'Voucher Footer Note',
                  hintText: 'e.g. Thank you! Keep refrigerated.',
                ),
                onChanged: (val) => widget.settings.footerNotes = val.trim(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D241E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: widget.onSaveSettings,
                  child: const Text(
                    'Save Configured Branding Info',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    String? badgeText,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: const Color(0xFFEAE7E2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF2D241E),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEAE7E2)),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF8C7E6A),
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24, thickness: 1.0, color: Color(0xFFEAE7E2)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildListRow({
    required String label,
    required int price,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFEAE7E2), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D241E),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF9F6),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: const Color(0xFFEAE7E2)),
            ),
            child: Text(
              '${price.toLocaleString()} MMK',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2D241E),
                fontFamily: 'JetBrains Mono',
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF8C7E6A),
              size: 18,
            ),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Color(0xFF8C7E6A),
              size: 18,
            ),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _ItemCatalogCard extends StatefulWidget {
  final CakeItem item;
  final List<CakeSize> sizes;
  final void Function(String name) onEditName;
  final VoidCallback onDeleteItem;
  final void Function(String size, String variant, int price) onSavePricing;
  final void Function(String size, String variant) onDeletePricing;

  const _ItemCatalogCard({
    required this.item,
    required this.sizes,
    required this.onEditName,
    required this.onDeleteItem,
    required this.onSavePricing,
    required this.onDeletePricing,
  });

  @override
  State<_ItemCatalogCard> createState() => _ItemCatalogCardState();
}

class _ItemCatalogCardState extends State<_ItemCatalogCard> {
  String? _selectedSize;
  final TextEditingController _variantController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sizes.isNotEmpty) {
      _selectedSize = widget.sizes[0].name;
    }
  }

  @override
  void didUpdateWidget(_ItemCatalogCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedSize == null && widget.sizes.isNotEmpty) {
      _selectedSize = widget.sizes[0].name;
    }
  }

  @override
  void dispose() {
    _variantController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showEditPricingDialog(String size, String variant, int currentPrice) {
    final priceCtrl = TextEditingController(text: currentPrice.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Edit Price ($size - $variant)',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D241E),
            ),
          ),
          content: TextFormField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            decoration: AppDecorations.input(labelText: 'Price (MMK)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D241E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final newPrice = int.tryParse(priceCtrl.text) ?? 0;
                widget.onSavePricing(size, variant, newPrice);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditNameDialog() {
    final nameCtrl = TextEditingController(text: widget.item.name);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Edit Item Name',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D241E),
            ),
          ),
          content: TextFormField(
            controller: nameCtrl,
            decoration: AppDecorations.input(labelText: 'Item Name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D241E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                final newName = nameCtrl.text.trim();
                if (newName.isNotEmpty) {
                  widget.onEditName(newName);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pricingKeys = widget.item.pricing.keys.toList()..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFFEAE7E2), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D241E),
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Color(0xFF8C7E6A),
                      size: 18,
                    ),
                    onPressed: _showEditNameDialog,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      size: 18,
                    ),
                    onPressed: widget.onDeleteItem,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16, color: Color(0xFFEAE7E2)),

          if (pricingKeys.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No design/size variations added yet.',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            )
          else
            ...pricingKeys.map((key) {
              final parts = key.split(':');
              final s = parts[0];
              final v = parts[1];
              final price = widget.item.pricing[key] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 6.0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: const Color(0xFFEAE7E2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$s size - $v',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2D241E),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F6),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: const Color(0xFFEAE7E2)),
                      ),
                      child: Text(
                        '${price.toLocaleString()} MMK',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D241E),
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Color(0xFF8C7E6A),
                        size: 16,
                      ),
                      onPressed: () => _showEditPricingDialog(s, v, price),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFF8C7E6A),
                        size: 16,
                      ),
                      onPressed: () => widget.onDeletePricing(s, v),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: AnchoredDropdown<String>(
                  initialValue: _selectedSize,
                  decoration: AppDecorations.input(
                    hintText: 'Size',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSize = val);
                    }
                  },
                  items: widget.sizes.map((sz) {
                    return DropdownMenuItem(
                      value: sz.name,
                      child: Text(sz.name),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _variantController,
                  decoration: AppDecorations.input(
                    hintText: 'e.g. Lava',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: AppDecorations.input(
                    hintText: 'Price (MMK)',
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D241E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  final sz = _selectedSize;
                  final vr = _variantController.text.trim();
                  final pr = int.tryParse(_priceController.text) ?? 0;
                  if (sz != null && vr.isNotEmpty) {
                    widget.onSavePricing(sz, vr, pr);
                    _variantController.clear();
                    _priceController.clear();
                  }
                },
                child: const Text(
                  '+ ADD',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
