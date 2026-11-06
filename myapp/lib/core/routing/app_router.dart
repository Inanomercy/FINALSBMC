import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/authentication/screens/splash_screen.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/register_screen.dart';
import '../../features/authentication/screens/forgot_password_screen.dart';
import '../../features/authentication/providers/auth_provider.dart';

// Customer screens
import '../../features/customer/home/customer_shell.dart';
import '../../features/customer/home/home_screen.dart';
import '../../features/customer/categories/categories_screen.dart';
import '../../features/customer/cart/cart_screen.dart';
import '../../features/customer/orders/orders_screen.dart';
import '../../features/customer/profile/profile_screen.dart';
import '../../features/customer/products/product_detail_screen.dart';
import '../../features/customer/checkout/checkout_screen.dart';
import '../../features/customer/orders/order_detail_screen.dart';
import '../../features/payments/screens/payment_status_screen.dart';

// Admin screens
import '../../features/admin/dashboard/admin_shell.dart';
import '../../features/admin/dashboard/admin_dashboard_screen.dart';
import '../../features/admin/products/admin_products_screen.dart';
import '../../features/admin/categories/admin_categories_screen.dart';
import '../../features/admin/orders/admin_orders_screen.dart';
import '../../features/admin/orders/admin_order_detail_screen.dart';
import '../../features/admin/riders/admin_riders_screen.dart';
import '../../features/admin/reports/admin_reports_screen.dart';

// Rider screens
import '../../features/rider/dashboard/rider_shell.dart';
import '../../features/rider/dashboard/rider_dashboard_screen.dart';
import '../../features/rider/deliveries/rider_deliveries_screen.dart';
import '../../features/rider/deliveries/rider_delivery_detail_screen.dart';
import '../../features/rider/history/rider_history_screen.dart';
import '../../features/rider/profile/rider_profile_screen.dart';

import '../../core/constants/app_constants.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _customerShellKey = GlobalKey<NavigatorState>();
final _adminShellKey = GlobalKey<NavigatorState>();
final _riderShellKey = GlobalKey<NavigatorState>();

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: authProvider,
    redirect: (context, state) {
      final isAuth = authProvider.isAuthenticated;
      final isInit = !authProvider.isInitialized;
      final location = state.matchedLocation;

      // 1. Still initializing -> stay on or go to splash screen
      if (isInit) {
        return location == '/splash' ? null : '/splash';
      }

      // 2. Initialization complete and user is on splash screen -> redirect away immediately
      if (location == '/splash') {
        if (!isAuth) return '/login';
        final role = authProvider.userProfile?.role;
        if (role == AppConstants.roleAdmin) return '/admin';
        if (role == AppConstants.roleRider) return '/rider';
        return '/customer';
      }

      // 3. User is NOT authenticated
      final publicRoutes = ['/login', '/register', '/forgot-password'];
      if (!isAuth) {
        return publicRoutes.contains(location) ? null : '/login';
      }

      // 4. User IS authenticated, but trying to access public auth screens
      if (publicRoutes.contains(location)) {
        final role = authProvider.userProfile?.role;
        if (role == AppConstants.roleAdmin) return '/admin';
        if (role == AppConstants.roleRider) return '/rider';
        return '/customer';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

      // Customer Shell (Bottom Navigation)
      ShellRoute(
        navigatorKey: _customerShellKey,
        builder: (context, state, child) => CustomerShell(child: child),
        routes: [
          GoRoute(path: '/customer', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/customer/categories', builder: (_, __) => const CategoriesScreen()),
          GoRoute(path: '/customer/cart', builder: (_, __) => const CartScreen()),
          GoRoute(path: '/customer/orders', builder: (_, __) => const OrdersScreen()),
          GoRoute(path: '/customer/profile', builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // Customer Full-Screen Pushed Routes (covers bottom bar with back button)
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/product/:id',
        builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/checkout',
        builder: (_, __) => const CheckoutScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/order/:id',
        builder: (_, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/customer/payment/:orderId',
        builder: (_, state) => PaymentStatusScreen(orderId: state.pathParameters['orderId']!),
      ),

      // Admin Shell
      ShellRoute(
        navigatorKey: _adminShellKey,
        builder: (context, state, child) => AdminShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),
          GoRoute(path: '/admin/products', builder: (_, __) => const AdminProductsScreen()),
          GoRoute(path: '/admin/categories', builder: (_, __) => const AdminCategoriesScreen()),
          GoRoute(path: '/admin/orders', builder: (_, __) => const AdminOrdersScreen()),
          GoRoute(path: '/admin/riders', builder: (_, __) => const AdminRidersScreen()),
          GoRoute(path: '/admin/reports', builder: (_, __) => const AdminReportsScreen()),
        ],
      ),

      // Admin Full-Screen Pushed Routes
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/admin/orders/:id',
        builder: (_, state) => AdminOrderDetailScreen(orderId: state.pathParameters['id']!),
      ),

      // Rider Shell
      ShellRoute(
        navigatorKey: _riderShellKey,
        builder: (context, state, child) => RiderShell(child: child),
        routes: [
          GoRoute(path: '/rider', builder: (_, __) => const RiderDashboardScreen()),
          GoRoute(path: '/rider/deliveries', builder: (_, __) => const RiderDeliveriesScreen()),
          GoRoute(path: '/rider/history', builder: (_, __) => const RiderHistoryScreen()),
          GoRoute(path: '/rider/profile', builder: (_, __) => const RiderProfileScreen()),
        ],
      ),

      // Rider Full-Screen Pushed Routes
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/rider/delivery/:id',
        builder: (_, state) => RiderDeliveryDetailScreen(orderId: state.pathParameters['id']!),
      ),
    ],
  );
}
