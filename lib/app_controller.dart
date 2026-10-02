import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import 'data/repositories.dart';
import 'models/restaurant.dart';

class CartLine {
  const CartLine({
    required this.product,
    required this.unitPrice,
    required this.quantity,
    this.variant,
  });

  final Product product;
  final int unitPrice;
  final int quantity;
  final String? variant;
  int get subtotal => unitPrice * quantity;
  String get key => '${product.id}:${variant ?? ''}';

  CartLine copyWith({int? quantity}) => CartLine(
    product: product,
    unitPrice: unitPrice,
    quantity: quantity ?? this.quantity,
    variant: variant,
  );
}

class AppController extends ChangeNotifier {
  AppController({
    required this.productRepository,
    required this.categoryRepository,
    required this.orderRepository,
    required this.connectionRepository,
    required this.authRepository,
    required this.qrRepository,
    this.restaurantSettingsRepository,
    this.staffAuth,
  });

  final ProductRepository productRepository;
  final CategoryRepository categoryRepository;
  final OrderRepository orderRepository;
  final ConnectionRepository connectionRepository;
  final AuthRepository authRepository;
  final QrRepository qrRepository;
  final RestaurantSettingsRepository? restaurantSettingsRepository;
  final StaffAuthRepository? staffAuth;

  StreamSubscription<void>? _orderSubscription;
  StreamSubscription<void>? _sessionSubscription;
  Timer? _orderPoller;
  Future<OrderRecord>? _pendingSubmit;

  bool get isCloudBacked => staffAuth != null;

  String realtimeStatus = 'idle';
  String? ordersError;
  bool staffSessionExpired = false;

  List<Product> products = [];
  List<Category> categories = [];
  List<OrderRecord> orders = [];
  List<CartLine> cart = [];
  ConnectionSettings connectionSettings = const ConnectionSettings();
  RestaurantSettings restaurantSettings = const RestaurantSettings();
  bool isLoading = true;

