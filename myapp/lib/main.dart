import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/services/supabase_service.dart';
import 'features/authentication/providers/auth_provider.dart';
import 'shared/providers/cart_provider.dart';
import 'shared/providers/product_provider.dart';
import 'shared/providers/order_provider.dart';
import 'shared/providers/notification_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (AppConstants.supabaseUrl.startsWith('http')) {
      await SupabaseService.initialize();
    }
  } catch (e) {
    debugPrint('Supabase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AuthProvider _authProvider;
  late final GoRouter _router;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider();
    _router = createRouter(_authProvider);
    _listenForDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    _authProvider.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingDeepLink();
    }
  }

  Future<void> _listenForDeepLinks() async {
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleDeepLink(uri);
    }, onError: (Object error) {
      debugPrint('Deep link error: $error');
    });

    await _checkPendingDeepLink();
  }

  Future<void> _checkPendingDeepLink() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      debugPrint('Failed to read initial deep link: $e');
    }
  }

  void _handleDeepLink(Uri uri) {
    final isSuccess = uri.scheme == 'oceancart' && (uri.host == 'payment-success' || uri.path == '/payment-success');
    final isFailure = uri.scheme == 'oceancart' && (uri.host == 'payment-failed' || uri.path == '/payment-failed');
    final isReturnPath = isSuccess || isFailure;

    if (!isReturnPath) {
      return;
    }

    final orderId = uri.queryParameters['order_id'] ?? uri.queryParameters['orderId'] ?? uri.queryParameters['id'];
    if (orderId == null || orderId.trim().isEmpty) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _router.go('/customer/payment/$orderId');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<CartProvider>(create: (_) => CartProvider()),
        ChangeNotifierProvider<ProductProvider>(create: (_) => ProductProvider()),
        ChangeNotifierProvider<OrderProvider>(create: (_) => OrderProvider()),
        ChangeNotifierProvider<NotificationProvider>(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
