import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/restaurant.dart';
import 'repositories.dart';

const _sourceCodes = {
  OrderSource.tableQr: 'TABLE_QR',
  OrderSource.publicLink: 'PUBLIC_LINK',
  OrderSource.cashierManual: 'CASHIER_MANUAL',
};

const _typeCodes = {
  OrderType.dineIn: 'DINE_IN',
  OrderType.takeaway: 'TAKEAWAY',
  OrderType.delivery: 'DELIVERY',
};

String _statusCode(OrderStatus status) => status.name.toUpperCase();

T _fromCode<T>(Map<T, String> codes, Object? code, T fallback) {
  for (final entry in codes.entries) {
    if (entry.value == code) return entry.key;
  }
  return fallback;
}

OrderRecord _orderFromRow(Map<String, dynamic> row) {
  final items = (row['order_items'] as List<dynamic>? ?? []).map((value) {
    final item = Map<String, dynamic>.from(value as Map);
    return OrderItem(
      productId: item['product_id'] as String,
      productName: item['product_name'] as String,
      unitPrice: item['unit_price'] as int,
      quantity: item['quantity'] as int,
      selectedVariant: item['variant'] as String?,
    );
  }).toList();
  final status = OrderStatus.values.firstWhere(
    (value) => _statusCode(value) == row['status'],
    orElse: () => OrderStatus.pending,
  );
  return OrderRecord(
    id: row['id'] as String,
    orderNumber: '${row['order_number']}',
    source: _fromCode(_sourceCodes, row['source'], OrderSource.publicLink),
    type: _fromCode(_typeCodes, row['order_type'], OrderType.takeaway),
    tableNumber: row['table_number'] as int?,
    customerName: row['customer_name'] as String?,
    customerPhone: row['customer_phone'] as String?,
    customerAddress: row['customer_address'] as String?,
    items: items,
    total: row['total'] as int,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    status: status,
  );
}

// Maps a failure to a diagnostic stage plus the Supabase code/message.
(String, String) _classify(Object error) {
  if (error is PostgrestException) {
    final code = error.code ?? '';
    final detail = '$code ${error.message}'.trim();
    if (code == 'PGRST202' || code == '42883') return ('rpc_missing', detail);
    if (code == '42501' || code == 'PGRST301' || code == '401') {
      return ('permission', detail);
    }
    if (error.message.contains('product_unavailable')) {
      return ('product', detail);
    }
    if (code.startsWith('23')) return ('db_insert', detail);
    if (code == 'P0001') return ('rpc_validation', detail);
    return ('rpc', detail);
  }
  return ('connection', '$error');
}

String _submitMessage(Object error) {
  final text = error is PostgrestException ? error.message : '$error';
  if (text.contains('product_unavailable')) {
    return 'أحد الأصناف غير متوفر حاليًا. حدّث القائمة وأعد المحاولة.';
  }
  if (text.contains('invalid_variant') || text.contains('variant_required')) {
    return 'حجم أحد الأصناف غير صالح. أعد اختيار الصنف.';
  }
  if (text.contains('customer_required')) {
    return 'الاسم ورقم الهاتف مطلوبان.';
  }
  if (text.contains('address_required')) return 'عنوان التوصيل مطلوب.';
  if (text.contains('invalid_table')) return 'رقم الطاولة غير صالح.';
  if (text.contains('not_authorized')) {
    return 'غير مصرح لك بإنشاء هذا الطلب. سجّل الدخول كموظف.';
  }
  return 'تعذر إرسال الطلب. تحقق من الاتصال وحاول مرة أخرى.';
}

