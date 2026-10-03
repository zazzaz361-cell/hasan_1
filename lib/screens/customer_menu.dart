import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../data/repositories.dart';
import '../models/restaurant.dart';
import '../ui/brand.dart';
import 'admin_screen.dart';
import 'staff_sign_in.dart';

// Add product IDs here only when matching photos exist in assets/products/.
const _customerProductImageAssets = <String, String>{};

class CustomerMenuScreen extends StatefulWidget {
  const CustomerMenuScreen({
    super.key,
    required this.controller,
    this.tableNumber,
    this.invalidTable = false,
  });

  final AppController controller;
  final int? tableNumber;
  final bool invalidTable;

  @override
  State<CustomerMenuScreen> createState() => _CustomerMenuScreenState();
}

class _CustomerMenuScreenState extends State<CustomerMenuScreen> {
  final _searchController = TextEditingController();
  String _categoryId = 'all';
  String _search = '';
  OrderType? _publicOrderType;

  bool get _isTableOrder => widget.tableNumber != null;
  OrderType? get _orderType =>
      _isTableOrder ? OrderType.dineIn : _publicOrderType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final categories =
            controller.categories
                .where((category) => category.isVisible)
                .toList()
              ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final visibleProducts = controller.products.where((product) {
          final matchesCategory =
              _categoryId == 'all' || product.categoryId == _categoryId;
          final matchesSearch = product.nameAr.toLowerCase().contains(
            _search.toLowerCase(),
          );
          return matchesCategory &&
              matchesSearch &&
              product.isVisible &&
              categories.any((category) => category.id == product.categoryId);
        }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const DariWordmark(compact: true),
            actions: [
              IconButton(
                tooltip: 'إدارة',
                onPressed: () => _requestAdminAccess(context),
                icon: const Icon(Icons.admin_panel_settings_outlined),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: _CartButton(
                  count: controller.cartCount,
                  onPressed: () => _openCart(context),
                ),
              ),
            ],
          ),
          body: widget.invalidTable
              ? const EmptyState(
                  title: 'رابط الطاولة غير صالح',
                  message: 'امسح رمز QR مرة أخرى أو اطلب المساعدة من الموظف.',
                  icon: Icons.qr_code_2,
                )
              : controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildIntro(context)),
                    if (!_isTableOrder)
                      SliverToBoxAdapter(child: _buildOrderTypePicker()),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 9),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _search = value),
                          decoration: InputDecoration(
                            hintText: 'ابحث في القائمة',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'مسح البحث',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _search = '');
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildCategories(categories)),
                    if (visibleProducts.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyState(
                          title: 'لا توجد أصناف هنا',
                          message: 'جرّب فئة أخرى أو غيّر عبارة البحث.',
                          icon: Icons.search_off,
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final width = constraints.crossAxisExtent;
                            final columns = width >= 1100
                                ? 5
                                : width >= 760
                                ? 4
                                : width >= 500
                                ? 3
                                : 2;
                            return SliverGrid.builder(
                              itemCount: visibleProducts.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 11,
                                    mainAxisSpacing: 11,
                                    childAspectRatio: width < 500 ? .79 : .87,
                                  ),
                              itemBuilder: (context, index) {
                                final product = visibleProducts[index];
                                final category = categories.firstWhere(
                                  (item) => item.id == product.categoryId,
                                );
                                return ProductCard(
                                  product: product,
                                  categoryName: category.nameAr,
                                  imageAssetPath:
                                      _customerProductImageAssets[product.id],
                                  allowNetworkImage: true,
                                  onTap: () => _showProductDetails(product),
                                  onAdd: () => product.variants.isEmpty
                                      ? controller.addToCart(product)
                                      : _showProductDetails(product),
                                );
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
          bottomNavigationBar: controller.cartCount == 0
              ? null
              : SafeArea(
                  minimum: const EdgeInsets.fromLTRB(14, 7, 14, 9),
                  child: FilledButton.icon(
                    onPressed: () => _openCart(context),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Row(
                      children: [
                        Expanded(
                          child: Text('السلة  •  ${controller.cartCount}'),
                        ),
                        Text(formatIqd(controller.cartTotal)),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildIntro(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DariColors.ink,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isTableOrder ? 'طاولة ${widget.tableNumber}' : 'مطعم داري',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'طعم مختلف .. تجربة تستحق',
            style: TextStyle(color: Color(0xFFD8D4CD), fontSize: 13),
          ),
        ],
      ),
    ),
  );

  Widget _buildOrderTypePicker() => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'اختر نوع الطلب',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SegmentedButton<OrderType>(
          showSelectedIcon: false,
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(
              value: OrderType.takeaway,
              label: Text('سفري'),
              icon: Icon(Icons.shopping_bag_outlined),
            ),
            ButtonSegment(
              value: OrderType.delivery,
              label: Text('ديليفري'),
              icon: Icon(Icons.delivery_dining),
            ),
          ],
          selected: _publicOrderType == null ? {} : {_publicOrderType!},
          onSelectionChanged: (selection) =>
              setState(() => _publicOrderType = selection.first),
        ),
      ],
    ),
  );

  Widget _buildCategories(List<Category> categories) => SizedBox(
    height: 48,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      scrollDirection: Axis.horizontal,
      children: [
        _CategoryChip(
          label: 'الكل',
          selected: _categoryId == 'all',
          onTap: () => setState(() => _categoryId = 'all'),
        ),
        for (final category in categories)
          _CategoryChip(
            label: category.nameAr,
            selected: _categoryId == category.id,
            onTap: () => setState(() => _categoryId = category.id),
          ),
      ],
    ),
  );

  Future<void> _showProductDetails(Product product) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DariColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => ProductDetailsSheet(
        product: product,
        onAdd: (quantity, variant) {
          for (var i = 0; i < quantity; i++) {
            widget.controller.addToCart(product, variant: variant);
          }
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _openCart(BuildContext context) async {
    if (!_isTableOrder && _publicOrderType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر سفري أو ديليفري أولاً.')),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: DariColors.canvas,
      builder: (sheetContext) => CartCheckoutSheet(
        controller: widget.controller,
        orderType: _orderType!,
        tableNumber: widget.tableNumber,
        onSubmit: (name, phone, address) async {
          try {
            final order = await widget.controller.submitCart(
              type: _orderType!,
              source: _isTableOrder
                  ? OrderSource.tableQr
                  : OrderSource.publicLink,
              tableNumber: widget.tableNumber,
              customerName: name,
              customerPhone: phone,
              customerAddress: address,
            );
            if (!mounted || !sheetContext.mounted) return;
            Navigator.pop(sheetContext);
            await showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: DariColors.success,
                  size: 38,
                ),
                title: const Text('تم استلام طلبك'),
                content: Text(
                  '${_isTableOrder ? 'تم تسجيل طلب طاولة ${widget.tableNumber}' : 'تم تسجيل طلب ${_orderType == OrderType.takeaway ? 'السفري' : 'التوصيل'}'}\n'
                  '#${order.orderNumber}\n\n'
                  '${widget.controller.isCloudBacked ? 'تم إرسال الطلب إلى المطعم وسيتم تحضيره قريبًا.' : 'حُفظ الطلب محليًا على هذا الجهاز. يلزم إعداد خادم لإرساله من هاتف الزبون إلى الكاشير.'}',
                  textAlign: TextAlign.center,
                ),
                actions: [
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('متابعة القائمة'),
                  ),
                ],
              ),
            );
          } catch (error) {
            if (!mounted || !sheetContext.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error is OrderSubmitException
                      ? describeSubmitError(error)
                      : 'تعذر إرسال الطلب. يرجى المحاولة مرة أخرى.',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _requestAdminAccess(BuildContext context) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => const _PinDialog(title: 'دخول الإدارة'),
    );
    if (pin == null || !context.mounted) return;
    final isAuthorized = await widget.controller.authRepository.authenticate(
      pin,
      AuthRole.cashierAdmin,
    );
    if (!context.mounted) return;
    if (!isAuthorized) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('الرقم السري غير صحيح.')));
      return;
    }
    if (!await ensureStaffSignedIn(context, widget.controller)) return;
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AdminScreen(controller: widget.controller),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 7, top: 6, bottom: 5),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: DariColors.ink,
      backgroundColor: DariColors.paper,
      side: BorderSide(color: selected ? DariColors.ink : DariColors.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : DariColors.ink,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
    ),
  );
}

