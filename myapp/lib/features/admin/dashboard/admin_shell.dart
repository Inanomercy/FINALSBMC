import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  int _calculateIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/admin/products')) return 1;
    if (location.startsWith('/admin/categories')) return 2;
    if (location.startsWith('/admin/orders')) return 3;
    if (location.startsWith('/admin/riders')) return 4;
    if (location.startsWith('/admin/reports')) return 5;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/admin');
        break;
      case 1:
        context.go('/admin/products');
        break;
      case 2:
        context.go('/admin/categories');
        break;
      case 3:
        context.go('/admin/orders');
        break;
      case 4:
        context.go('/admin/riders');
        break;
      case 5:
        context.go('/admin/reports');
        break;
    }
  }

  static const List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard, 'label': 'Dashboard'},
    {'icon': Icons.inventory_2_outlined, 'activeIcon': Icons.inventory_2, 'label': 'Products'},
    {'icon': Icons.category_outlined, 'activeIcon': Icons.category, 'label': 'Categories'},
    {'icon': Icons.receipt_long_outlined, 'activeIcon': Icons.receipt_long, 'label': 'Orders'},
    {'icon': Icons.delivery_dining_outlined, 'activeIcon': Icons.delivery_dining, 'label': 'Riders'},
    {'icon': Icons.bar_chart_outlined, 'activeIcon': Icons.bar_chart, 'label': 'Reports'},
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => _onItemTapped(i, context),
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.grey,
          backgroundColor: AppColors.white,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Icon(item['icon'] as IconData),
            activeIcon: Icon(item['activeIcon'] as IconData),
            label: item['label'] as String,
          )).toList(),
        ),
      ),
    );
  }
}
