import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/restaurant.dart';
import 'menu_seed.dart';

abstract interface class ProductRepository {
  Future<List<Product>> loadProducts();
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(String productId);
}

abstract interface class ProductImageStorage {
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  });

  Future<void> deleteProductImage(String imageUrl);
}

abstract interface class CategoryRepository {
  Future<List<Category>> loadCategories();
  Future<void> saveCategory(Category category);
  Future<void> deleteCategory(String categoryId);
}

abstract interface class OrderRepository {
  Future<List<OrderRecord>> loadOrders();
  Future<OrderRecord> submitOrder(OrderRecord order);
  Future<void> updateOrderStatus(String orderId, OrderStatus status);
  Future<void> deleteOrder(String orderId);
  Future<List<String>> deleteProcessedOrders();
}

abstract interface class OrderChangeSource {
  Stream<void> orderChanges({void Function(String status)? onStatus});
}

abstract interface class StaffAuthRepository {
  Future<bool> isStaffSignedIn();
  Future<void> signIn(String identifier, String password);
  Future<void> signOut();
  Stream<void> sessionEnded();
}

class OrderSubmitException implements Exception {
  const OrderSubmitException(this.message, {this.stage = '', this.detail = ''});
  final String message;
  final String stage;
  final String detail;
}

class OrderStatusException implements Exception {
  const OrderStatusException(this.message, {this.detail = ''});
  final String message;
  final String detail;
}

class OrderDeletionException implements Exception {
  const OrderDeletionException(this.message, {this.detail = ''});
  final String message;
  final String detail;
}

// Temporary: show the failing stage and Supabase error code to the user.
const showBackendDiagnostics = bool.fromEnvironment(
  'DARI_DIAGNOSTICS',
  defaultValue: true,
);

String describeSubmitError(OrderSubmitException error) =>
    showBackendDiagnostics && error.stage.isNotEmpty
    ? '${error.message}\n[${error.stage}] ${error.detail}'
    : error.message;

class StaffSignInException implements Exception {
  const StaffSignInException(this.stage, this.detail);
  final String stage;
  final String detail;
}

abstract interface class ConnectionRepository {
  Future<ConnectionSettings> loadSettings();
  Future<void> saveSettings(ConnectionSettings settings);
  Future<ConnectionStatus> testConnection(ConnectionSettings settings);
  Future<LoyverseTestResult> testLoyverseConnection(
    ConnectionSettings settings,
  );
}

class LoyverseTestResult {
  const LoyverseTestResult({
    required this.connected,
    required this.message,
    this.merchantName,
  });

  final bool connected;
  final String message;
  final String? merchantName;
}

abstract interface class RestaurantSettingsRepository {
  Future<RestaurantSettings> loadRestaurantSettings();
  Future<void> saveRestaurantSettings(RestaurantSettings settings);
}

abstract interface class AuthRepository {
  Future<bool> authenticate(String pin, AuthRole role);
}

abstract interface class QrRepository {
  void configurePublicMenuUrl(String url);
  String buildPublicUrl();
  String buildTableUrl(int tableNumber);
}

enum AuthRole { cashierAdmin, connection }

class DevelopmentAuthRepository implements AuthRepository {
  static const cashierAdminPin = '1234';
  static const connectionPin = '2002';

  @override
  Future<bool> authenticate(String pin, AuthRole role) async =>
      pin == (role == AuthRole.connection ? connectionPin : cashierAdminPin);
}

class QrLinkRepository implements QrRepository {
  static const configuredBaseUrl = String.fromEnvironment(
    'DARI_PUBLIC_BASE_URL',
  );

  String _publicMenuUrl = '';

  Uri? get _customMenuUri {
    if (_publicMenuUrl.isEmpty) return null;
    final uri = Uri.tryParse(_publicMenuUrl);
    return uri != null && uri.hasAuthority ? uri : null;
  }

  static bool _isReachable(Uri uri) {
    if (!uri.hasAuthority || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return false;
    }
    final host = uri.host.toLowerCase();
    if (host == 'localhost' ||
        host == '0.0.0.0' ||
        host.endsWith('.local') ||
        host.endsWith('.internal') ||
        host.startsWith('127.') ||
        host.startsWith('10.') ||
        host.startsWith('192.168.')) {
      return false;
    }
    return true;
  }

  // Hash routing (/#/menu) works on any static host without server rewrites.
  Uri get _baseUri {
    final candidates = <Uri?>[
      _customMenuUri,
      if (configuredBaseUrl.isNotEmpty) Uri.tryParse(configuredBaseUrl),
      Uri.base,
    ];
    for (final candidate in candidates) {
      if (candidate != null && _isReachable(candidate)) {
        return Uri(
          scheme: candidate.scheme,
          host: candidate.host,
          port: candidate.hasPort ? candidate.port : null,
        );
      }
    }
    return Uri.parse('https://your-domain.com');
  }

  @override
  void configurePublicMenuUrl(String url) => _publicMenuUrl = url.trim();

  @override
  String buildPublicUrl() => '${_baseUri.toString()}/#/menu';

  @override
  String buildTableUrl(int tableNumber) =>
      '${_baseUri.toString()}/#/menu?table=$tableNumber';
}

