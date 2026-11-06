import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/providers/order_provider.dart';
import '../../../models/order.dart';
import '../../authentication/providers/auth_provider.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  String _selectedFilter = 'all';

  final List<Map<String, String>> _statusFilters = const [
    {'id': 'all', 'label': 'All'},
    {'id': AppConstants.statusPendingConfirmation, 'label': 'Pending'},
    {'id': AppConstants.statusProcessing, 'label': 'Processing'},
    {'id': AppConstants.statusAssignedToRider, 'label': 'Assigned'},
    {'id': AppConstants.statusOutForDelivery, 'label': 'Out for Delivery'},
    {'id': AppConstants.statusDelivered, 'label': 'Delivered'},
    {'id': AppConstants.statusCancelled, 'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadAdminOrders();
    });
  }

  List<Order> _getFilteredOrders(List<Order> orders) {
    if (_selectedFilter == 'all') return orders;
    return orders.where((o) => o.orderStatus == _selectedFilter).toList();
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
      case AppConstants.statusPendingConfirmation:
      case AppConstants.statusPendingPayment:
        return AppColors.warning;
      case AppConstants.statusCancelled:
      case AppConstants.statusPaymentFailed:
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  void _showOrderDetails(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminOrderDetailSheet(order: order),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final filteredOrders = _getFilteredOrders(orderProvider.adminOrders);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.white),
            onPressed: () => context.read<OrderProvider>().loadAdminOrders(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter horizontal list
          Container(
            height: 52,
            color: AppColors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _statusFilters.length,
              itemBuilder: (ctx, idx) {
                final filter = _statusFilters[idx];
                final isSelected = _selectedFilter == filter['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter['label']!,
                      style: TextStyle(
                        color: isSelected ? AppColors.white : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.greyLight,
                    onSelected: (_) {
                      setState(() => _selectedFilter = filter['id']!);
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: orderProvider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No orders found',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => context.read<OrderProvider>().loadAdminOrders(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filteredOrders.length,
                          itemBuilder: (ctx, i) {
                            final order = filteredOrders[i];
                            final statusColor = _getStatusColor(order.orderStatus);
                            final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(order.createdAt);

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: InkWell(
                                onTap: () => _showOrderDetails(order),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            order.orderNumber,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formattedDate,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                      const Divider(height: 18),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                order.customerName ?? 'Customer',
                                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${order.items.length} item(s)',
                                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '₱${order.totalAmount.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
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
          ),
        ],
      ),
    );
  }
}

class _AdminOrderDetailSheet extends StatefulWidget {
  final Order order;
  const _AdminOrderDetailSheet({required this.order});

  @override
  State<_AdminOrderDetailSheet> createState() => _AdminOrderDetailSheetState();
}

class _AdminOrderDetailSheetState extends State<_AdminOrderDetailSheet> {
  bool _updating = false;
  List<Map<String, dynamic>> _riders = [];
  bool _loadingRiders = true;

  @override
  void initState() {
    super.initState();
    _fetchRiders();
  }

  Future<void> _fetchRiders() async {
    try {
      final res = await SupabaseService.adminClient
          .from('profiles')
          .select('id, full_name, phone, is_active')
          .eq('role', AppConstants.roleRider);
      if (mounted) {
        setState(() {
          _riders = List<Map<String, dynamic>>.from(res as List);
          _loadingRiders = false;
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
            _riders = List<Map<String, dynamic>>.from(res as List);
            _loadingRiders = false;
          });
          return;
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _loadingRiders = false);
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updating = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OrderProvider>();

    final success = await provider.updateOrderStatus(widget.order.id, status);
    if (!mounted) return;
    setState(() => _updating = false);
    if (success) {
      await provider.loadAdminOrders();
      nav.pop();
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
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<OrderProvider>();
    final adminId = context.read<AuthProvider>().userProfile?.id;

    final success = await provider.assignRiderToOrder(
      orderId: widget.order.id,
      riderId: riderId,
      adminId: adminId,
    );

    if (!mounted) return;
    setState(() => _updating = false);
    if (success) {
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Rider assigned successfully!'), backgroundColor: AppColors.success),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to assign rider'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.orderNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('Customer: ${order.customerName ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Phone: ${order.customerPhone}', style: const TextStyle(color: AppColors.textSecondary)),
            Text('Address: ${order.deliveryAddress}', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${item.productName} x${item.quantity}', style: const TextStyle(fontSize: 13)),
                      Text('₱${item.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                )),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('₱${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Update Status', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Processing'),
                  onPressed: _updating ? null : () => _updateStatus(AppConstants.statusProcessing),
                ),
                ActionChip(
                  label: const Text('Delivered'),
                  onPressed: _updating ? null : () => _updateStatus(AppConstants.statusDelivered),
                ),
                ActionChip(
                  label: const Text('Cancel Order'),
                  onPressed: _updating ? null : () => _updateStatus(AppConstants.statusCancelled),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Assign Delivery Rider', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_loadingRiders)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else if (_riders.isEmpty)
              const Text('No registered riders found.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
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
                onChanged: _updating ? null : (riderId) {
                  if (riderId != null) _assignRider(riderId);
                },
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
