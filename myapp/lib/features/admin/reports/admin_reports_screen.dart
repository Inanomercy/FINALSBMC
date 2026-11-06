import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/order_provider.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _loading = true);
    final stats = await context.read<OrderProvider>().getDashboardStats();
    if (mounted) {
      setState(() {
        _stats = stats;
        _loading = false;
      });
    }
  }

  Widget _buildReportCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final revenue = (_stats['totalRevenue'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = _stats['totalOrders'] ?? 0;
    final pendingOrders = _stats['pendingOrders'] ?? 0;
    final processingOrders = _stats['processingOrders'] ?? 0;
    final activeDeliveries = _stats['activeDeliveries'] ?? 0;
    final completedDeliveries = _stats['completedDeliveries'] ?? 0;
    final customers = _stats['customers'] ?? 0;
    final riders = _stats['riders'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Revenue & Financials', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildReportCard(
                    title: 'Total Revenue',
                    value: '₱${revenue.toStringAsFixed(2)}',
                    icon: Icons.payments_outlined,
                    color: AppColors.success,
                    subtitle: 'From completed orders',
                  ),
                  _buildReportCard(
                    title: 'Total Orders Placed',
                    value: '$totalOrders',
                    icon: Icons.shopping_bag_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text('Order Pipeline Status', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildReportCard(
                    title: 'Pending Confirmation',
                    value: '$pendingOrders',
                    icon: Icons.hourglass_top,
                    color: AppColors.warning,
                  ),
                  _buildReportCard(
                    title: 'Processing in Kitchen/Packing',
                    value: '$processingOrders',
                    icon: Icons.kitchen,
                    color: AppColors.accent,
                  ),
                  _buildReportCard(
                    title: 'Active Deliveries on the Road',
                    value: '$activeDeliveries',
                    icon: Icons.delivery_dining,
                    color: AppColors.secondary,
                  ),
                  _buildReportCard(
                    title: 'Delivered Successfully',
                    value: '$completedDeliveries',
                    icon: Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  Text('User Base', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildReportCard(
                    title: 'Registered Customers',
                    value: '$customers',
                    icon: Icons.people_outline,
                    color: AppColors.primary,
                  ),
                  _buildReportCard(
                    title: 'Active Delivery Riders',
                    value: '$riders',
                    icon: Icons.two_wheeler,
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),
    );
  }
}
