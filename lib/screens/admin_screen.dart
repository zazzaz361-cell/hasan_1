import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../app_controller.dart';
import '../data/repositories.dart';
import '../models/restaurant.dart';
import '../ui/brand.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _section = 0;

  static const _sections = [
    'نظرة عامة',
    'المنتجات',
    'الفئات',
    'إدارة QR',
    'إعدادات الاتصال',
    'إعدادات المطعم',
  ];

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      appBar: AppBar(
        title: const DariWordmark(compact: true),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('العودة'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (!narrow)
            _AdminSidebar(
              sections: _sections,
              selected: _section,
              onSelected: _openSection,
            ),
          Expanded(
            child: Column(
              children: [
                if (narrow)
                  SizedBox(
                    height: 57,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (var i = 0; i < _sections.length; i++)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 7),
                            child: ChoiceChip(
                              label: Text(_sections[i]),
                              selected: _section == i,
                              onSelected: (_) => _openSection(i),
                              showCheckmark: false,
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(child: _buildSection()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSection(int index) async {
    if (index == 4) {
      final pin = await showDialog<String>(
        context: context,
        builder: (_) => const _ConnectionPinDialog(),
      );
      if (pin == null || !mounted) return;
      final valid = await widget.controller.authRepository.authenticate(
        pin,
        AuthRole.connection,
      );
      if (!mounted) return;
      if (!valid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('الرقم السري غير صحيح.')));
        return;
      }
    }
    setState(() => _section = index);
  }

  Widget _buildSection() {
    switch (_section) {
      case 1:
        return _ProductsAdmin(controller: widget.controller);
      case 2:
        return _CategoriesAdmin(controller: widget.controller);
      case 3:
        return _QrManagement(controller: widget.controller);
      case 4:
        return _ConnectionAdmin(controller: widget.controller);
      case 5:
        return _RestaurantSettings(controller: widget.controller);
      default:
        return _AdminOverview(
          controller: widget.controller,
          onOpen: _openSection,
        );
    }
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.sections,
    required this.selected,
    required this.onSelected,
  });

  final List<String> sections;
  final int selected;
  final ValueChanged<int> onSelected;

  static const icons = [
    Icons.dashboard_outlined,
    Icons.restaurant_menu,
    Icons.category_outlined,
    Icons.qr_code_2,
    Icons.settings_ethernet,
    Icons.tune,
  ];

  @override
  Widget build(BuildContext context) => Container(
    width: 238,
    decoration: const BoxDecoration(
      color: DariColors.paper,
      border: Border(left: BorderSide(color: DariColors.border)),
    ),
    child: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'الإدارة',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        for (var i = 0; i < sections.length; i++)
          ListTile(
            selected: selected == i,
            leading: Icon(icons[i]),
            title: Text(sections[i]),
            selectedTileColor: DariColors.accentSoft,
            onTap: () => onSelected(i),
          ),
      ],
    ),
  );
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({required this.controller, required this.onOpen});

  final AppController controller;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) {
    final incoming = controller.orders
        .where((order) => order.status == OrderStatus.pending)
        .length;
    final confirmed = controller.orders
        .where((order) => order.status == OrderStatus.confirmed)
        .length;
    final stats = [
      ('طلبات جديدة', '$incoming', Icons.mark_email_unread_outlined),
      ('طلبات مؤكدة', '$confirmed', Icons.fact_check_outlined),
      ('إجمالي الطلبات', '${controller.orders.length}', Icons.receipt_long),
      ('المنتجات', '${controller.products.length}', Icons.restaurant_menu),
      ('الفئات', '${controller.categories.length}', Icons.category_outlined),
      (
        'الطاولات',
        '${controller.restaurantSettings.tableCount}',
        Icons.table_restaurant_outlined,
      ),
      ('الاتصال', 'تجريبي', Icons.cloud_off_outlined),
    ];
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SectionHeading('لوحة الإدارة', subtitle: 'مطعم داري  •  IQD'),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 930
                ? 4
                : constraints.maxWidth > 560
                ? 3
                : 2;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stats.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisExtent: 112,
                crossAxisSpacing: 11,
                mainAxisSpacing: 11,
              ),
              itemBuilder: (context, index) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        stats[index].$3,
                        color: index == 6
                            ? DariColors.secondary
                            : DariColors.accent,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              stats[index].$1,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            stats[index].$2,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 25),
        const SectionHeading('إدارة المطعم'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (final entry in [
              (1, 'المنتجات', Icons.restaurant_menu),
              (2, 'الفئات', Icons.category_outlined),
              (3, 'إدارة QR', Icons.qr_code_2),
              (4, 'الاتصال', Icons.settings_ethernet),
              (5, 'إعدادات المطعم', Icons.tune),
            ])
              OutlinedButton.icon(
                onPressed: () => onOpen(entry.$1),
                icon: Icon(entry.$3),
                label: Text(entry.$2),
              ),
          ],
        ),
        const SizedBox(height: 25),
        const Text(
          'وضع التطوير: البيانات محفوظة على هذا الجهاز. لا يوجد خادم طلبات أو اتصال لحظي مهيأ.',
          style: TextStyle(color: DariColors.secondary, height: 1.6),
        ),
      ],
    );
  }
}

