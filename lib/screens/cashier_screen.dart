import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_controller.dart';
import '../data/repositories.dart';
import '../models/restaurant.dart';
import '../ui/brand.dart';
import 'admin_screen.dart';
import 'customer_menu.dart';
import 'staff_sign_in.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  int _section = 0;
  bool _reauthenticating = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  // Shows the staff login again once Supabase reports the session has ended.
  Future<void> _onControllerChanged() async {
    if (!widget.controller.staffSessionExpired || _reauthenticating) return;
    _reauthenticating = true;
    final signedIn = await ensureStaffSignedIn(context, widget.controller);
    _reauthenticating = false;
    if (!mounted || signedIn) return;
    await Navigator.of(context)
        .pushNamedAndRemoveUntil('/cashier', (route) => false);
  }

  static const _labels = ['الطلبات', 'طلب يدوي', 'منيو الزبون', 'الإدارة'];
  static const _icons = [
    Icons.receipt_long_outlined,
    Icons.add_shopping_cart,
    Icons.menu_book_outlined,
    Icons.admin_panel_settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 850;
    return Scaffold(
      appBar: AppBar(
        title: const DariWordmark(compact: true),
        actions: [
          Text('الكاشير', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 15),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            Container(
              width: 226,
              decoration: const BoxDecoration(
                color: DariColors.paper,
                border: Border(left: BorderSide(color: DariColors.border)),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'نظام الكاشير',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  for (var index = 0; index < _labels.length; index++)
                    _navTile(index),
                ],
              ),
            ),
          Expanded(
            child: _section == 1
                ? _ManualOrderScreen(controller: widget.controller)
                : _section == 0
                ? _OrdersScreen(controller: widget.controller)
                : const EmptyState(
                    title: 'جارٍ فتح القائمة',
                    icon: Icons.restaurant_menu,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: isWide
          ? null
          : NavigationBar(
              selectedIndex: _section,
              onDestinationSelected: _selectSection,
              destinations: [
                for (var index = 0; index < _labels.length; index++)
                  NavigationDestination(
                    icon: Icon(_icons[index]),
                    label: _labels[index],
                  ),
              ],
            ),
    );
  }

  Widget _navTile(int index) => ListTile(
    selected: _section == index,
    leading: Icon(_icons[index]),
    title: Text(_labels[index]),
    selectedTileColor: DariColors.accentSoft,
    onTap: () => _selectSection(index),
  );

  Future<void> _selectSection(int index) async {
    if (index == 2) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => CustomerMenuScreen(controller: widget.controller),
        ),
      );
      return;
    }
    if (index == 3) {
      final pin = await showDialog<String>(
        context: context,
        builder: (_) => const _CashierPinDialog(),
      );
      if (pin == null || !mounted) return;
      final authorized = await widget.controller.authRepository.authenticate(
        pin,
        AuthRole.cashierAdmin,
      );
      if (!mounted) return;
      if (!authorized) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('الرقم السري غير صحيح.')));
        return;
      }
      if (!await ensureStaffSignedIn(context, widget.controller)) return;
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => AdminScreen(controller: widget.controller),
        ),
      );
      return;
    }
    setState(() => _section = index);
  }
}

class _OrdersScreen extends StatefulWidget {
  const _OrdersScreen({required this.controller});

  final AppController controller;

