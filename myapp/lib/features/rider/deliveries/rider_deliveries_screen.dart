import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/order_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';

class RiderDeliveriesScreen extends StatefulWidget {
  const RiderDeliveriesScreen({super.key});

  @override
  State<RiderDeliveriesScreen> createState() => _RiderDeliveriesScreenState();
}

class _RiderDeliveriesScreenState extends State<RiderDeliveriesScreen> {
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

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.riderOrders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Deliveries'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.two_wheeler_outlined, size: 64, color: AppColors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'No deliveries assigned to you yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (ctx, i) {
                      final order = orders[i];
                      final isCompleted = order.orderStatus == AppConstants.statusDelivered;
                      final isCancelled = order.orderStatus == AppConstants.statusCancelled;
                      final color = isCompleted
                          ? AppColors.success
                          : (isCancelled ? AppColors.error : AppColors.primary);

                      return InkWell(
                        onTap: () => context.push('/rider/delivery/${order.id}'),
                        borderRadius: BorderRadius.circular(12),
                        child: Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                              const Divider(height: 16),
                              Text('Customer: ${order.customerName ?? 'Customer'}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text('Address: ${order.deliveryAddress}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('${order.items.length} items',
                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text(
                                    '₱${order.totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                    },
                  ),
                ),
    );
  }
}