class _ProductsAdmin extends StatelessWidget {
  const _ProductsAdmin({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeading('المنتجات')),
            FilledButton.icon(
              onPressed: controller.categories.isEmpty
                  ? null
                  : () => _editProduct(context),
              icon: const Icon(Icons.add),
              label: const Text('منتج جديد'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (controller.products.isEmpty)
          const SizedBox(
            height: 260,
            child: EmptyState(title: 'لا توجد منتجات'),
          )
        else
          for (final product in controller.products)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  product.isAvailable
                      ? Icons.restaurant_menu
                      : Icons.visibility_off_outlined,
                  color: product.isVisible
                      ? DariColors.accent
                      : DariColors.secondary,
                ),
                title: Text(product.nameAr),
                subtitle: Text(
                  '${_categoryName(controller, product.categoryId)}  •  ${formatIqd(product.price)}${product.isAvailable ? '' : '  •  غير متوفر'}${product.isVisible ? '' : '  •  مخفي'}',
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'edit') {
                      await _editProduct(context, product: product);
                    } else if (action == 'visible') {
                      await controller.saveProduct(
                        product.copyWith(isVisible: !product.isVisible),
                      );
                    } else if (action == 'available') {
                      await controller.saveProduct(
                        product.copyWith(isAvailable: !product.isAvailable),
                      );
                    } else if (action == 'delete') {
                      await controller.deleteProduct(product);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(
                      value: 'visible',
                      child: Text(product.isVisible ? 'إخفاء' : 'إظهار'),
                    ),
                    PopupMenuItem(
                      value: 'available',
                      child: Text(
                        product.isAvailable ? 'تحديد غير متوفر' : 'تحديد متوفر',
                      ),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
              ),
            ),
      ],
    ),
  );

  String _categoryName(AppController controller, String id) =>
      controller.categories
          .where((category) => category.id == id)
          .map((category) => category.nameAr)
          .firstOrNull ??
      'بلا فئة';

  Future<void> _editProduct(BuildContext context, {Product? product}) async {
    final result = await showDialog<Product>(
      context: context,
      builder: (_) =>
          _ProductForm(categories: controller.categories, product: product),
    );
    if (result != null) await controller.saveProduct(result);
  }
}

class _ProductForm extends StatefulWidget {
  const _ProductForm({required this.categories, this.product});

