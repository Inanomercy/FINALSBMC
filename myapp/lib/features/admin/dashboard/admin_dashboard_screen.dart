import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/order_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final stats = await context.read<OrderProvider>().getDashboardStats();
    setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin Dashboard', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Welcome, ${auth.userProfile?.fullName.split(' ').first ?? 'Admin'}!',
              style: const TextStyle(color: AppColors.white, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            tooltip: 'Refresh Stats',
            onPressed: _loadStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.white),
            tooltip: 'Sign Out',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Overview', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    // Stats Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _statCard('Products', '${_stats['products'] ?? 0}', Icons.inventory_2, AppColors.primary),
                        _statCard('Customers', '${_stats['customers'] ?? 0}', Icons.people, AppColors.secondary),
                        _statCard('Riders', '${_stats['riders'] ?? 0}', Icons.delivery_dining, AppColors.accent),
                        _statCard('Total Orders', '${_stats['totalOrders'] ?? 0}', Icons.receipt_long, Colors.purple),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Order Status', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.5,
                      children: [
                        _statCard('Pending', '${_stats['pendingOrders'] ?? 0}', Icons.pending_outlined, AppColors.warning),
                        _statCard('Processing', '${_stats['processingOrders'] ?? 0}', Icons.sync, AppColors.primary),
                        _statCard('Active Del.', '${_stats['activeDeliveries'] ?? 0}', Icons.local_shipping, AppColors.accent),
                        _statCard('Delivered', '${_stats['completedDeliveries'] ?? 0}', Icons.check_circle_outline, AppColors.success),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Revenue Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on, color: AppColors.white, size: 40),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Revenue', style: TextStyle(color: AppColors.white, fontSize: 13)),
                              Text(
                                '₱${NumberFormat('#,##0.00').format(_stats['totalRevenue'] ?? 0)}',
                                style: const TextStyle(color: AppColors.white, fontSize: 24, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Session & Sign Out Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Admin Session', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Signed in as ${auth.userProfile?.email ?? 'System Administrator'}',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          PrimaryButton(
                            label: 'Sign Out / Exit Admin',
                            color: AppColors.error,
                            icon: Icons.logout,
                            onPressed: () => _confirmSignOut(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out and exit Admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }
}