class _CartButton extends StatelessWidget {
  const _CartButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      IconButton(
        tooltip: 'السلة',
        onPressed: onPressed,
        icon: const Icon(Icons.shopping_bag_outlined),
      ),
      if (count > 0)
        PositionedDirectional(
          top: 2,
          end: 0,
          child: CircleAvatar(
            radius: 9,
            backgroundColor: DariColors.accent,
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ),
    ],
  );
}

class ProductDetailsSheet extends StatefulWidget {
  const ProductDetailsSheet({
    super.key,
    required this.product,
    required this.onAdd,
  });

  final Product product;
  final void Function(int quantity, ProductVariant? variant) onAdd;

  @override
  State<ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends State<ProductDetailsSheet> {
  int _quantity = 1;
  int _variantIndex = 0;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final variant = product.variants.isEmpty
        ? null
        : product.variants[_variantIndex.clamp(0, product.variants.length - 1)];
    final price = variant?.price ?? product.price;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: DariColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 17),
          Container(
            height: 170,
            decoration: BoxDecoration(
              color: DariColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: product.image == null || product.image!.isEmpty
                ? const Icon(
                    Icons.restaurant_menu,
                    size: 54,
                    color: DariColors.secondary,
                  )
                : _customerProductImage(product.image!),
          ),
          const SizedBox(height: 16),
          Text(product.nameAr, style: Theme.of(context).textTheme.titleLarge),
          if (product.descriptionAr.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              product.descriptionAr,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (product.variants.isNotEmpty) ...[
            const SizedBox(height: 15),
            const Text('الحجم', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 8,
              children: [
                for (var index = 0; index < product.variants.length; index++)
                  ChoiceChip(
                    label: Text(
                      '${product.variants[index].nameAr}  •  ${formatIqd(product.variants[index].price)}',
                    ),
                    selected: index == _variantIndex,
                    onSelected: (_) => setState(() => _variantIndex = index),
                    showCheckmark: false,
                    selectedColor: DariColors.accentSoft,
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _QuantityButton(
                icon: Icons.remove,
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 17),
                child: Text(
                  '$_quantity',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _QuantityButton(
                icon: Icons.add,
                onPressed: () => setState(() => _quantity++),
              ),
              const Spacer(),
              Text(
                formatIqd(price * _quantity),
                style: const TextStyle(
                  color: DariColors.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          FilledButton(
            onPressed: () => widget.onAdd(_quantity, variant),
            child: const Text('أضف إلى السلة'),
          ),
        ],
      ),
    );
  }

  Widget _customerProductImage(String path) {
    final uri = Uri.tryParse(path);
    final isNetworkImage =
        uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
    return isNetworkImage
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.image_not_supported_outlined,
              color: DariColors.secondary,
            ),
          )
        : Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.image_not_supported_outlined,
              color: DariColors.secondary,
            ),
          );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 36,
    height: 36,
    child: IconButton.outlined(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      padding: EdgeInsets.zero,
    ),
  );
}

class CartCheckoutSheet extends StatefulWidget {
  const CartCheckoutSheet({
    super.key,
    required this.controller,
    required this.orderType,
    required this.onSubmit,
    this.tableNumber,
  });

