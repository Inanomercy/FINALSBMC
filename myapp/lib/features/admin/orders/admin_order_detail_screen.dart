import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/order.dart';
import '../../../shared/providers/order_provider.dart';
import '../../authentication/providers/auth_provider.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  bool _updating = false;
  List<Map<String, dynamic>> _riders = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final o = await context.read<OrderProvider>().getOrderById(widget.orderId);
    try {
      final res = await SupabaseService.adminClient
          .from('profiles')
          .select('id, full_name, phone, is_active')
          .eq('role', AppConstants.roleRider);
      if (mounted) {
        setState(() {
          _order = o;
          _riders = List<Map<String, dynamic>>.from(res as List);
          _loading = false;
        });
        return;
      }
    } catch (_) {
      try {
        final res = await SupabaseService.client
            .from('profiles')
            .select('id, full_name, phone, is_active')
            .eq('role', AppConstants.roleRider);
        if (mounted) {
          setState(() {
            _order = o;
            _riders = List<Map<String, dynamic>>.from(res as List);
            _loading = false;
          });
          return;
        }
      } catch (_) {}
      if (mounted) {
        setState(() {
          _order = o;
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    final messenger = ScaffoldMessenger.of(context);
    final success = await context.read<OrderProvider>().updateOrderStatus(widget.orderId, status);
    if (!mounted) return;
    setState(() => _updating = false);
    if (success) {
      _loadData();
      messenger.showSnackBar(
        SnackBar(content: Text('Order status updated to $status'), backgroundColor: AppColors.success),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to update status'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _assignRider(String riderId) async {
    setState(() => _updating = true);
    final messenger = ScaffoldMessenger.of(context);
    final adminId = context.read<AuthProvider>().userProfile?.id;
    final success = await context.read<OrderProvider>().assignRiderToOrder(
      orderId: widget.orderId,
      riderId: riderId,
      adminId: adminId,
    );

    if (!mounted) return;
    setState(() => _updating = false);
    if (success) {
      _loadData();
      messenger.showSnackBar(
        const SnackBar(content: Text('Rider assigned successfully!'), backgroundColor: AppColors.success),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to assign rider'), backgroundColor: AppColors.error),
      );
    }
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Order #${order.orderNumber}'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Summary Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(order.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt),
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Order Status:'),
                        Text(order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Status:'),
                        Text(order.paymentStatus.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: order.paymentStatus == AppConstants.paymentPaid ? AppColors.success : AppColors.warning,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Customer Info Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Customer Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Text('Name: ${order.customerName ?? 'N/A'}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Phone: ${order.customerPhone}', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Address: ${order.deliveryAddress}', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Items List Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Items (${order.items.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...order.items.map((i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${i.productName} x${i.quantity}', style: const TextStyle(fontSize: 13)),
                              Text('₱${i.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        )),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text('₱${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Assign Rider
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Delivery Rider', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_riders.isEmpty)
                      const Text('No riders registered.', style: TextStyle(color: AppColors.textSecondary))
                    else
                      DropdownButtonFormField<String>(
                        initialValue: order.riderId,
                        hint: const Text('Select Rider'),
                        items: _riders.map((r) {
                          return DropdownMenuItem<String>(
                            value: r['id'] as String,
                            child: Text('${r['full_name']} (${r['phone'] ?? 'No phone'})'),
                          );
                        }).toList(),
                        onChanged: _updating ? null : (id) {
                          if (id != null) _assignRider(id);
                        },
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status Update Buttons
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Change Order Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Set Processing'),
                          onPressed: _updating ? null : () => _updateStatus(AppConstants.statusProcessing),
                        ),
                        ActionChip(
                          label: const Text('Set Delivered'),
                          onPressed: _updating ? null : () => _updateStatus(AppConstants.statusDelivered),
                        ),
                        ActionChip(
                          label: const Text('Cancel Order'),
                          onPressed: _updating ? null : () => _updateStatus(AppConstants.statusCancelled),
                        ),
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
    );
  }
}