  @override
  State<_OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<_OrdersScreen> {
  int _filter = 0;
  bool _deletingAll = false;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final orders = widget.controller.orders.where((order) {
        if (_filter == 1) return order.status == OrderStatus.pending;
        if (_filter == 2) return order.status == OrderStatus.confirmed;
        return true;
      }).toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 18, 19, 9),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SectionHeading(
                        'الطلبات الواردة',
                        subtitle: widget.controller.isCloudBacked
                            ? (widget.controller.ordersError != null &&
                                      showBackendDiagnostics
                                  ? 'فشل جلب الطلبات: ${widget.controller.ordersError}'
                                  : showBackendDiagnostics
                                  ? 'تتحدّث مباشرة من السحابة • realtime: ${widget.controller.realtimeStatus}'
                                  : 'تتحدّث مباشرة من السحابة')
                            : 'تُحدّث محليًا عند إنشاء طلب',
                      ),
                    ),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 1, label: Text('الواردة')),
                        ButtonSegment(value: 2, label: Text('المؤكدة')),
                        ButtonSegment(value: 0, label: Text('الكل')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (value) =>
                          setState(() => _filter = value.first),
                    ),
                  ],
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed:
                        _deletingAll ||
                            !widget.controller.orders.any(
                              (order) => order.isProcessed,
                            )
                        ? null
                        : _confirmDeleteAll,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text('حذف الجميع'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: orders.isEmpty
                ? EmptyState(
                    title: _filter == 1
                        ? 'لا توجد طلبات واردة'
                        : _filter == 2
                        ? 'لا توجد طلبات مؤكدة'
                        : 'لا توجد طلبات بعد',
                    message: 'ستظهر الطلبات الجديدة هنا.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    itemCount: orders.length,
                    itemBuilder: (context, index) => _OrderCard(
                      order: orders[index],
                      onDelete: orders[index].isProcessed
                          ? () => _confirmDeleteOrder(orders[index])
                          : null,
                      onStatusChanged: (status) async {
                        try {
                          await widget.controller.updateOrderStatus(
                            orders[index],
                            status,
                          );
                        } catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error is OrderStatusException
                                    ? (showBackendDiagnostics
                                          ? '${error.message}\n[${error.detail}]'
                                          : error.message)
                                    : 'تعذر تحديث حالة الطلب. تحقق من الاتصال وحاول مرة أخرى.',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
          ),
        ],
      );
    },
  );

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: const Text('هل أنت متأكد من حذف جميع الطلبات المعالجة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف الجميع'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deletingAll = true);
    try {
      final deletedCount = await widget.controller.deleteProcessedOrders();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deletedCount == 0
                ? 'لا توجد طلبات معالجة لحذفها.'
                : 'تم حذف $deletedCount من الطلبات المعالجة.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_deleteErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _deletingAll = false);
    }
  }

  Future<void> _confirmDeleteOrder(OrderRecord order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text('هل أنت متأكد من حذف الطلب #${order.orderNumber}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.deleteOrder(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف الطلب.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_deleteErrorMessage(error))));
    }
  }

  String _deleteErrorMessage(Object error) => error is OrderDeletionException
      ? showBackendDiagnostics && error.detail.isNotEmpty
            ? '${error.message}\n[${error.detail}]'
            : error.message
      : 'تعذر حذف الطلب. تحقق من الاتصال وحاول مرة أخرى.';
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onStatusChanged,
    this.onDelete,
  });

  final OrderRecord order;
  final ValueChanged<OrderStatus> onStatusChanged;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 11),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 7,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '#${order.orderNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              _OrderBadge(_typeLabel(order)),
              _OrderBadge(_sourceLabel(order.source), muted: true),
              _OrderBadge(
                _statusLabel(order.status),
                muted: order.status != OrderStatus.pending,
              ),
              Text(
                _timeLabel(order.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 18,
            runSpacing: 5,
            children: [
              if (order.tableNumber != null)
                _info('الطاولة', '${order.tableNumber}'),
              if (order.customerName != null)
                _info('الزبون', order.customerName!),
              if (order.customerPhone != null)
                _info('الهاتف', order.customerPhone!),
              if (order.customerAddress != null)
                _info('العنوان', order.customerAddress!),
            ],
          ),
          const Divider(height: 21),
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.quantity} × ${item.productName}${item.selectedVariant == null ? '' : ' (${item.selectedVariant})'}',
                    ),
                  ),
                  Text(formatIqd(item.subtotal)),
                ],
              ),
            ),
          const Divider(height: 21),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'الإجمالي',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatIqd(order.total),
                style: const TextStyle(
                  color: DariColors.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                tooltip: 'تغيير حالة الطلب',
                onSelected: (action) {
                  if (action == 'delete') {
                    onDelete?.call();
                    return;
                  }
                  onStatusChanged(OrderStatus.values.byName(action));
                },
                itemBuilder: (_) => [
                  for (final status in OrderStatus.values)
                    PopupMenuItem(
                      value: status.name,
                      child: Text(_statusLabel(status)),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف الطلب'),
                    ),
                ],
                child: const Icon(Icons.more_horiz),
              ),
              if (order.status == OrderStatus.pending) ...[
                const SizedBox(width: 7),
                FilledButton.tonal(
                  onPressed: () => onStatusChanged(OrderStatus.confirmed),
                  child: const Text('تأكيد الطلب'),
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  );

  Widget _info(String label, String value) => RichText(
    text: TextSpan(
      style: const TextStyle(color: DariColors.secondary, fontSize: 12),
      children: [
        TextSpan(text: '$label: '),
        TextSpan(
          text: value,
          style: const TextStyle(
            color: DariColors.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  String _typeLabel(OrderRecord order) => switch (order.type) {
    OrderType.dineIn =>
      'داخل المطعم${order.tableNumber == null ? '' : ' • طاولة ${order.tableNumber}'}',
    OrderType.takeaway => 'سفري',
    OrderType.delivery => 'ديليفري',
  };

  String _sourceLabel(OrderSource source) => switch (source) {
    OrderSource.tableQr => 'QR الطاولة',
    OrderSource.publicLink => 'الرابط العام',
    OrderSource.cashierManual => 'كاشير',
  };

  String _statusLabel(OrderStatus status) => switch (status) {
    OrderStatus.pending => 'وارد',
    OrderStatus.confirmed => 'مؤكد',
    OrderStatus.preparing => 'قيد التحضير',
    OrderStatus.ready => 'جاهز',
    OrderStatus.completed => 'مكتمل',
    OrderStatus.cancelled => 'ملغي',
  };

  String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge(this.label, {this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: muted ? DariColors.canvas : DariColors.accentSoft,
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: muted ? DariColors.secondary : DariColors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _ManualOrderScreen extends StatefulWidget {
  const _ManualOrderScreen({required this.controller});

  final AppController controller;

  @override
  State<_ManualOrderScreen> createState() => _ManualOrderScreenState();
}

class _ManualOrderScreenState extends State<_ManualOrderScreen> {
  final _search = TextEditingController();
  String _category = 'all';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final categories = controller.categories
          .where((category) => category.isVisible)
          .toList();
      final products = controller.products.where((product) {
        return product.isVisible &&
            (_category == 'all' || product.categoryId == _category) &&
            product.nameAr.contains(_search.text);
      }).toList();
      return LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          final picker = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 17, 17, 10),
                child: Row(
                  children: [
                    const Expanded(child: SectionHeading('طلب يدوي')),
                    if (isWide) _cartTotal(controller),
                  ],
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _categoryChip('all', 'الكل'),
                    for (final category in categories)
                      _categoryChip(category.id, category.nameAr),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 9),
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن منتج',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? const EmptyState(title: 'لا توجد منتجات مطابقة')
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(15, 0, 15, 18),
                        itemCount: products.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth > 680 ? 4 : 2,
                          crossAxisSpacing: 9,
                          mainAxisSpacing: 9,
                          childAspectRatio: .88,
                        ),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final category = categories
                              .where((item) => item.id == product.categoryId)
                              .firstOrNull;
                          return ProductCard(
                            product: product,
                            categoryName: category?.nameAr ?? '',
                            onTap: () => _add(product),
                            onAdd: () => _add(product),
                            allowNetworkImage: true,
                          );
                        },
                      ),
              ),
            ],
          );
          if (!isWide) {
            return Column(
              children: [
                Expanded(child: picker),
                if (controller.cartCount > 0)
                  SafeArea(
                    minimum: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      onPressed: () => _openCheckout(context),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: Row(
                        children: [
                          Expanded(
                            child: Text('السلة • ${controller.cartCount}'),
                          ),
                          Text(formatIqd(controller.cartTotal)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(flex: 7, child: picker),
              Container(
                width: 320,
                decoration: const BoxDecoration(
                  color: DariColors.paper,
                  border: Border(right: BorderSide(color: DariColors.border)),
                ),
                child: _ManualCart(
                  controller: controller,
                  onCheckout: () => _openCheckout(context),
                ),
              ),
            ],
          );
        },
      );
    },
  );

  Widget _categoryChip(String id, String label) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 7),
    child: ChoiceChip(
      label: Text(label),
      selected: _category == id,
      showCheckmark: false,
      onSelected: (_) => setState(() => _category = id),
    ),
  );

  Widget _cartTotal(AppController controller) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        '${controller.cartCount} صنف',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      Text(
        formatIqd(controller.cartTotal),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ],
  );

  void _add(Product product) {
    if (product.variants.isEmpty) {
      widget.controller.addToCart(product);
    } else {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
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
  }

  Future<void> _openCheckout(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _ManualCheckout(
        controller: widget.controller,
        onSubmit: (type, table, name, phone, address) async {
          try {
            final order = await widget.controller.submitCart(
              type: type,
              source: OrderSource.cashierManual,
              tableNumber: table,
              customerName: name,
              customerPhone: phone,
              customerAddress: address,
            );
            if (!mounted || !sheetContext.mounted) return;
            Navigator.pop(sheetContext);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم إنشاء الطلب #${order.orderNumber}.')),
            );
          } catch (error) {
            if (!mounted || !sheetContext.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  error is OrderSubmitException
                      ? describeSubmitError(error)
                      : 'تعذر إنشاء الطلب.',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class _ManualCart extends StatelessWidget {
  const _ManualCart({required this.controller, required this.onCheckout});

  final AppController controller;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(17),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'سلة الطلب',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
        ),
        Expanded(
          child: controller.cart.isEmpty
              ? const EmptyState(title: 'السلة فارغة')
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  children: [
                    for (final line in controller.cart)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(line.product.nameAr),
                        subtitle: Text(
                          '${line.quantity} × ${formatIqd(line.unitPrice)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'تقليل الكمية',
                              onPressed: () =>
                                  controller.changeCartQuantity(line, -1),
                              icon: const Icon(Icons.remove, size: 18),
                            ),
                            Text('${line.quantity}'),
                            IconButton(
                              tooltip: 'زيادة الكمية',
                              onPressed: () =>
                                  controller.changeCartQuantity(line, 1),
                              icon: const Icon(Icons.add, size: 18),
                            ),
                            Text(formatIqd(line.subtotal)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Text('الإجمالي')),
                  Text(
                    formatIqd(controller.cartTotal),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: controller.cart.isEmpty ? null : onCheckout,
                  child: const Text('تأكيد الطلب'),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ManualCheckout extends StatefulWidget {
  const _ManualCheckout({required this.controller, required this.onSubmit});

  final AppController controller;
  final Future<void> Function(OrderType, int?, String?, String?, String?)
  onSubmit;

  @override
  State<_ManualCheckout> createState() => _ManualCheckoutState();
}

class _ManualCheckoutState extends State<_ManualCheckout> {
  final _formKey = GlobalKey<FormState>();
  final _table = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  OrderType _type = OrderType.takeaway;
  bool _submitting = false;

  @override
  void dispose() {
    _table.dispose();
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      18,
      20,
      18,
      MediaQuery.viewInsetsOf(context).bottom + 16,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'تأكيد الطلب اليدوي',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 13),
          SegmentedButton<OrderType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: OrderType.dineIn,
                label: Text('داخل المطعم'),
              ),
              ButtonSegment(value: OrderType.takeaway, label: Text('سفري')),
              ButtonSegment(value: OrderType.delivery, label: Text('ديليفري')),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.first),
          ),
          const SizedBox(height: 12),
          if (_type == OrderType.dineIn)
            TextFormField(
              controller: _table,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'رقم الطاولة'),
              validator: (value) => int.tryParse(value ?? '') == null
                  ? 'أدخل رقم طاولة صحيحًا'
                  : null,
            ),
          if (_type != OrderType.dineIn) ...[
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'اسم الزبون'),
              validator: _required,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              validator: _required,
            ),
            if (_type == OrderType.delivery) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'عنوان التوصيل'),
                validator: _required,
              ),
            ],
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('الإجمالي')),
              Text(
                formatIqd(widget.controller.cartTotal),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const CircularProgressIndicator()
                : const Text('إنشاء الطلب'),
          ),
        ],
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      _type,
      _type == OrderType.dineIn ? int.parse(_table.text) : null,
      _type == OrderType.dineIn ? null : _name.text.trim(),
      _type == OrderType.dineIn ? null : _phone.text.trim(),
      _type == OrderType.delivery ? _address.text.trim() : null,
    );
    if (mounted) setState(() => _submitting = false);
  }
}

class _CashierPinDialog extends StatefulWidget {
  const _CashierPinDialog();

  @override
  State<_CashierPinDialog> createState() => _CashierPinDialogState();
}

class _CashierPinDialogState extends State<_CashierPinDialog> {
  final _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('دخول الإدارة'),
    content: TextField(
      controller: _pin,
      obscureText: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
        child: const Text('دخول'),
      ),
    ],
  );
}
