import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/order_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';

class RiderHistoryScreen extends StatefulWidget {
  const RiderHistoryScreen({super.key});

  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final riderId = context.read<AuthProvider>().userProfile?.id;
    if (riderId != null) {
      await context.read<OrderProvider>().loadRiderOrders(riderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final deliveredOrders = orderProvider.riderOrders
        .where((o) => o.orderStatus == AppConstants.statusDelivered)
        .toList();

    final totalEarnings = deliveredOrders.length * AppConstants.deliveryFee;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Delivery History'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.monetization_on_outlined, color: AppColors.success, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Estimated Delivery Earnings', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('₱${totalEarnings.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                              Text('${deliveredOrders.length} completed deliveries',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Completed Deliveries', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (deliveredOrders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('No completed deliveries yet.', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    )
                  else
                    ...deliveredOrders.map((order) {
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: ListTile(
                          title: Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.deliveryAddress, style: const TextStyle(fontSize: 12)),
                              Text(
                                DateFormat('MMM dd, yyyy • hh:mm a').format(order.deliveredAt ?? order.updatedAt),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          trailing: const Text(
                            '+₱50.00',
                            style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