class MockLocalRepository
    implements
        ProductRepository,
        CategoryRepository,
        OrderRepository,
        ConnectionRepository,
        RestaurantSettingsRepository {
  MockLocalRepository(this._preferences);

  final SharedPreferences _preferences;

  static const _productsKey = 'dari.products.v1';
  static const _categoriesKey = 'dari.categories.v1';
  static const _ordersKey = 'dari.orders.v1';
  static const _connectionKey = 'dari.connection.v1';
  static const _restaurantSettingsKey = 'dari.restaurant-settings.v1';

  List<T> _decodeList<T>(String key, T Function(Map<String, dynamic>) decode) {
    final stored = _preferences.getString(key);
    if (stored == null) return [];
    try {
      return (jsonDecode(stored) as List<dynamic>)
          .map((value) => decode(Map<String, dynamic>.from(value as Map)))
          .toList();
    } on FormatException {
      return [];
    } on TypeError {
      return [];
    }
  }

  Future<void> _writeList<T>(
    String key,
    List<T> values,
    Map<String, Object?> Function(T) encode,
  ) async {
    await _preferences.setString(key, jsonEncode(values.map(encode).toList()));
  }

  @override
  Future<List<Category>> loadCategories() async {
    final values = _decodeList(_categoriesKey, Category.fromJson);
    if (values.isNotEmpty) return values;
    await _writeList(_categoriesKey, seedCategories, (value) => value.toJson());
    return seedCategories;
  }

  @override
  Future<void> saveCategory(Category category) async {
    final values = await loadCategories();
    final index = values.indexWhere((value) => value.id == category.id);
    if (index < 0) {
      values.add(category);
    } else {
      values[index] = category;
    }
    await _writeList(_categoriesKey, values, (value) => value.toJson());
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    final values = (await loadCategories())
        .where((category) => category.id != categoryId)
        .toList();
    await _writeList(_categoriesKey, values, (value) => value.toJson());
  }

  @override
  Future<List<Product>> loadProducts() async {
    final values = _decodeList(_productsKey, Product.fromJson);
    if (values.isNotEmpty) return values;
    await _writeList(_productsKey, seedProducts, (value) => value.toJson());
    return seedProducts;
  }

  @override
  Future<void> saveProduct(Product product) async {
    final values = await loadProducts();
    final index = values.indexWhere((value) => value.id == product.id);
    if (index < 0) {
      values.add(product);
    } else {
      values[index] = product;
    }
    await _writeList(_productsKey, values, (value) => value.toJson());
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final values = (await loadProducts())
        .where((product) => product.id != productId)
        .toList();
    await _writeList(_productsKey, values, (value) => value.toJson());
  }

  @override
  Future<List<OrderRecord>> loadOrders() async =>
      _decodeList(_ordersKey, OrderRecord.fromJson);

  @override
  Future<OrderRecord> submitOrder(OrderRecord order) async {
    final values = await loadOrders();
    final now = order.createdAt.toLocal();
    final dateKey =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final counterKey = 'dari.orders.last-number.$dateKey';
    final priorNumbers = values
        .where((value) {
          final createdAt = value.createdAt.toLocal();
          return createdAt.year == now.year &&
              createdAt.month == now.month &&
              createdAt.day == now.day;
        })
        .map((value) => int.tryParse(value.orderNumber) ?? 0);
    final lastNumber =
        _preferences.getInt(counterKey) ??
        priorNumbers.fold<int>(
          0,
          (maximum, value) => value > maximum ? value : maximum,
        );
    final stored = order.copyWith(orderNumber: '${lastNumber + 1}');
    await _preferences.setInt(counterKey, lastNumber + 1);
    values.insert(0, stored);
    await _writeList(_ordersKey, values, (value) => value.toJson());
    return stored;
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final values = await loadOrders();
    final index = values.indexWhere((order) => order.id == orderId);
    if (index < 0) return;
    values[index] = values[index].copyWith(status: status);
    await _writeList(_ordersKey, values, (value) => value.toJson());
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    final values = await loadOrders();
    final index = values.indexWhere((value) => value.id == orderId);
    if (index < 0 || !values[index].isProcessed) {
      throw const OrderDeletionException(
        'لا يمكن حذف الطلب. الطلب غير موجود أو لم تتم معالجته.',
      );
    }
    await _writeList(
      _ordersKey,
      values.where((value) => value.id != orderId).toList(),
      (value) => value.toJson(),
    );
  }

  @override
  Future<List<String>> deleteProcessedOrders() async {
    final values = await loadOrders();
    final deletedIds = values
        .where((value) => value.isProcessed)
        .map((value) => value.id)
        .toList();
    await _writeList(
      _ordersKey,
      values.where((value) => !value.isProcessed).toList(),
      (value) => value.toJson(),
    );
    return deletedIds;
  }

  @override
  Future<ConnectionSettings> loadSettings() async {
    final encoded = _preferences.getString(_connectionKey);
    if (encoded == null) return const ConnectionSettings();
    try {
      return ConnectionSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } on FormatException {
      return const ConnectionSettings();
    } on TypeError {
      return const ConnectionSettings();
    }
  }

  @override
  Future<void> saveSettings(ConnectionSettings settings) async {
    await _preferences.setString(_connectionKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<RestaurantSettings> loadRestaurantSettings() async {
    final encoded = _preferences.getString(_restaurantSettingsKey);
    if (encoded == null) return const RestaurantSettings();
    try {
      return RestaurantSettings.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } on FormatException {
      return const RestaurantSettings();
    } on TypeError {
      return const RestaurantSettings();
    }
  }

  @override
  Future<void> saveRestaurantSettings(RestaurantSettings settings) async {
    await _preferences.setString(
      _restaurantSettingsKey,
      jsonEncode(settings.toJson()),
    );
  }

  @override
  Future<ConnectionStatus> testConnection(ConnectionSettings settings) async =>
      ConnectionStatus.disconnected;

  @override
  Future<LoyverseTestResult> testLoyverseConnection(
    ConnectionSettings settings,
  ) async => const LoyverseTestResult(
    connected: false,
    message: 'اختبار Loyverse يتطلب الاتصال بـ Supabase.',
  );
}
