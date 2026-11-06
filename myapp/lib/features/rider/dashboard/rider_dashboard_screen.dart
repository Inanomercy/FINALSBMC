import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/order_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import '../../../models/order.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    final riderId = context.read<AuthProvider>().userProfile?.id;
    if (riderId != null) {
      await context.read<OrderProvider>().loadRiderOrders(riderId);
    }
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<OrderProvider>().updateDeliveryStatus(orderId, newStatus);
    if (!mounted) return;
    if (ok) {
      _loadOrders();
      messenger.showSnackBar(
        SnackBar(content: Text('Status updated to ${newStatus.replaceAll('_', ' ')}'), backgroundColor: AppColors.success),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to update status'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final activeOrders = orderProvider.riderOrders
        .where((o) => o.orderStatus != AppConstants.statusDelivered && o.orderStatus != AppConstants.statusCancelled)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rider Dashboard', style: TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Welcome, ${auth.userProfile?.fullName ?? 'Rider'}',
                style: const TextStyle(color: AppColors.white, fontSize: 12)),
          ],
        ),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          Row(
            children: [
              Text(_isOnline ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                      color: _isOnline ? AppColors.success : AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
              Switch(
                value: _isOnline,
                activeThumbColor: AppColors.success,
                onChanged: (v) => setState(() => _isOnline = v),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadOrders,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Status card
                  Card(
                    elevation: 0,
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
                              color: (_isOnline ? AppColors.success : AppColors.grey).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isOnline ? Icons.two_wheeler : Icons.do_not_disturb_on,
                              color: _isOnline ? AppColors.success : AppColors.grey,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isOnline ? 'You are Online & Ready' : 'You are Offline',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isOnline ? 'Ready to accept incoming delivery jobs' : 'Go online to receive jobs',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Active Deliveries', style: Theme.of(context).textTheme.titleMedium),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('${activeOrders.length}',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (activeOrders.isEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.inventory_outlined, size: 48, color: AppColors.grey),
                            SizedBox(height: 8),
                            Text('No active deliveries right now',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...activeOrders.map((order) => _buildRiderOrderCard(order)),
                ],
              ),
            ),
    );
  }

  Widget _buildRiderOrderCard(Order order) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${order.customerName ?? 'Customer'} • ${order.customerPhone}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, color: AppColors.success, size: 20),
                  onPressed: () => _callCustomer(order.customerPhone),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    order.deliveryAddress,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${order.items.length} item(s) • Total: ₱${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            // Status action buttons
            if (order.orderStatus == AppConstants.statusAssignedToRider) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Accept Delivery'),
                      onPressed: () => _updateStatus(order.id, AppConstants.statusRiderAccepted),
                    ),
                  ),
                ],
              ),
            ] else if (order.orderStatus == AppConstants.statusRiderAccepted) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                      ),
                      icon: const Icon(Icons.storefront, size: 18),
                      label: const Text('Picked Up from Store'),
                      onPressed: () => _updateStatus(order.id, AppConstants.statusPickedUp),
                    ),
                  ),
                ],
              ),
            ] else if (order.orderStatus == AppConstants.statusPickedUp) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: AppColors.white,
                      ),
                      icon: const Icon(Icons.motorcycle, size: 18),
                      label: const Text('Start Delivering'),
                      onPressed: () => _updateStatus(order.id, AppConstants.statusOutForDelivery),
                    ),
                  ),
                ],
              ),
            ] else if (order.orderStatus == AppConstants.statusOutForDelivery) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.white,
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Complete & Delivered'),
                      onPressed: () => _updateStatus(order.id, AppConstants.statusDelivered),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