  final List<Category> categories;
  final Product? product;

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.nameAr);
  late final _price = TextEditingController(
    text: widget.product == null ? '' : '${widget.product!.price}',
  );
  late final _description = TextEditingController(
    text: widget.product?.descriptionAr,
  );
  late final _image = TextEditingController(text: widget.product?.image);
  late final _variants = TextEditingController(
    text:
        widget.product?.variants
            .map((variant) => '${variant.nameAr}:${variant.price}')
            .join('\n') ??
        '',
  );
  late String _categoryId =
      widget.product?.categoryId ??
      (widget.categories.isEmpty ? '' : widget.categories.first.id);
  late bool _available = widget.product?.isAvailable ?? true;
  late bool _visible = widget.product?.isVisible ?? true;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _image.dispose();
    _variants.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product == null ? 'إضافة منتج' : 'تعديل المنتج'),
    content: SizedBox(
      width: 430,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'الاسم بالعربية'),
                validator: _required,
              ),
              const SizedBox(height: 9),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'الفئة'),
                items: [
                  for (final category in widget.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(category.nameAr),
                    ),
                ],
                onChanged: (value) => setState(() => _categoryId = value!),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'السعر الأساسي (د.ع)',
                ),
                validator: (value) => int.tryParse(value ?? '') == null
                    ? 'أدخل سعرًا صحيحًا'
                    : null,
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: _description,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: _image,
                decoration: const InputDecoration(
                  labelText: 'مسار صورة المنتج',
                ),
              ),
              const SizedBox(height: 9),
              TextFormField(
                controller: _variants,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'الخيارات، خيار لكل سطر: صغير:5000',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('متوفر للطلب'),
                value: _available,
                onChanged: (value) => setState(() => _available = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ظاهر في القائمة'),
                value: _visible,
                onChanged: (value) => setState(() => _visible = value),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _save, child: const Text('حفظ')),
    ],
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final variants = <ProductVariant>[];
    for (final line in _variants.text.split('\n')) {
      if (line.trim().isEmpty) continue;
      final separator = line.lastIndexOf(':');
      if (separator < 1) continue;
      final price = int.tryParse(line.substring(separator + 1).trim());
      if (price != null) {
        variants.add(
          ProductVariant(
            nameAr: line.substring(0, separator).trim(),
            price: price,
          ),
        );
      }
    }
    final previous = widget.product;
    Navigator.pop(
      context,
      Product(
        id: previous?.id ?? 'product-${DateTime.now().microsecondsSinceEpoch}',
        categoryId: _categoryId,
        nameAr: _name.text.trim(),
        price: int.parse(_price.text),
        descriptionAr: _description.text.trim(),
        image: _image.text.trim().isEmpty ? null : _image.text.trim(),
        isAvailable: _available,
        isVisible: _visible,
        variants: variants,
        sortOrder: previous?.sortOrder ?? 0,
      ),
    );
  }
}

class _CategoriesAdmin extends StatelessWidget {
  const _CategoriesAdmin({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            const Expanded(child: SectionHeading('الفئات')),
            FilledButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add),
              label: const Text('فئة جديدة'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final category in controller.categories)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.category_outlined),
              title: Text(category.nameAr),
              subtitle: Text(
                '${controller.products.where((product) => product.categoryId == category.id).length} منتج${category.isVisible ? '' : '  •  مخفية'}',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: category.isVisible ? 'إخفاء' : 'إظهار',
                    onPressed: () => controller.saveCategory(
                      Category(
                        id: category.id,
                        nameAr: category.nameAr,
                        nameEn: category.nameEn,
                        sortOrder: category.sortOrder,
                        isVisible: !category.isVisible,
                      ),
                    ),
                    icon: Icon(
                      category.isVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  IconButton(
                    tooltip: 'تعديل',
                    onPressed: () => _edit(context, category: category),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'حذف',
                    onPressed:
                        controller.products.any(
                          (product) => product.categoryId == category.id,
                        )
                        ? null
                        : () => controller.deleteCategory(category),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Future<void> _edit(BuildContext context, {Category? category}) async {
    final result = await showDialog<Category>(
      context: context,
      builder: (_) => _CategoryForm(category: category),
    );
    if (result != null) await controller.saveCategory(result);
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.category});

  final Category? category;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  late final _name = TextEditingController(text: widget.category?.nameAr);
  late final _order = TextEditingController(
    text: '${widget.category?.sortOrder ?? 0}',
  );

  @override
  void dispose() {
    _name.dispose();
    _order.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.category == null ? 'فئة جديدة' : 'تعديل الفئة'),
    content: SizedBox(
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'اسم الفئة'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _order,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ترتيب العرض'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                Category(
                  id:
                      widget.category?.id ??
                      'category-${DateTime.now().microsecondsSinceEpoch}',
                  nameAr: _name.text.trim(),
                  sortOrder: int.tryParse(_order.text) ?? 0,
                  isVisible: widget.category?.isVisible ?? true,
                ),
              ),
        child: const Text('حفظ'),
      ),
    ],
  );
}

