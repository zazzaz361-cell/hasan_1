enum OrderType { dineIn, takeaway, delivery }

enum OrderSource { tableQr, publicLink, cashierManual }

enum OrderStatus { pending, confirmed, preparing, ready, completed, cancelled }

enum ConnectionStatus { connected, disconnected, connecting, error }

class Category {
  const Category({
    required this.id,
    required this.nameAr,
    this.nameEn = '',
    this.isVisible = true,
    this.sortOrder = 0,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final bool isVisible;
  final int sortOrder;

  Map<String, Object?> toJson() => {
    'id': id,
    'nameAr': nameAr,
    'nameEn': nameEn,
    'isVisible': isVisible,
    'sortOrder': sortOrder,
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    nameAr: json['nameAr'] as String,
    nameEn: json['nameEn'] as String? ?? '',
    isVisible: json['isVisible'] as bool? ?? true,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );
}

class ProductVariant {
  const ProductVariant({required this.nameAr, required this.price});

  final String nameAr;
  final int price;

  Map<String, Object?> toJson() => {'nameAr': nameAr, 'price': price};

  factory ProductVariant.fromJson(Map<String, dynamic> json) => ProductVariant(
    nameAr: json['nameAr'] as String,
    price: json['price'] as int,
  );
}

class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.nameAr,
    required this.price,
    this.nameEn = '',
    this.descriptionAr = '',
    this.descriptionEn = '',
    this.image,
    this.isAvailable = true,
    this.isVisible = true,
    this.sortOrder = 0,
    this.variants = const [],
  });

  final String id;
  final String categoryId;
  final String nameAr;
  final String nameEn;
  final String descriptionAr;
  final String descriptionEn;
  final String? image;
  final bool isAvailable;
  final bool isVisible;
  final int sortOrder;
  final List<ProductVariant> variants;
  final int price;

  Product copyWith({
    String? categoryId,
    String? nameAr,
    String? nameEn,
    String? descriptionAr,
    String? image,
    bool clearImage = false,
    int? price,
    bool? isAvailable,
    bool? isVisible,
    int? sortOrder,
    List<ProductVariant>? variants,
  }) => Product(
    id: id,
    categoryId: categoryId ?? this.categoryId,
    nameAr: nameAr ?? this.nameAr,
    nameEn: nameEn ?? this.nameEn,
    descriptionAr: descriptionAr ?? this.descriptionAr,
    descriptionEn: descriptionEn,
    image: clearImage ? null : image ?? this.image,
    price: price ?? this.price,
    isAvailable: isAvailable ?? this.isAvailable,
    isVisible: isVisible ?? this.isVisible,
    sortOrder: sortOrder ?? this.sortOrder,
    variants: variants ?? this.variants,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'nameAr': nameAr,
    'nameEn': nameEn,
    'descriptionAr': descriptionAr,
    'descriptionEn': descriptionEn,
    'image': image,
    'price': price,
    'isAvailable': isAvailable,
    'isVisible': isVisible,
    'sortOrder': sortOrder,
    'variants': variants.map((variant) => variant.toJson()).toList(),
  };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    nameAr: json['nameAr'] as String,
    nameEn: json['nameEn'] as String? ?? '',
    descriptionAr: json['descriptionAr'] as String? ?? '',
    descriptionEn: json['descriptionEn'] as String? ?? '',
    image: json['image'] as String?,
    price: json['price'] as int,
    isAvailable: json['isAvailable'] as bool? ?? true,
    isVisible: json['isVisible'] as bool? ?? true,
    sortOrder: json['sortOrder'] as int? ?? 0,
    variants: (json['variants'] as List<dynamic>? ?? [])
        .map(
          (value) =>
              ProductVariant.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
  );
}

class OrderItem {
  const OrderItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.selectedVariant,
  });

  final String productId;
  final String productName;
  final int unitPrice;
  final int quantity;
  final String? selectedVariant;
  int get subtotal => unitPrice * quantity;

  Map<String, Object?> toJson() => {
    'productId': productId,
    'productName': productName,
    'unitPrice': unitPrice,
    'quantity': quantity,
    'selectedVariant': selectedVariant,
  };

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productId: json['productId'] as String,
    productName: json['productName'] as String,
    unitPrice: json['unitPrice'] as int,
    quantity: json['quantity'] as int,
    selectedVariant: json['selectedVariant'] as String?,
  );
}