class SupabaseOrderRepository implements OrderRepository, OrderChangeSource {
  SupabaseOrderRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<OrderRecord>> loadOrders() async {
    final rows = await _client
        .from('orders')
        .select('*, order_items(*)')
        .order('created_at', ascending: false)
        .limit(500);
    return rows
        .map((row) => _orderFromRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<OrderRecord> submitOrder(OrderRecord order) async {
    try {
      final result = await _client.rpc<dynamic>(
        'create_order',
        params: {
          'p_source': _sourceCodes[order.source],
          'p_order_type': _typeCodes[order.type],
          'p_table_number': order.tableNumber,
          'p_customer_name': order.customerName,
          'p_customer_phone': order.customerPhone,
          'p_customer_address': order.customerAddress,
          'p_items': [
            for (final item in order.items)
              {
                'product_id': item.productId,
                'variant': item.selectedVariant,
                'quantity': item.quantity,
              },
          ],
        },
      );
      final data = Map<String, dynamic>.from(result as Map);
      return OrderRecord(
        id: data['id'] as String,
        orderNumber: '${data['order_number']}',
        source: order.source,
        type: order.type,
        tableNumber: order.tableNumber,
        customerName: order.customerName,
        customerPhone: order.customerPhone,
        customerAddress: order.customerAddress,
        items: order.items,
        total: data['total'] as int,
        createdAt: DateTime.parse(data['created_at'] as String).toLocal(),
      );
    } catch (error) {
      final (stage, detail) = _classify(error);
      debugPrint('create_order failed [$stage] $detail');
      throw OrderSubmitException(
        _submitMessage(error),
        stage: stage,
        detail: detail,
      );
    }
  }

  @override
  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final List<dynamic> updated;
    try {
      updated = await _client
          .from('orders')
          .update({'status': _statusCode(status)})
          .eq('id', orderId)
          .select('id');
    } catch (error) {
      final (stage, detail) = _classify(error);
      debugPrint('order status update failed [$stage] $detail');
      throw OrderStatusException(
        stage == 'permission'
            ? 'انتهت صلاحية الجلسة أو لا تملك صلاحية تعديل الطلب.'
            : 'تعذر تحديث حالة الطلب. تحقق من الاتصال وحاول مرة أخرى.',
        detail: detail,
      );
    }
    // RLS filters unauthorized rows silently, so zero rows means no update.
    if (updated.isEmpty) {
      throw const OrderStatusException(
        'لم يتم تحديث الطلب. سجّل الدخول كموظف وحاول مرة أخرى.',
        detail: 'no_rows_updated',
      );
    }
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    try {
      await _client.rpc<dynamic>(
        'delete_processed_order',
        params: {'p_order_id': orderId},
      );
    } catch (error) {
      throw _deletionException(error, 'تعذر حذف الطلب');
    }
  }

  @override
  Future<List<String>> deleteProcessedOrders() async {
    try {
      final result = await _client.rpc<dynamic>('delete_processed_orders');
      if (result is! List) {
        throw const FormatException(
          'Unexpected delete_processed_orders result',
        );
      }
      return result.map((id) => id as String).toList();
    } catch (error) {
      throw _deletionException(error, 'تعذر حذف الطلبات المعالجة');
    }
  }

  OrderDeletionException _deletionException(Object error, String message) {
    final detail = error is PostgrestException
        ? '${error.code ?? ''} ${error.message}'.trim()
        : '$error';
    final errorText = error is PostgrestException ? error.message : '$error';
    final userMessage = errorText.contains('not_authorized')
        ? 'انتهت صلاحية الجلسة أو لا تملك صلاحية حذف الطلبات.'
        : errorText.contains('order_not_deletable')
        ? 'لا يمكن حذف الطلب غير المعالج أو غير الموجود.'
        : '$message. تحقق من الاتصال وصلاحية الموظف ثم حاول مرة أخرى.';
    debugPrint('order deletion failed: $detail');
    return OrderDeletionException(userMessage, detail: detail);
  }

  @override
  Stream<void> orderChanges({void Function(String status)? onStatus}) {
    late final StreamController<void> controller;
    RealtimeChannel? channel;
    controller = StreamController<void>(
      onListen: () {
        channel = _client
            .channel('dari-orders')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'orders',
              callback: (_) => controller.add(null),
            )
            .subscribe((status, error) {
              final text = error == null
                  ? status.name
                  : '${status.name}: $error';
              debugPrint('realtime orders: $text');
              onStatus?.call(text);
            });
      },
      onCancel: () async {
        final active = channel;
        if (active != null) await _client.removeChannel(active);
      },
    );
    return controller.stream;
  }
}

class SupabaseStaffAuthRepository implements StaffAuthRepository {
  SupabaseStaffAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isStaffSignedIn() async {
    if (_client.auth.currentSession == null) return false;
    try {
      return await _client.rpc<dynamic>('is_staff') == true;
    } catch (error) {
      debugPrint('is_staff RPC failed: $error');
      return false;
    }
  }

