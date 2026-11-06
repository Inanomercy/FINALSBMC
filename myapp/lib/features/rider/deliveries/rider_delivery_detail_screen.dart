import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/order.dart';
import '../../../shared/providers/order_provider.dart';

class RiderDeliveryDetailScreen extends StatefulWidget {
  final String orderId;
  const RiderDeliveryDetailScreen({super.key, required this.orderId});

  @override
  State<RiderDeliveryDetailScreen> createState() => _RiderDeliveryDetailScreenState();
}

class _RiderDeliveryDetailScreenState extends State<RiderDeliveryDetailScreen> {
  Order? _order;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _loading = true);
    final o = await context.read<OrderProvider>().getOrderById(widget.orderId);
    if (mounted) {
      setState(() {
        _order = o;
        _loading = false;
      });
    }
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMap(String address) async {
    final query = Uri.encodeComponent(address);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    final messenger = ScaffoldMessenger.of(context);
    final success = await context.read<OrderProvider>().updateDeliveryStatus(widget.orderId, status);
    if (!mounted) return;
    setState(() => _updating = false);
    if (success) {
      _loadOrder();
      messenger.showSnackBar(
        SnackBar(content: Text('Delivery marked as ${status.replaceAll('_', ' ')}!'), backgroundColor: AppColors.success),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to update status'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Delivery Details'), backgroundColor: AppColors.primary),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Delivery Details'), backgroundColor: AppColors.primary),
        body: const Center(child: Text('Delivery not found.')),
      );
    }

    final order = _order!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(order.orderNumber),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrder),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Current Status', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('MMM dd • hh:mm a').format(order.createdAt),
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Contact & Address Card
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
                    const Text('Customer & Destination', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.person, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(order.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(order.customerPhone, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: AppColors.success.withValues(alpha: 0.1)),
                          icon: const Icon(Icons.phone, color: AppColors.success),
                          onPressed: () => _callCustomer(order.customerPhone),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.error, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(order.deliveryAddress, style: const TextStyle(fontSize: 13, height: 1.4)),
                        ),
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: AppColors.primary.withValues(alpha: 0.1)),
                          icon: const Icon(Icons.map_outlined, color: AppColors.primary),
                          tooltip: 'Open in Maps',
                          onPressed: () => _openMap(order.deliveryAddress),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Package Items Card
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
                    Text('Package Contents (${order.items.length} items)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ...order.items.map((item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.productName} x${item.quantity}', style: const TextStyle(fontSize: 13)),
                              Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Collect on Delivery / Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('₱${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Status Progression Buttons
            if (order.orderStatus == AppConstants.statusAssignedToRider) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Accept Delivery Job', style: TextStyle(fontSize: 16)),
                  onPressed: _updating ? null : () => _updateStatus(AppConstants.statusRiderAccepted),
                ),
              ),
            ] else if (order.orderStatus == AppConstants.statusRiderAccepted) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.storefront),
                  label: const Text('Confirm Picked Up from Store', style: TextStyle(fontSize: 16)),
                  onPressed: _updating ? null : () => _updateStatus(AppConstants.statusPickedUp),
                ),
              ),
            ] else if (order.orderStatus == AppConstants.statusPickedUp) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.motorcycle),
                  label: const Text('Start Delivery (Out for Delivery)', style: TextStyle(fontSize: 16)),
                  onPressed: _updating ? null : () => _updateStatus(AppConstants.statusOutForDelivery),
                ),
              ),
            ] else if (order.orderStatus == AppConstants.statusOutForDelivery) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Mark as Delivered to Customer', style: TextStyle(fontSize: 16)),
                  onPressed: _updating ? null : () => _updateStatus(AppConstants.statusDelivered),
                ),
              ),
            ] else if (order.orderStatus == AppConstants.statusDelivered) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.success),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: AppColors.success),
                    SizedBox(width: 8),
                    Text('Delivery Completed Successfully',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