class _QrManagement extends StatefulWidget {
  const _QrManagement({required this.controller});

  final AppController controller;

  @override
  State<_QrManagement> createState() => _QrManagementState();
}

class _QrManagementState extends State<_QrManagement> {
  final _tableController = TextEditingController(text: '1');
  late int _tableCount;

  @override
  void initState() {
    super.initState();
    _tableCount = widget.controller.restaurantSettings.tableCount;
  }

  @override
  void dispose() {
    _tableController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configuredUrl = widget.controller.restaurantSettings.publicMenuUrl;
    final publicUrl = configuredUrl.isEmpty
        ? widget.controller.qrRepository.buildPublicUrl()
        : configuredUrl;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionHeading(
          'إدارة QR',
          subtitle: 'روابط مباشرة للقائمة الرقمية',
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'القائمة العامة',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Center(child: _QrCode(data: publicUrl)),
                const SizedBox(height: 10),
                SelectableText(
                  publicUrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: DariColors.secondary),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _copyLink(context, publicUrl),
                      icon: const Icon(Icons.copy),
                      label: const Text('نسخ الرابط'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: 'قائمة مطعم داري: $publicUrl'),
                      ),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('مشاركة'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showPrintPreview(
                        context,
                        'القائمة العامة',
                        publicUrl,
                      ),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('معاينة الطباعة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'رموز الطاولات',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'تقليل عدد الطاولات',
                      onPressed: _tableCount > 1
                          ? () => _changeTableCount(_tableCount - 1)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$_tableCount'),
                    IconButton(
                      tooltip: 'زيادة عدد الطاولات',
                      onPressed: () => _changeTableCount(_tableCount + 1),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tableController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'رقم الطاولة',
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    FilledButton.icon(
                      onPressed: _openTable,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('إنشاء QR'),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (var table = 1; table <= _tableCount; table++)
                      ActionChip(
                        label: Text('طاولة $table'),
                        onPressed: () {
                          _tableController.text = '$table';
                          _openTable();
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text(
            'روابط QR تُنشأ من عنوان التطبيق الحالي. للنشر الفعلي عيّن DARI_PUBLIC_BASE_URL إلى نطاق المطعم.',
            style: TextStyle(color: DariColors.secondary, height: 1.5),
          ),
        ),
      ],
    );
  }

  Future<void> _changeTableCount(int count) async {
    setState(() => _tableCount = count);
    await widget.controller.saveRestaurantSettings(
      widget.controller.restaurantSettings.copyWith(tableCount: count),
    );
  }

  Future<void> _openTable() async {
    final number = int.tryParse(_tableController.text);
    if (number == null || number < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل رقم طاولة صحيحًا.')));
      return;
    }
    final link = widget.controller.qrRepository.buildTableUrl(number);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('طاولة $number'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _QrCode(data: link, size: 205),
            const SizedBox(height: 12),
            SelectableText(link, textAlign: TextAlign.center),
            const SizedBox(height: 7),
            const Text(
              'امسح الرمز لفتح قائمة الطاولة',
              style: TextStyle(color: DariColors.secondary),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _copyLink(context, link),
            icon: const Icon(Icons.copy),
            label: const Text('نسخ الرابط'),
          ),
          TextButton.icon(
            onPressed: () => _showPrintPreview(context, 'طاولة $number', link),
            icon: const Icon(Icons.print_outlined),
            label: const Text('معاينة الطباعة'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }
}

class _QrCode extends StatelessWidget {
  const _QrCode({required this.data, this.size = 170});

  final String data;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    color: Colors.white,
    child: QrImageView(
      data: data,
      size: size,
      backgroundColor: Colors.white,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
    ),
  );
}

Future<void> _showPrintPreview(
  BuildContext context,
  String title,
  String url,
) async {
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 340,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DariWordmark(),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 17),
              _QrCode(data: url, size: 205),
              const SizedBox(height: 13),
              const Text('امسح لفتح القائمة'),
              const SizedBox(height: 8),
              const Text(
                'معاينة جاهزة للطباعة. يلزم ربط خدمة طباعة لإرسالها إلى طابعة فعلية.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DariColors.secondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('إغلاق المعاينة'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _copyLink(BuildContext context, String link) {
  Clipboard.setData(ClipboardData(text: link));
  ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('تم نسخ الرابط.')));
}

class _ConnectionAdmin extends StatefulWidget {
  const _ConnectionAdmin({required this.controller});

  final AppController controller;

  @override
  State<_ConnectionAdmin> createState() => _ConnectionAdminState();
}

class _ConnectionAdminState extends State<_ConnectionAdmin> {
  late final _apiBase = TextEditingController(
    text: widget.controller.connectionSettings.apiBaseUrl,
  );
  late final _server = TextEditingController(
    text: widget.controller.connectionSettings.serverUrl,
  );
  late final _apiPort = TextEditingController(
    text: widget.controller.connectionSettings.port,
  );
  late final _apiKey = TextEditingController(
    text: widget.controller.connectionSettings.apiKey,
  );
  late final _bridge = TextEditingController(
    text: widget.controller.connectionSettings.bridgeUrl,
  );
  late final _bridgePort = TextEditingController(
    text: widget.controller.connectionSettings.bridgePort,
  );
  late final _device = TextEditingController(
    text: widget.controller.connectionSettings.deviceName,
  );
  bool _isBridge = false;
  bool _testing = false;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  @override
  void dispose() {
    _apiBase.dispose();
    _server.dispose();
    _apiPort.dispose();
    _apiKey.dispose();
    _bridge.dispose();
    _bridgePort.dispose();
    _device.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const SectionHeading(
        'إعدادات الاتصال',
        subtitle: 'بيانات محلية، لا توجد خدمة خادم متصلة',
      ),
      const SizedBox(height: 17),
      SegmentedButton<bool>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: false, label: Text('API')),
          ButtonSegment(value: true, label: Text('Bridge')),
        ],
        selected: {_isBridge},
        onSelectionChanged: (value) => setState(() => _isBridge = value.first),
      ),
      const SizedBox(height: 16),
      _statusRow(),
      const SizedBox(height: 14),
      if (_isBridge) ...[
        TextField(
          controller: _bridge,
          decoration: const InputDecoration(labelText: 'Bridge URL'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _bridgePort,
          decoration: const InputDecoration(labelText: 'Port'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _device,
          decoration: const InputDecoration(labelText: 'اسم الجهاز'),
        ),
      ] else ...[
        TextField(
          controller: _apiBase,
          decoration: const InputDecoration(labelText: 'API Base URL'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _server,
          decoration: const InputDecoration(labelText: 'Server URL'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _apiPort,
          decoration: const InputDecoration(labelText: 'Port'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _apiKey,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'API Key'),
        ),
      ],
      const SizedBox(height: 15),
      const Text(
        'وضع التطوير: اختبار الاتصال لا يرسل طلبًا حقيقيًا، والنتيجة تبقى غير متصل حتى إعداد خدمة فعلية.',
        style: TextStyle(color: DariColors.secondary, height: 1.5),
      ),
      const SizedBox(height: 15),
      Wrap(
        spacing: 9,
        children: [
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: const Text('اختبار الاتصال'),
          ),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ'),
          ),
        ],
      ),
    ],
  );

  Widget _statusRow() {
    final connected = _status == ConnectionStatus.connected;
    final text = switch (_status) {
      ConnectionStatus.connected => 'متصل',
      ConnectionStatus.disconnected => 'غير متصل',
      ConnectionStatus.connecting => 'جارٍ الاتصال',
      ConnectionStatus.error => 'خطأ في الاتصال',
    };
    return Row(
      children: [
        Icon(
          Icons.circle,
          size: 11,
          color: connected ? DariColors.success : DariColors.secondary,
        ),
        const SizedBox(width: 8),
        Text(
          'حالة الاتصال: $text',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _status = ConnectionStatus.connecting;
    });
    final status = await widget.controller.connectionRepository.testConnection(
      _settings(),
    );
    if (!mounted) return;
    setState(() {
      _status = status;
      _testing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('لا يوجد خادم مهيأ للاختبار في وضع التطوير.'),
      ),
    );
  }

  ConnectionSettings _settings() => ConnectionSettings(
    apiBaseUrl: _apiBase.text.trim(),
    serverUrl: _server.text.trim(),
    port: _apiPort.text.trim(),
    apiKey: _apiKey.text,
    bridgeUrl: _bridge.text.trim(),
    bridgePort: _bridgePort.text.trim(),
    deviceName: _device.text.trim(),
  );

  Future<void> _save() async {
    await widget.controller.saveConnectionSettings(_settings());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ إعدادات الاتصال على هذا الجهاز.')),
    );
  }
}

class _ConnectionPinDialog extends StatefulWidget {
  const _ConnectionPinDialog();

