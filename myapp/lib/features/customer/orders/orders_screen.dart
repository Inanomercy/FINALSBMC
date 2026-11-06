import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/order_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import '../../../models/order.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _refreshInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrders());
  }

  Future<void> _refreshOrders() async {
    if (_refreshInProgress || !mounted) return;
    _refreshInProgress = true;
    try {
      final customerId = context.read<AuthProvider>().userProfile?.id;
      if (customerId != null) {
        await context.read<OrderProvider>().loadCustomerOrders(customerId);
      }
    } finally {
      _refreshInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final orders = orderProvider.orders;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('My Orders'),
          backgroundColor: AppColors.primary,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
                onPressed: _refreshOrders,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh orders')
          ]),
      body: orderProvider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : orders.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 80, color: AppColors.grey),
                        const SizedBox(height: 16),
                        Text('No orders yet',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Text('Start shopping!',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 24),
                        ElevatedButton(
                            onPressed: () => context.go('/customer'),
                            child: const Text('Browse Products')),
                      ]),
                )
              : RefreshIndicator(
                  onRefresh: _refreshOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: orders.length,
                    itemBuilder: (_, i) => OrderCard(order: orders[i]),
                  ),
                ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final Order order;
  const OrderCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.orderStatus);
    final statusLabel = _statusLabel(order.orderStatus);

    return GestureDetector(
      onTap: () => context.push('/customer/order/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('#${order.orderNumber}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const Divider(height: 12),
            Row(
              children: [
                Text('${order.items.length} item(s)',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                Text('₱${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ],
            ),
            if (order.paymentStatus == 'paid') ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check_circle_outline,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 4),
                const Text('Payment paid',
                    style: TextStyle(color: AppColors.success, fontSize: 12)),
              ]),
            ],
            if (order.paymentStatus == 'pending') ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.info_outline,
                    size: 14, color: AppColors.warning),
                const SizedBox(width: 4),
                const Text('Payment pending',
                    style: TextStyle(color: AppColors.warning, fontSize: 12)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case AppConstants.statusDelivered:
        return AppColors.success;
      case AppConstants.statusCancelled:
        return AppColors.error;
      case AppConstants.statusPaymentFailed:
        return AppColors.error;
      case AppConstants.statusPendingPayment:
        return AppColors.warning;
      case AppConstants.statusOutForDelivery:
        return AppColors.accent;
      default:
        return AppColors.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case AppConstants.statusPendingPayment:
        return 'Pending Payment';
      case AppConstants.statusPendingConfirmation:
        return 'Pending Confirmation';
      case AppConstants.statusProcessing:
        return 'Processing';
      case AppConstants.statusAssignedToRider:
        return 'Assigned to Rider';
      case AppConstants.statusRiderAccepted:
        return 'Rider Accepted';
      case AppConstants.statusPickedUp:
        return 'Picked Up';
      case AppConstants.statusOutForDelivery:
        return 'Out for Delivery';
      case AppConstants.statusDelivered:
        return 'Delivered';
      case AppConstants.statusCancelled:
        return 'Cancelled';
      case AppConstants.statusPaymentFailed:
        return 'Payment Failed';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }
}
