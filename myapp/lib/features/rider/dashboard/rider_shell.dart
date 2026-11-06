import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class RiderShell extends StatelessWidget {
  final Widget child;
  const RiderShell({super.key, required this.child});

  int _calculateIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/rider/deliveries')) return 1;
    if (location.startsWith('/rider/history')) return 2;
    if (location.startsWith('/rider/profile')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/rider');
        break;
      case 1:
        context.go('/rider/deliveries');
        break;
      case 2:
        context.go('/rider/history');
        break;
      case 3:
        context.go('/rider/profile');
        break;
    }
  }

  static const List<Map<String, dynamic>> _navItems = [
    {'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard, 'label': 'Dashboard'},
    {'icon': Icons.delivery_dining_outlined, 'activeIcon': Icons.delivery_dining, 'label': 'Deliveries'},
    {'icon': Icons.history_outlined, 'activeIcon': Icons.history, 'label': 'History'},
    {'icon': Icons.person_outline, 'activeIcon': Icons.person, 'label': 'Profile'},
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
          selectedFontSize: 11,
          unselectedFontSize: 11,
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