  @override
  State<_ConnectionPinDialog> createState() => _ConnectionPinDialogState();
}

class _ConnectionPinDialogState extends State<_ConnectionPinDialog> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('حماية إعدادات الاتصال'),
    content: TextField(
      controller: _pin,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 4,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'الرقم السري'),
      onChanged: (_) => setState(() {}),
      onSubmitted: (value) =>
          value.length == 4 ? Navigator.pop(context, value) : null,
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: _pin.text.length == 4
            ? () => Navigator.pop(context, _pin.text)
            : null,
        child: const Text('متابعة'),
      ),
    ],
  );
}

class _RestaurantSettings extends StatefulWidget {
  const _RestaurantSettings({required this.controller});

  final AppController controller;

  @override
  State<_RestaurantSettings> createState() => _RestaurantSettingsState();
}

class _RestaurantSettingsState extends State<_RestaurantSettings> {
  late final _name = TextEditingController(
    text: widget.controller.restaurantSettings.restaurantName,
  );
  late final _phone = TextEditingController(
    text: widget.controller.restaurantSettings.phone,
  );
  late final _social = TextEditingController(
    text: widget.controller.restaurantSettings.socialLink,
  );
  late final _address = TextEditingController(
    text: widget.controller.restaurantSettings.address,
  );
  late final _logo = TextEditingController(
    text: widget.controller.restaurantSettings.logoPath,
  );
  late final _publicUrl = TextEditingController(
    text: widget.controller.restaurantSettings.publicMenuUrl,
  );
  late final _tableCount = TextEditingController(
    text: '${widget.controller.restaurantSettings.tableCount}',
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _social.dispose();
    _address.dispose();
    _logo.dispose();
    _publicUrl.dispose();
    _tableCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const SectionHeading('إعدادات المطعم'),
      const SizedBox(height: 14),
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'اسم المطعم'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _phone,
        decoration: const InputDecoration(labelText: 'رقم الهاتف'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _social,
        decoration: const InputDecoration(labelText: 'حساب التواصل'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _address,
        decoration: const InputDecoration(labelText: 'العنوان'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _logo,
        decoration: const InputDecoration(labelText: 'مسار الشعار'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _publicUrl,
        keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'رابط القائمة العامة'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _tableCount,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'عدد الطاولات'),
      ),
      const SizedBox(height: 10),
      const ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('العملة'),
        trailing: Text('IQD  •  دينار عراقي'),
      ),
      const Text(
        'تُحفظ هذه الإعدادات محليًا على هذا الجهاز.',
        style: TextStyle(color: DariColors.secondary, height: 1.5),
      ),
      const SizedBox(height: 13),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('حفظ'),
        ),
      ),
    ],
  );

  Future<void> _save() async {
    final count = int.tryParse(_tableCount.text);
    if (count == null || count < 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل عدد طاولات صحيحًا.')));
      return;
    }
    await widget.controller.saveRestaurantSettings(
      widget.controller.restaurantSettings.copyWith(
        restaurantName: _name.text.trim(),
        phone: _phone.text.trim(),
        socialLink: _social.text.trim(),
        address: _address.text.trim(),
        logoPath: _logo.text.trim(),
        publicMenuUrl: _publicUrl.text.trim(),
        tableCount: count,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ إعدادات المطعم على هذا الجهاز.')),
    );
  }
}
