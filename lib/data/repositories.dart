import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/restaurant.dart';
import 'menu_seed.dart';

abstract interface class ProductRepository {
  Future<List<Product>> loadProducts();
  Future<void> saveProduct(Product product);
  Future<void> deleteProduct(String productId);
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
}

abstract interface class OrderChangeSource {
  Stream<void> orderChanges({void Function(String status)? onStatus});
}

abstract interface class StaffAuthRepository {
  Future<bool> isStaffSignedIn();
  Future<void> signIn(String email, String password);
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
    values.insert(0, order);
    await _writeList(_ordersKey, values, (value) => value.toJson());
    return order;
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
}
