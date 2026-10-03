import 'package:dari_pos/app_controller.dart';
import 'package:dari_pos/data/menu_seed.dart';
import 'package:dari_pos/data/repositories.dart';
import 'package:dari_pos/main.dart';
import 'package:dari_pos/models/restaurant.dart';
import 'package:dari_pos/ui/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('menu seed matches verified reference items and pizza prices', () {
    expect(
      seedProducts.any(
        (product) => product.nameAr == 'نقانق' && product.price == 2000,
      ),
      isTrue,
    );
    expect(
      seedProducts.any(
        (product) => product.nameAr == 'جاجيك' && product.price == 2000,
      ),
      isTrue,
    );

    final chickenPizza = seedProducts.firstWhere(
      (product) => product.id == 'pizza-chicken',
    );
    expect(
      chickenPizza.variants
          .map((variant) => (variant.nameAr, variant.price))
          .toList(),
      [('صغير', 5000), ('وسط', 8000), ('كبير', 11000)],
    );
  });

  test('product image can be cleared from the existing product field', () {
    final product = seedProducts.first.copyWith(
      image: 'https://storage.example/product.png',
    );

    expect(product.copyWith(clearImage: true).image, isNull);
  });

  testWidgets('product cards render stored network image URLs', (tester) async {
    final product = seedProducts.first.copyWith(
      image: 'https://storage.example/product.png',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 240,
            child: ProductCard(
              product: product,
              categoryName: 'الريزو',
              allowNetworkImage: true,
              onTap: () {},
              onAdd: () {},
            ),
          ),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
  });

  testWidgets('cashier PIN opens the order inbox', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = MockLocalRepository(preferences);
    final controller = AppController(
      productRepository: repository,
      categoryRepository: repository,
      orderRepository: repository,
      connectionRepository: repository,
      authRepository: DevelopmentAuthRepository(),
      qrRepository: QrLinkRepository(),
    );
    await controller.load();

    await tester.pumpWidget(DariRestaurantApp(controller: controller));
    await tester.pumpAndSettle();
    for (final digit in ['1', '2', '3', '4']) {
      await tester.tap(find.text(digit).first);
      await tester.pump();
    }
    await tester.tap(find.text('دخول').last);
    await tester.pumpAndSettle();

    expect(find.text('الطلبات الواردة'), findsOneWidget);
    expect(find.text('لا توجد طلبات بعد'), findsOneWidget);
  });

  testWidgets('table menu keeps cart and submits the order', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = MockLocalRepository(preferences);
    final controller = AppController(
      productRepository: repository,
      categoryRepository: repository,
      orderRepository: repository,
      connectionRepository: repository,
      authRepository: DevelopmentAuthRepository(),
      qrRepository: QrLinkRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      DariRestaurantApp(
        controller: controller,
        initialUri: Uri.parse('https://dari.test/menu?table=5'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('طاولة 5'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('ريزو كرسبي داري'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('ريزو كرسبي داري'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أضف إلى السلة'));
    await tester.pumpAndSettle();

    expect(controller.cartCount, 1);
    await tester.tap(find.textContaining('السلة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إرسال الطلب إلى الكاشير'));
    await tester.pumpAndSettle();

    expect(controller.orders, hasLength(1));
    expect(controller.orders.single.tableNumber, 5);
    expect(controller.orders.single.source, OrderSource.tableQr);
  });

  testWidgets('public takeaway requires customer details', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = MockLocalRepository(preferences);
    final controller = AppController(
      productRepository: repository,
      categoryRepository: repository,
      orderRepository: repository,
      connectionRepository: repository,
      authRepository: DevelopmentAuthRepository(),
      qrRepository: QrLinkRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      DariRestaurantApp(
        controller: controller,
        initialUri: Uri.parse('https://dari.test/menu'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('سفري').first);
    await tester.pumpAndSettle();
    controller.addToCart(
      controller.products.firstWhere((product) => product.id == 'rizo-dari'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('السلة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تأكيد الطلب'));
    await tester.pumpAndSettle();

    expect(find.text('هذا الحقل مطلوب'), findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).at(0), 'علي');
    await tester.enterText(find.byType(TextFormField).at(1), '07730000000');
    await tester.tap(find.text('تأكيد الطلب'));
    await tester.pumpAndSettle();

    expect(controller.orders, hasLength(1));
    expect(controller.orders.single.type, OrderType.takeaway);
    expect(controller.orders.single.source, OrderSource.publicLink);
    expect(controller.orders.single.customerPhone, '07730000000');
  });

  testWidgets('invalid table link shows an error instead of public ordering', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = MockLocalRepository(preferences);
    final controller = AppController(
      productRepository: repository,
      categoryRepository: repository,
      orderRepository: repository,
      connectionRepository: repository,
      authRepository: DevelopmentAuthRepository(),
      qrRepository: QrLinkRepository(),
    );
    await controller.load();

    await tester.pumpWidget(
      DariRestaurantApp(
        controller: controller,
        initialUri: Uri.parse('https://dari.test/menu?table=invalid'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('رابط الطاولة غير صالح'), findsOneWidget);
    expect(find.text('اختر نوع الطلب'), findsNothing);
  });
}
