import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_controller.dart';
import 'data/repositories.dart';
import 'data/supabase_config.dart';
import 'data/supabase_repositories.dart';
import 'screens/cashier_screen.dart';
import 'screens/customer_menu.dart';
import 'screens/staff_sign_in.dart';
import 'ui/brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Release builds must never fall back to the device-local mock repository.
  if (kReleaseMode && !SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  final preferences = await SharedPreferences.getInstance();
  final repository = MockLocalRepository(preferences);
  late final AppController controller;
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
    final client = Supabase.instance.client;
    // Staff must enter email/password on every app start; drop any persisted session.
    if (client.auth.currentSession != null) {
      await client.auth.signOut(scope: SignOutScope.local);
    }
    final catalog = SupabaseCatalogRepository(client, repository);
    final orders = SupabaseOrderRepository(client);
    controller = AppController(
      productRepository: catalog,
      categoryRepository: catalog,
      orderRepository: orders,
      connectionRepository: SupabaseConnectionRepository(client, repository),
      authRepository: DevelopmentAuthRepository(),
      qrRepository: QrLinkRepository(),
      restaurantSettingsRepository: repository,
      staffAuth: SupabaseStaffAuthRepository(client),
    );
  } else {
    controller = AppController(
      productRepository: repository,
      categoryRepository: repository,
      orderRepository: repository,
      connectionRepository: repository,
      authRepository: DevelopmentAuthRepository(),
      qrRepository: QrLinkRepository(),
      restaurantSettingsRepository: repository,
    );
  }
  await controller.load();
  runApp(DariRestaurantApp(controller: controller));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configuration error: SUPABASE_URL and SUPABASE_ANON_KEY were '
              'not provided at build time. Rebuild with both --dart-define '
              'values.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class DariRestaurantApp extends StatelessWidget {
  const DariRestaurantApp({
    super.key,
    required this.controller,
    this.initialUri,
  });

  final AppController controller;
  final Uri? initialUri;

  Uri? get _menuUri {
    final current = initialUri ?? Uri.base;
    if (current.path == '/menu') return current;
    if (current.fragment.startsWith('/menu')) {
      return Uri.tryParse(current.fragment);
    }
    return null;
  }

  int? _tableNumber(Uri uri) =>
      int.tryParse(uri.queryParameters['table'] ?? '');

  bool _hasInvalidTable(Uri uri) =>
      uri.queryParameters.containsKey('table') &&
      (_tableNumber(uri) == null || _tableNumber(uri)! < 1);

  @override
  Widget build(BuildContext context) {
    final uri = _menuUri;
    return MaterialApp(
      title: 'DARI Restaurant | مطعم داري',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildDariTheme(),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
      home: uri == null
          ? PinLoginScreen(controller: controller)
          : CustomerMenuScreen(
              controller: controller,
              tableNumber: _tableNumber(uri),
              invalidTable: _hasInvalidTable(uri),
            ),
      onGenerateRoute: (settings) {
        final route = Uri.tryParse(settings.name ?? '');
        if (route?.path == '/menu') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => CustomerMenuScreen(
              controller: controller,
              tableNumber: route == null ? null : _tableNumber(route),
              invalidTable: route != null && _hasInvalidTable(route),
            ),
          );
        }
        if (route?.path == '/cashier') {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => PinLoginScreen(controller: controller),
          );
        }
        return null;
      },
    );
  }
}

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  String _pin = '';
  bool _isChecking = false;
  String? _error;

  // Covers both the top number row and the numpad (whose keyLabel is "Numpad 1").
  static const _digitKeys = [
    (LogicalKeyboardKey.digit0, LogicalKeyboardKey.numpad0),
    (LogicalKeyboardKey.digit1, LogicalKeyboardKey.numpad1),
    (LogicalKeyboardKey.digit2, LogicalKeyboardKey.numpad2),
    (LogicalKeyboardKey.digit3, LogicalKeyboardKey.numpad3),
    (LogicalKeyboardKey.digit4, LogicalKeyboardKey.numpad4),
    (LogicalKeyboardKey.digit5, LogicalKeyboardKey.numpad5),
    (LogicalKeyboardKey.digit6, LogicalKeyboardKey.numpad6),
    (LogicalKeyboardKey.digit7, LogicalKeyboardKey.numpad7),
    (LogicalKeyboardKey.digit8, LogicalKeyboardKey.numpad8),
    (LogicalKeyboardKey.digit9, LogicalKeyboardKey.numpad9),
  ];

  String? _digitFor(LogicalKeyboardKey key) {
    for (var i = 0; i < _digitKeys.length; i++) {
      if (key == _digitKeys[i].$1 || key == _digitKeys[i].$2) return '$i';
    }
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || _isChecking) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final digit = _digitFor(key);
    if (digit != null) {
      _press(digit);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _press('⌫');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_pin.length == 4) _verify();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    onKeyEvent: _onKey,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: DariColors.ink,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: const Icon(
                      Icons.local_dining_outlined,
                      color: Colors.white,
                      size: 35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DARI',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'مطعم داري',
                    style: TextStyle(color: DariColors.secondary, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(21),
                    decoration: BoxDecoration(
                      color: DariColors.paper,
                      border: Border.all(color: DariColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'دخول الكاشير',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'أدخل الرقم السري للمتابعة',
                          style: TextStyle(color: DariColors.secondary),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var index = 0; index < 4; index++)
                              Container(
                                width: 14,
                                height: 14,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: index < _pin.length
                                      ? DariColors.ink
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _error == null
                                        ? DariColors.secondary
                                        : DariColors.danger,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: DariColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            for (var digit = 1; digit <= 9; digit++)
                              _key('$digit'),
                            _key('مسح'),
                            _key('0'),
                            _key('⌫'),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _pin.length == 4 && !_isChecking
                                ? _verify
                                : null,
                            child: _isChecking
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('دخول'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/menu'),
                    icon: const Icon(Icons.menu_book_outlined, size: 18),
                    label: const Text('عرض قائمة الزبون'),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'طعم مختلف .. تجربة تستحق',
                    style: TextStyle(color: DariColors.secondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _key(String value) => SizedBox(
    width: 82,
    height: 54,
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: OutlinedButton(
        onPressed: _isChecking ? null : () => _press(value),
        style: OutlinedButton.styleFrom(
          backgroundColor: DariColors.canvas,
          side: const BorderSide(color: DariColors.border),
          padding: EdgeInsets.zero,
        ),
        child: Text(
          value,
          style: const TextStyle(
            color: DariColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ),
  );

  void _press(String key) => setState(() {
    _error = null;
    if (key == 'مسح') {
      _pin = '';
    } else if (key == '⌫') {
      if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
    } else if (_pin.length < 4) {
      _pin += key;
    }
  });

  Future<void> _verify() async {
    setState(() => _isChecking = true);
    final authorized = await widget.controller.authRepository.authenticate(
      _pin,
      AuthRole.cashierAdmin,
    );
    if (!mounted) return;
    if (!authorized) {
      setState(() {
        _pin = '';
        _error = 'الرقم السري غير صحيح. حاول مرة أخرى.';
        _isChecking = false;
      });
      return;
    }
    if (!await ensureStaffSignedIn(context, widget.controller)) {
      if (mounted) setState(() => _isChecking = false);
      return;
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CashierScreen(controller: widget.controller),
      ),
    );
  }
}