class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.orderNumber,
    required this.source,
    required this.type,
    required this.items,
    required this.total,
    required this.createdAt,
    this.tableNumber,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.status = OrderStatus.pending,
  });

  final String id;
  final String orderNumber;
  final OrderSource source;
  final OrderType type;
  final int? tableNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final List<OrderItem> items;
  final int total;
  final DateTime createdAt;
  final OrderStatus status;

  bool get isProcessed => status != OrderStatus.pending;

  OrderRecord copyWith({OrderStatus? status, String? orderNumber}) =>
      OrderRecord(
        id: id,
        orderNumber: orderNumber ?? this.orderNumber,
        source: source,
        type: type,
        tableNumber: tableNumber,
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        items: items,
        total: total,
        createdAt: createdAt,
        status: status ?? this.status,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'orderNumber': orderNumber,
    'source': source.name,
    'type': type.name,
    'tableNumber': tableNumber,
    'customerName': customerName,
    'customerPhone': customerPhone,
    'customerAddress': customerAddress,
    'items': items.map((item) => item.toJson()).toList(),
    'total': total,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
  };

  factory OrderRecord.fromJson(Map<String, dynamic> json) => OrderRecord(
    id: json['id'] as String,
    orderNumber: json['orderNumber'] as String,
    source: OrderSource.values.byName(json['source'] as String),
    type: OrderType.values.byName(json['type'] as String),
    tableNumber: json['tableNumber'] as int?,
    customerName: json['customerName'] as String?,
    customerPhone: json['customerPhone'] as String?,
    customerAddress: json['customerAddress'] as String?,
    items: (json['items'] as List<dynamic>)
        .map(
          (value) =>
              OrderItem.fromJson(Map<String, dynamic>.from(value as Map)),
        )
        .toList(),
    total: json['total'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    status: OrderStatus.values.byName(json['status'] as String),
  );
}

class ConnectionSettings {
  const ConnectionSettings({
    this.apiBaseUrl = '',
    this.serverUrl = '',
    this.port = '',
    this.apiKey = '',
    this.bridgeUrl = '',
    this.bridgePort = '',
    this.deviceName = 'DARI POS',
  });

  final String apiBaseUrl;
  final String serverUrl;
  final String port;
  final String apiKey;
  final String bridgeUrl;
  final String bridgePort;
  final String deviceName;

  Map<String, Object?> toJson() => {
    'apiBaseUrl': apiBaseUrl,
    'serverUrl': serverUrl,
    'port': port,
    'apiKey': apiKey,
    'bridgeUrl': bridgeUrl,
    'bridgePort': bridgePort,
    'deviceName': deviceName,
  };

  factory ConnectionSettings.fromJson(Map<String, dynamic> json) =>
      ConnectionSettings(
        apiBaseUrl: json['apiBaseUrl'] as String? ?? '',
        serverUrl: json['serverUrl'] as String? ?? '',
        port: json['port'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        bridgeUrl: json['bridgeUrl'] as String? ?? '',
        bridgePort: json['bridgePort'] as String? ?? '',
        deviceName: json['deviceName'] as String? ?? 'DARI POS',
      );
}

class RestaurantSettings {
  const RestaurantSettings({
    this.restaurantName = 'مطعم داري',
    this.logoPath = '',
    this.phone = '07731111592',
    this.socialLink = 'DARI.REST',
    this.address = '',
    this.publicMenuUrl = '',
    this.currency = 'IQD',
    this.tableCount = 20,
  });

  final String restaurantName;
  final String logoPath;
  final String phone;
  final String socialLink;
  final String address;
  final String publicMenuUrl;
  final String currency;
  final int tableCount;

  RestaurantSettings copyWith({
    String? restaurantName,
    String? logoPath,
    String? phone,
    String? socialLink,
    String? address,
    String? publicMenuUrl,
    String? currency,
    int? tableCount,
  }) => RestaurantSettings(
    restaurantName: restaurantName ?? this.restaurantName,
    logoPath: logoPath ?? this.logoPath,
    phone: phone ?? this.phone,
    socialLink: socialLink ?? this.socialLink,
    address: address ?? this.address,
    publicMenuUrl: publicMenuUrl ?? this.publicMenuUrl,
    currency: currency ?? this.currency,
    tableCount: tableCount ?? this.tableCount,
  );

  Map<String, Object?> toJson() => {
    'restaurantName': restaurantName,
    'logoPath': logoPath,
    'phone': phone,
    'socialLink': socialLink,
    'address': address,
    'publicMenuUrl': publicMenuUrl,
    'currency': currency,
    'tableCount': tableCount,
  };

  factory RestaurantSettings.fromJson(Map<String, dynamic> json) =>
      RestaurantSettings(
        restaurantName: json['restaurantName'] as String? ?? 'مطعم داري',
        logoPath: json['logoPath'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        socialLink: json['socialLink'] as String? ?? '',
        address: json['address'] as String? ?? '',
        publicMenuUrl: json['publicMenuUrl'] as String? ?? '',
        currency: json['currency'] as String? ?? 'IQD',
        tableCount: json['tableCount'] as int? ?? 20,
      );
}