  final AppController controller;
  final OrderType orderType;
  final int? tableNumber;
  final Future<void> Function(String? name, String? phone, String? address)
  onSubmit;

  @override
  State<CartCheckoutSheet> createState() => _CartCheckoutSheetState();
}

class _CartCheckoutSheetState extends State<CartCheckoutSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _submitting = false;

  bool get _needsCustomer => widget.orderType != OrderType.dineIn;
  bool get _needsAddress => widget.orderType == OrderType.delivery;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: EdgeInsets.fromLTRB(
          17,
          20,
          17,
          MediaQuery.viewInsetsOf(context).bottom + 15,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'السلة  •  ${controller.cartCount} صنف',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: controller.clearCart,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('إفراغ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 230),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: controller.cart.length,
                    separatorBuilder: (_, _) => const Divider(height: 15),
                    itemBuilder: (context, index) {
                      final line = controller.cart[index];
                      return Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.product.nameAr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (line.variant != null)
                                  Text(
                                    line.variant!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                Text(
                                  formatIqd(line.subtotal),
                                  style: const TextStyle(
                                    color: DariColors.accent,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _QuantityButton(
                            icon: Icons.remove,
                            onPressed: () =>
                                controller.changeCartQuantity(line, -1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('${line.quantity}'),
                          ),
                          _QuantityButton(
                            icon: Icons.add,
                            onPressed: () =>
                                controller.changeCartQuantity(line, 1),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_needsCustomer) ...[
                  const SizedBox(height: 13),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'اسم الزبون'),
                    validator: _required,
                  ),
                  const SizedBox(height: 9),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                    validator: _required,
                  ),
                  if (_needsAddress) ...[
                    const SizedBox(height: 9),
                    TextFormField(
                      controller: _addressController,
                      minLines: 1,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'عنوان التوصيل',
                      ),
                      validator: _required,
                    ),
                  ],
                ],
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'الإجمالي',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      formatIqd(controller.cartTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: DariColors.accent,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                FilledButton(
                  onPressed: _submitting || controller.cart.isEmpty
                      ? null
                      : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 19,
                          width: 19,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          widget.orderType == OrderType.dineIn
                              ? 'إرسال الطلب إلى الكاشير'
                              : 'تأكيد الطلب',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  Future<void> _submit() async {
    if (_needsCustomer && !_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      _needsCustomer ? _nameController.text.trim() : null,
      _needsCustomer ? _phoneController.text.trim() : null,
      _needsAddress ? _addressController.text.trim() : null,
    );
    if (mounted) setState(() => _submitting = false);
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.title});

  final String title;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _pin = '';

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final label = key.keyLabel;
    if (label.length == 1 && '0123456789'.contains(label)) {
      if (_pin.length < 4) setState(() => _pin += label);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_pin.length == 4) Navigator.pop(context, _pin);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('أدخل الرقم السري'),
          const SizedBox(height: 14),
          Text(
            '● ' * _pin.length + '○ ' * (4 - _pin.length),
            style: const TextStyle(fontSize: 18, letterSpacing: 4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 230,
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                for (var digit = 1; digit <= 9; digit++) _key('$digit'),
                _key('مسح'),
                _key('0'),
                _key('⌫'),
              ],
            ),
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
        onPressed: _pin.length == 4 ? () => Navigator.pop(context, _pin) : null,
        child: const Text('دخول'),
      ),
    ],
  );

  Widget _key(String value) => SizedBox(
    width: 72,
    child: TextButton(
      onPressed: () => setState(() {
        if (value == 'مسح') {
          _pin = '';
        } else if (value == '⌫') {
          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        } else if (_pin.length < 4) {
          _pin += value;
        }
      }),
      child: Text(value),
    ),
  );
}
