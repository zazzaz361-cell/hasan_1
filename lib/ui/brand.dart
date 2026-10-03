import 'package:flutter/material.dart';

import '../models/restaurant.dart';

abstract final class DariColors {
  static const canvas = Color(0xFFF7F6F2);
  static const paper = Color(0xFFFFFFFF);
  static const ink = Color(0xFF191917);
  static const secondary = Color(0xFF686760);
  static const border = Color(0xFFE6E3DB);
  static const accent = Color(0xFFB85432);
  static const accentSoft = Color(0xFFF5E7E0);
  static const success = Color(0xFF39715A);
  static const danger = Color(0xFFAD433A);
}

ThemeData buildDariTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: DariColors.canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: DariColors.accent,
    surface: DariColors.paper,
    primary: DariColors.ink,
    secondary: DariColors.accent,
    error: DariColors.danger,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: DariColors.canvas,
    foregroundColor: DariColors.ink,
    elevation: 0,
    centerTitle: false,
  ),
  cardTheme: CardThemeData(
    color: DariColors.paper,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: DariColors.border),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DariColors.paper,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DariColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DariColors.border),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: DariColors.ink,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      color: DariColors.ink,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(color: DariColors.ink, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(color: DariColors.ink, fontWeight: FontWeight.w600),
    bodyMedium: TextStyle(color: DariColors.ink),
    bodySmall: TextStyle(color: DariColors.secondary),
  ),
);

String formatIqd(int amount) =>
    '${amount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')} د.ع';

class DariWordmark extends StatelessWidget {
  const DariWordmark({super.key, this.compact = false, this.light = false});

  final bool compact;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : DariColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 46,
          height: compact ? 38 : 46,
          decoration: BoxDecoration(
            border: Border.all(color: foreground, width: 1.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.local_dining_outlined,
            color: foreground,
            size: compact ? 20 : 24,
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DARI',
              style: TextStyle(
                color: foreground,
                fontSize: compact ? 18 : 21,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                'مطعم داري',
                style: TextStyle(color: foreground, fontSize: 12),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ],
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.categoryName,
    this.imageAssetPath,
    this.allowNetworkImage = false,
    required this.onTap,
    required this.onAdd,
  });

  final Product product;
  final String categoryName;
  final String? imageAssetPath;
  final bool allowNetworkImage;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final prices = product.variants.map((variant) => variant.price).toList();
    final imagePath = imageAssetPath ?? product.image;
    final priceLabel = prices.isEmpty
        ? formatIqd(product.price)
        : '${formatIqd(prices.reduce((a, b) => a < b ? a : b))}+';
    return Opacity(
      opacity: product.isAvailable ? 1 : .62,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: DariColors.paper,
            border: Border.all(color: DariColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: DariColors.canvas,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: imagePath == null || imagePath.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.restaurant_menu,
                              size: 31,
                              color: DariColors.secondary,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              categoryName,
                              style: const TextStyle(
                                color: DariColors.secondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: _productImage(
                            imagePath,
                            allowNetworkImage: allowNetworkImage,
                          ),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 2, 11, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nameAr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.isAvailable ? priceLabel : 'غير متوفر',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: product.isAvailable
                                  ? DariColors.accent
                                  : DariColors.secondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton.filled(
                            tooltip: product.isAvailable
                                ? 'أضف إلى السلة'
                                : 'غير متوفر',
                            onPressed: product.isAvailable ? onAdd : null,
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.add, size: 19),
                            style: IconButton.styleFrom(
                              backgroundColor: DariColors.ink,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: DariColors.border,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productImage(String path, {required bool allowNetworkImage}) {
    final uri = Uri.tryParse(path);
    final isNetworkImage =
        allowNetworkImage &&
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    final errorFallback = const Icon(
      Icons.image_not_supported_outlined,
      color: DariColors.secondary,
    );
    return isNetworkImage
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => errorFallback,
          )
        : Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => errorFallback,
          );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: DariColors.secondary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (message != null) ...[
            const SizedBox(height: 5),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    ),
  );
}