  int get cartCount => cart.fold(0, (sum, line) => sum + line.quantity);
  int get cartTotal => cart.fold(0, (sum, line) => sum + line.subtotal);

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    final results = await Future.wait<Object>([
      productRepository.loadProducts(),
      categoryRepository.loadCategories(),
      _safeLoadOrders(),
      connectionRepository.loadSettings(),
      restaurantSettingsRepository?.loadRestaurantSettings() ??
          Future.value(const RestaurantSettings()),
    ]);
    products = results[0] as List<Product>;
    categories = results[1] as List<Category>;
    orders = results[2] as List<OrderRecord>;
    connectionSettings = results[3] as ConnectionSettings;
    restaurantSettings = results[4] as RestaurantSettings;
    qrRepository.configurePublicMenuUrl(restaurantSettings.publicMenuUrl);
    isLoading = false;
    notifyListeners();
    if (await staffAuth?.isStaffSignedIn() ?? false) {
      await refreshOrders();
      _startOrderSync();
    }
  }

  // Customers (anon) cannot read orders under RLS, so failures mean an empty list.
  Future<List<OrderRecord>> _safeLoadOrders() async {
    try {
      return await orderRepository.loadOrders();
    } catch (_) {
      return orders;
    }
  }

  Future<void> refreshOrders() async {
    try {
      orders = await orderRepository.loadOrders();
      ordersError = null;
    } catch (error) {
      ordersError = '$error';
      debugPrint('orders query failed: $error');
    }
    notifyListeners();
  }

  Future<bool> hasStaffSession() async =>
      staffAuth == null || await staffAuth!.isStaffSignedIn();

  Future<void> signInStaff(String email, String password) async {
    await staffAuth!.signIn(email, password);
    staffSessionExpired = false;
    final results = await Future.wait<Object>([
      productRepository.loadProducts(),
      categoryRepository.loadCategories(),
    ]);
    products = results[0] as List<Product>;
    categories = results[1] as List<Category>;
    await refreshOrders();
    _startOrderSync();
  }

  void _startOrderSync() {
    final source = orderRepository;
    if (source is OrderChangeSource && _orderSubscription == null) {
      _orderSubscription = (source as OrderChangeSource)
          .orderChanges(
            onStatus: (status) {
              final recovered =
                  status == 'subscribed' && realtimeStatus != 'subscribed';
              realtimeStatus = status;
              notifyListeners();
              // Orders created while the channel was down are not replayed.
              if (recovered) refreshOrders();
            },
          )
          .listen((_) => refreshOrders());
    }
    _sessionSubscription ??= staffAuth?.sessionEnded().listen(
      (_) => _onStaffSessionEnded(),
    );
    // Fallback only: polls while the realtime channel is not subscribed.
    _orderPoller ??= Timer.periodic(const Duration(seconds: 20), (_) {
      if (realtimeStatus != 'subscribed') refreshOrders();
    });
  }

  void _onStaffSessionEnded() {
    _orderSubscription?.cancel();
    _orderSubscription = null;
    _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _orderPoller?.cancel();
    _orderPoller = null;
    orders = [];
    realtimeStatus = 'idle';
    staffSessionExpired = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    _sessionSubscription?.cancel();
    _orderPoller?.cancel();
    super.dispose();
  }

  void addToCart(Product product, {ProductVariant? variant}) {
    if (!product.isAvailable) return;
    final price = variant?.price ?? product.price;
    final line = CartLine(
      product: product,
      unitPrice: price,
      quantity: 1,
      variant: variant?.nameAr,
    );
    final index = cart.indexWhere((value) => value.key == line.key);
    if (index < 0) {
      cart = [...cart, line];
    } else {
      cart = [
        for (var i = 0; i < cart.length; i++)
          if (i == index)
            cart[i].copyWith(quantity: cart[i].quantity + 1)
          else
            cart[i],
      ];
    }
    notifyListeners();
  }

  void changeCartQuantity(CartLine line, int delta) {
    final index = cart.indexWhere((value) => value.key == line.key);
    if (index < 0) return;
    final quantity = cart[index].quantity + delta;
    cart = quantity < 1
        ? cart.where((value) => value.key != line.key).toList()
        : [
            for (var i = 0; i < cart.length; i++)
              if (i == index) cart[i].copyWith(quantity: quantity) else cart[i],
          ];
    notifyListeners();
  }

  void removeFromCart(CartLine line) {
    cart = cart.where((value) => value.key != line.key).toList();
    notifyListeners();
  }

  void clearCart() {
    cart = [];
    notifyListeners();
  }

  // Without a server-side idempotency key, a second request cannot be told
  // apart from the first, so only one submission may be in flight at a time.
  Future<OrderRecord> submitCart({
    required OrderType type,
    required OrderSource source,
    int? tableNumber,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) {
    if (_pendingSubmit != null) {
      throw const OrderSubmitException(
        'طلبك السابق ما زال قيد الإرسال. انتظر قليلًا قبل المحاولة من جديد.',
        stage: 'in_flight',
      );
    }
    final work = _submitNow(
      type: type,
      source: source,
      tableNumber: tableNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
    );
    _pendingSubmit = work;
    // The lock is held until the real request ends, even if the caller times out.
    work.then<void>((_) {}, onError: (_) {}).then((_) => _pendingSubmit = null);
    return work.timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw const OrderSubmitException(
        'تأخر الرد ولم نتأكد من استلام الطلب. قد يكون قد وصل؛ اسأل الموظف قبل إعادة الإرسال.',
        stage: 'timeout',
        detail: '25s',
      ),
    );
  }

  Future<OrderRecord> _submitNow({
    required OrderType type,
    required OrderSource source,
    int? tableNumber,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
  }) async {
    if (cart.isEmpty) throw StateError('empty_cart');
    final now = DateTime.now();
    final number = (1001 + orders.length).toString();
    final order = OrderRecord(
      id: '${now.microsecondsSinceEpoch}',
      orderNumber: number,
      source: source,
      type: type,
      tableNumber: tableNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      items: cart
          .map(
            (line) => OrderItem(
              productId: line.product.id,
              productName: line.product.nameAr,
              unitPrice: line.unitPrice,
              quantity: line.quantity,
              selectedVariant: line.variant,
            ),
          )
          .toList(),
      total: cartTotal,
      createdAt: now,
    );
    final stored = await orderRepository.submitOrder(order);
    orders = await _safeLoadOrders();
    cart = [];
    notifyListeners();
    return stored;
  }

  Future<void> updateOrderStatus(OrderRecord order, OrderStatus status) async {
    await orderRepository.updateOrderStatus(order.id, status);
    await refreshOrders();
  }

  Future<void> saveProduct(Product product) async {
    await productRepository.saveProduct(product);
    products = await productRepository.loadProducts();
    notifyListeners();
  }

  Future<void> deleteProduct(Product product) async {
    await productRepository.deleteProduct(product.id);
    products = await productRepository.loadProducts();
    notifyListeners();
  }

  Future<void> saveCategory(Category category) async {
    await categoryRepository.saveCategory(category);
    categories = await categoryRepository.loadCategories();
    notifyListeners();
  }

  Future<void> deleteCategory(Category category) async {
    await categoryRepository.deleteCategory(category.id);
    categories = await categoryRepository.loadCategories();
    notifyListeners();
  }

  Future<void> saveConnectionSettings(ConnectionSettings settings) async {
    await connectionRepository.saveSettings(settings);
    connectionSettings = settings;
    notifyListeners();
  }

  Future<void> saveRestaurantSettings(RestaurantSettings settings) async {
    final repository = restaurantSettingsRepository;
    if (repository == null) return;
    await repository.saveRestaurantSettings(settings);
    restaurantSettings = settings;
    qrRepository.configurePublicMenuUrl(settings.publicMenuUrl);
    notifyListeners();
  }
}
