import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/order.dart';
import '../../../models/rider_assignment.dart';
import '../../../shared/providers/order_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  List<OrderStatusHistory> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    setState(() => _loading = true);
    final orderProvider = context.read<OrderProvider>();
    final order = await orderProvider.getOrderById(widget.orderId);
    final history = await orderProvider.getOrderHistory(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _history = history;
        _loading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case AppConstants.statusDelivered:
        return AppColors.success;
      case AppConstants.statusProcessing:
      case AppConstants.statusAssignedToRider:
      case AppConstants.statusRiderAccepted:
      case AppConstants.statusPickedUp:
      case AppConstants.statusOutForDelivery:
        return AppColors.primary;
      case AppConstants.statusPendingPayment:
      case AppConstants.statusPendingConfirmation:
        return AppColors.warning;
      case AppConstants.statusCancelled:
      case AppConstants.statusPaymentFailed:
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  Future<void> _callRider(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool isCurrent,
    bool isLast = false,
  }) {
    final color = isCurrent
        ? AppColors.primary
        : (isCompleted ? AppColors.success : AppColors.grey.withValues(alpha: 0.5));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted || isCurrent ? color : AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 14, color: AppColors.white)
                  : isCurrent
                      ? const Center(
                          child: SizedBox(
                            width: 8,
                            height: 8,
                            child: DecoratedBox(decoration: BoxDecoration(color: AppColors.white, shape: BoxShape.circle)),
                          ),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                color: isCompleted ? AppColors.success : AppColors.grey.withValues(alpha: 0.3),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Order Details'), backgroundColor: AppColors.primary),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Order Details'), backgroundColor: AppColors.primary),
        body: const Center(child: Text('Order not found.')),
      );
    }

    final order = _order!;
    final statusColor = _getStatusColor(order.orderStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(order.orderNumber),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrderData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrderData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Payment Status', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (order.paymentStatus == AppConstants.paymentPaid ? AppColors.success : AppColors.warning)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.paymentStatus.toUpperCase(),
                              style: TextStyle(
                                color: order.paymentStatus == AppConstants.paymentPaid ? AppColors.success : AppColors.warning,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Assigned Rider Card (if assigned)
              if (order.riderName != null) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          radius: 24,
                          child: const Icon(Icons.two_wheeler, color: AppColors.primary),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Assigned Rider', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              Text(order.riderName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: AppColors.success.withValues(alpha: 0.1)),
                          icon: const Icon(Icons.phone, color: AppColors.success),
                          onPressed: () => _callRider(''),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Order Tracking Timeline Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildTimelineItem(
                        title: 'Order Placed',
                        subtitle: DateFormat('hh:mm a, MMM dd').format(order.createdAt),
                        isCompleted: true,
                        isCurrent: order.orderStatus == AppConstants.statusPendingConfirmation,
                      ),
                      _buildTimelineItem(
                        title: 'Order Processing',
                        subtitle: 'Packing seafood with fresh ice packs',
                        isCompleted: [
                          AppConstants.statusProcessing,
                          AppConstants.statusAssignedToRider,
                          AppConstants.statusRiderAccepted,
                          AppConstants.statusPickedUp,
                          AppConstants.statusOutForDelivery,
                          AppConstants.statusDelivered,
                        ].contains(order.orderStatus),
                        isCurrent: order.orderStatus == AppConstants.statusProcessing,
                      ),
                      _buildTimelineItem(
                        title: 'Rider Assigned & Picked Up',
                        subtitle: order.riderName != null ? 'Assigned to ${order.riderName}' : 'Waiting for rider assignment',
                        isCompleted: [
                          AppConstants.statusRiderAccepted,
                          AppConstants.statusPickedUp,
                          AppConstants.statusOutForDelivery,
                          AppConstants.statusDelivered,
                        ].contains(order.orderStatus),
                        isCurrent: [AppConstants.statusAssignedToRider, AppConstants.statusRiderAccepted, AppConstants.statusPickedUp].contains(order.orderStatus),
                      ),
                      _buildTimelineItem(
                        title: 'Out for Delivery',
                        subtitle: 'Rider is on the way to your address',
                        isCompleted: [AppConstants.statusOutForDelivery, AppConstants.statusDelivered].contains(order.orderStatus),
                        isCurrent: order.orderStatus == AppConstants.statusOutForDelivery,
                      ),
                      _buildTimelineItem(
                        title: 'Delivered',
                        subtitle: order.deliveredAt != null
                            ? 'Delivered at ${DateFormat('hh:mm a, MMM dd').format(order.deliveredAt!)}'
                            : 'Package delivered to recipient',
                        isCompleted: order.orderStatus == AppConstants.statusDelivered,
                        isCurrent: order.orderStatus == AppConstants.statusDelivered,
                        isLast: true,
                      ),
                      if (_history.isNotEmpty) ...[
                        const Divider(height: 24),
                        const Text('Activity Timeline Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ..._history.map((h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.circle, size: 6, color: AppColors.primary),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${h.status.replaceAll('_', ' ').toUpperCase()}${h.notes != null ? ' (${h.notes})' : ''}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                DateFormat('hh:mm a, MMM dd').format(h.createdAt),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order Items (${order.items.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...order.items.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      Text('₱${item.productPrice.toStringAsFixed(2)} x ${item.quantity}',
                                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          )),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text('₱${order.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Delivery Fee', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text('₱${order.deliveryFee.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            '₱${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Delivery Address Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Delivery Address', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              order.deliveryAddress,
                              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined, size: 20, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(order.customerPhone, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