  // Temporary diagnostics: reports which stage failed (auth, RPC, or is_staff=false).
  @override
  Future<void> signIn(String identifier, String password) async {
    try {
      if (identifier.contains('@')) {
        await _client.auth.signInWithPassword(
          email: identifier,
          password: password,
        );
      } else {
        await _client.auth.signInWithPassword(
          phone: identifier,
          password: password,
        );
      }
    } on AuthException catch (error) {
      debugPrint(
        'signInWithPassword failed: ${error.statusCode} ${error.message}',
      );
      throw StaffSignInException(
        'auth',
        '${error.statusCode ?? ''} ${error.message}'.trim(),
      );
    } catch (error) {
      throw StaffSignInException('auth', '$error');
    }

    final Object? result;
    try {
      result = await _client.rpc<dynamic>('is_staff');
    } catch (error) {
      debugPrint('is_staff RPC failed: $error');
      await _client.auth.signOut();
      throw StaffSignInException(
        'rpc',
        error is PostgrestException
            ? '${error.code ?? ''} ${error.message}'.trim()
            : '$error',
      );
    }
    if (result != true) {
      debugPrint('is_staff returned: $result');
      await _client.auth.signOut();
      throw StaffSignInException('not_staff', 'is_staff() = $result');
    }
    try {
      debugPrint(
        'dari_diagnostics: ${await _client.rpc<dynamic>('dari_diagnostics')}',
      );
    } catch (error) {
      debugPrint('dari_diagnostics unavailable (run migration 002): $error');
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();

  @override
  Stream<void> sessionEnded() => _client.auth.onAuthStateChange.where(
    (state) => state.event == AuthChangeEvent.signedOut,
  );
}

/// Loads the menu from Supabase and falls back to the local seed when the
/// backend is empty or unreachable. Writes go to Supabase for staff sessions.
class SupabaseCatalogRepository
    implements ProductRepository, ProductImageStorage, CategoryRepository {
  SupabaseCatalogRepository(this._client, this._local);

  static const _productImagesBucket = 'product-images';

  final SupabaseClient _client;
  final MockLocalRepository _local;

  bool get _isSignedIn => _client.auth.currentSession != null;

  @override
  Future<List<Category>> loadCategories() async {
    try {
      final rows = await _client
          .from('categories')
          .select()
          .order('sort_order');
      if (rows.isNotEmpty) {
        return rows
            .map(
              (row) => Category(
                id: row['id'] as String,
                nameAr: row['name_ar'] as String,
                nameEn: row['name_en'] as String? ?? '',
                isVisible: row['is_visible'] as bool? ?? true,
                sortOrder: row['sort_order'] as int? ?? 0,
              ),
            )
            .toList();
      }
    } catch (_) {}
    return _local.loadCategories();
  }

  @override
  Future<void> saveCategory(Category category) async {
    if (_isSignedIn) {
      await _client.from('categories').upsert({
        'id': category.id,
        'name_ar': category.nameAr,
        'name_en': category.nameEn,
        'is_visible': category.isVisible,
        'sort_order': category.sortOrder,
      });
    }
    await _local.saveCategory(category);
  }

  @override
  Future<void> deleteCategory(String categoryId) async {
    if (_isSignedIn) {
      await _client.from('categories').delete().eq('id', categoryId);
    }
    await _local.deleteCategory(categoryId);
  }

  @override
  Future<List<Product>> loadProducts() async {
    try {
      final rows = await _client.from('products').select().order('sort_order');
      if (rows.isNotEmpty) {
        return rows
            .map(
              (row) => Product(
                id: row['id'] as String,
                categoryId: row['category_id'] as String,
                nameAr: row['name_ar'] as String,
                nameEn: row['name_en'] as String? ?? '',
                descriptionAr: row['description_ar'] as String? ?? '',
                descriptionEn: row['description_en'] as String? ?? '',
                image: row['image'] as String?,
                price: row['price'] as int,
                isAvailable: row['is_available'] as bool? ?? true,
                isVisible: row['is_visible'] as bool? ?? true,
                sortOrder: row['sort_order'] as int? ?? 0,
                variants: (row['variants'] as List<dynamic>? ?? [])
                    .map(
                      (value) => ProductVariant.fromJson(
                        Map<String, dynamic>.from(value as Map),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();
      }
    } catch (_) {}
    return _local.loadProducts();
  }

  @override
  Future<void> saveProduct(Product product) async {
    if (!_isSignedIn) {
      throw StateError('Sign in as staff before saving products.');
    }
    await _client.from('products').upsert({
      'id': product.id,
      'category_id': product.categoryId,
      'name_ar': product.nameAr,
      'name_en': product.nameEn,
      'description_ar': product.descriptionAr,
      'description_en': product.descriptionEn,
      'image': product.image,
      'price': product.price,
      'is_available': product.isAvailable,
      'is_visible': product.isVisible,
      'sort_order': product.sortOrder,
      'variants': product.variants.map((value) => value.toJson()).toList(),
    });
    await _local.saveProduct(product);
  }

  @override
  Future<String> uploadProductImage({
    required String productId,
    required Uint8List bytes,
    required String extension,
    required String contentType,
  }) async {
    if (!_isSignedIn) {
      throw StateError('Sign in as staff before uploading product images.');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(productId)) {
      throw ArgumentError.value(productId, 'productId', 'Invalid path segment');
    }
    final path =
        'products/$productId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    final storage = _client.storage.from(_productImagesBucket);
    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );
    return storage.getPublicUrl(path);
  }

  @override
  Future<void> deleteProductImage(String imageUrl) async {
    if (!_isSignedIn) {
      throw StateError('Sign in as staff before deleting product images.');
    }
    final base = Uri.parse(
      _client.storage.from(_productImagesBucket).getPublicUrl(''),
    );
    final uri = Uri.tryParse(imageUrl);
    final prefix = '${base.path}${base.path.endsWith('/') ? '' : '/'}';
    if (uri == null ||
        uri.origin != base.origin ||
        !uri.path.startsWith(prefix)) {
      return;
    }
    final path = Uri.decodeComponent(uri.path.substring(prefix.length));
    if (path.isNotEmpty) {
      await _client.storage.from(_productImagesBucket).remove([path]);
    }
  }

  @override
  Future<void> deleteProduct(String productId) async {
    if (_isSignedIn) {
      await _client.from('products').delete().eq('id', productId);
    }
    await _local.deleteProduct(productId);
  }
}

/// Keeps the existing API/Bridge settings and adds a Supabase reachability test.
class SupabaseConnectionRepository implements ConnectionRepository {
  SupabaseConnectionRepository(this._client, this._local);

  final SupabaseClient _client;
  final ConnectionRepository _local;

  @override
  Future<ConnectionSettings> loadSettings() => _local.loadSettings();

  @override
  Future<void> saveSettings(ConnectionSettings settings) =>
      _local.saveSettings(settings);

  @override
  Future<ConnectionStatus> testConnection(ConnectionSettings settings) async {
    try {
      await _client.from('categories').select('id').limit(1);
      return ConnectionStatus.connected;
    } catch (_) {
      return ConnectionStatus.error;
    }
  }

  // The Loyverse token lives only in the Edge Function secret; nothing secret is sent.
  @override
  Future<LoyverseTestResult> testLoyverseConnection(
    ConnectionSettings settings,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'loyverse-test-connection',
        body: {'baseUrl': settings.apiBaseUrl},
      );
      final data = response.data;
      if (data is! Map) return _loyverseFailure('unknown');
      if (data['ok'] == true) {
        final name = data['merchant_name'];
        return LoyverseTestResult(
          connected: true,
          message: 'Loyverse Connected',
          merchantName: name is String && name.isNotEmpty ? name : null,
        );
      }
      return _loyverseFailure('${data['code']}');
    } on FunctionException catch (error) {
      final details = error.details;
      return _loyverseFailure(
        error.status == 404
            ? 'function_not_deployed'
            : details is Map
            ? '${details['code']}'
            : 'unknown',
      );
    } catch (_) {
      return _loyverseFailure('network_error');
    }
  }

  LoyverseTestResult _loyverseFailure(String code) => LoyverseTestResult(
    connected: false,
    message: switch (code) {
      'unauthorized' => 'Loyverse رفض الـ Access Token. تحقق من صلاحيته.',
      'token_not_configured' =>
        'لم يتم ضبط السر LOYVERSE_ACCESS_TOKEN في Supabase.',
      'invalid_base_url' =>
        'API Base URL غير مدعوم. استخدم https://api.loyverse.com/v1.0',
      'rate_limited' => 'Loyverse يحدّ الطلبات حالياً. حاول بعد قليل.',
      'forbidden' => 'يجب تسجيل الدخول كموظف لاختبار الاتصال.',
      'function_not_deployed' =>
        'لم يتم نشر الدالة loyverse-test-connection في Supabase.',
      'network_error' => 'تعذر الوصول إلى Loyverse. تحقق من الشبكة.',
      _ => 'فشل الاتصال بـ Loyverse.',
    },
  );
}
