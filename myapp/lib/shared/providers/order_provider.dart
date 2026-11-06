import 'package:flutter/foundation.dart';
import '../../core/services/supabase_service.dart';
import '../../core/constants/app_constants.dart';
import '../../models/order.dart';
import '../../models/cart_item.dart';
import '../../models/rider_assignment.dart';

class OrderProvider extends ChangeNotifier {
  SupabaseClient get _client => SupabaseService.client;
  SupabaseClient get _adminClient => SupabaseService.adminClient;

  List<Order> _orders = [];
  List<Order> _adminOrders = [];
  List<Order> _riderOrders = [];
  bool _loading = false;
  String? _error;
  RealtimeChannel? _customerOrdersSubscription;
  String? _subscribedCustomerId;

  List<Order> get orders => _orders;
  List<Order> get adminOrders => _adminOrders;
  List<Order> get riderOrders => _riderOrders;
  bool get isLoading => _loading;
  String? get error => _error;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  // CUSTOMER: Load own orders and listen for live database changes.
  Future<void> loadCustomerOrders(String customerId,
      {bool showLoading = true}) async {
    _subscribeToCustomerOrders(customerId);
    if (showLoading) _setLoading(true);
    try {
      final data = await _client
          .from('orders')
          .select(
              '*, order_items(*), rider:profiles!orders_rider_id_fkey(full_name, phone)')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);
      _orders = (data as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load orders.';
      notifyListeners();
    } finally {
      if (showLoading) _setLoading(false);
    }
  }

  void _subscribeToCustomerOrders(String customerId) {
    if (!SupabaseService.isInitialized) return;
    if (_subscribedCustomerId == customerId &&
        _customerOrdersSubscription != null) {
      return;
    }

    _customerOrdersSubscription?.unsubscribe();
    _subscribedCustomerId = customerId;
    try {
      _customerOrdersSubscription = _client
          .channel('customer-orders-$customerId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'customer_id',
              value: customerId,
            ),
            callback: (_) {
              loadCustomerOrders(customerId, showLoading: false);
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Customer orders realtime subscription failed: $e');
    }
  }

  // ADMIN: Load all orders
  Future<void> loadAdminOrders() async {
    _setLoading(true);
    try {
      final data = await _adminClient
          .from('orders')
          .select(
              '*, order_items(*), customer:profiles!orders_customer_id_fkey(full_name, email, phone), rider:profiles!orders_rider_id_fkey(full_name, phone)')
          .order('created_at', ascending: false);
      _adminOrders = (data as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('loadAdminOrders error: $e');
      _error = 'Failed to load orders.';
    } finally {
      _setLoading(false);
    }
  }

  // RIDER: Load assigned orders
  Future<void> loadRiderOrders(String riderId) async {
    _setLoading(true);
    try {
      final data = await _client
          .from('orders')
          .select(
              '*, order_items(*), customer:profiles!orders_customer_id_fkey(full_name, phone)')
          .eq('rider_id', riderId)
          .order('created_at', ascending: false);
      _riderOrders = (data as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _riderOrders = [];
    } finally {
      _setLoading(false);
    }
  }

  // Get single order
  Future<Order?> getOrderById(String orderId) async {
    try {
      final data = await _adminClient
          .from('orders')
          .select(
              '*, order_items(*), customer:profiles!orders_customer_id_fkey(full_name, email, phone), rider:profiles!orders_rider_id_fkey(full_name, phone)')
          .eq('id', orderId)
          .single();
      return Order.fromJson(data);
    } catch (_) {
      try {
        final data = await _client
            .from('orders')
            .select(
                '*, order_items(*), customer:profiles!orders_customer_id_fkey(full_name, email, phone), rider:profiles!orders_rider_id_fkey(full_name, phone)')
            .eq('id', orderId)
            .single();
        return Order.fromJson(data);
      } catch (_) {
        return null;
      }
    }
  }

  // Assign rider to order (Admin)
  Future<bool> assignRiderToOrder({
    required String orderId,
    required String riderId,
    String? adminId,
  }) async {
    final now = DateTime.now().toIso8601String();
    bool success = false;

    // 1. Prefer the server-side assign-rider Edge Function, which enforces auth and rider validation.
    try {
      final response = await _client.functions.invoke(
        'assign-rider',
        body: {
          'order_id': orderId,
          'rider_id': riderId,
        },
      );

      if (response.status == 200) {
        success = true;
      } else {
        debugPrint(
            'assign-rider function returned ${response.status}: ${response.data}');
      }
    } catch (e) {
      debugPrint('assign-rider function invoke failed: $e');
    }

    // 2. Fallback to the database RPC for environments where the function is unavailable.
    if (!success) {
      try {
        final res = await _client.rpc('assign_rider_to_order', params: {
          'p_order_id': orderId,
          'p_rider_id': riderId,
          'p_admin_id': adminId ?? '00000000-0000-0000-0000-000000000000',
        });
        if (res is Map && res['success'] == true) {
          success = true;
        }
      } catch (_) {}
    }

    // 3. Direct database updates as a final fallback when admin privileges are available.
    if (!success) {
      try {
        await _adminClient.from('orders').update({
          'rider_id': riderId,
          'order_status': AppConstants.statusAssignedToRider,
          'assigned_at': now,
          'updated_at': now,
        }).eq('id', orderId);

        await _adminClient.from('rider_assignments').insert({
          'order_id': orderId,
          'rider_id': riderId,
          'status': 'pending',
          'assigned_at': now,
        });

        await _adminClient.from('order_status_history').insert({
          'order_id': orderId,
          'status': AppConstants.statusAssignedToRider,
          'changed_by': adminId,
          'notes': 'Assigned to rider by admin',
          'created_at': now,
        });

        try {
          await _adminClient.from('notifications').insert({
            'user_id': riderId,
            'title': 'New Delivery Assigned 🛵',
            'message':
                'You have been assigned a new delivery order. Open your deliveries to accept.',
            'type': 'rider',
            'created_at': now,
          });
        } catch (_) {}

        success = true;
      } catch (e) {
        debugPrint('adminClient assign failed: $e, trying client...');
        try {
          await _client.from('orders').update({
            'rider_id': riderId,
            'order_status': AppConstants.statusAssignedToRider,
            'assigned_at': now,
            'updated_at': now,
          }).eq('id', orderId);

          await _client.from('rider_assignments').insert({
            'order_id': orderId,
            'rider_id': riderId,
            'status': 'pending',
            'assigned_at': now,
          });

          await _client.from('order_status_history').insert({
            'order_id': orderId,
            'status': AppConstants.statusAssignedToRider,
            'changed_by': adminId,
            'notes': 'Assigned to rider by admin',
            'created_at': now,
          });

          success = true;
        } catch (e2) {
          debugPrint('client assign error: $e2');
          _error = 'Failed to assign rider: $e2';
        }
      }
    }

    if (success) {
      await loadAdminOrders();
    }
    return success;
  }

  // Direct order creation (Customer checkout booking fallback)
  Future<Order?> createOrderDirect({
    required String customerId,
    required String deliveryAddress,
    required String customerPhone,
    required String paymentMethod,
    required List<CartItem> cartItems,
  }) async {
    _setLoading(true);
    try {
      final now = DateTime.now();
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final randomSuffix =
          (1000 + (now.millisecondsSinceEpoch % 9000)).toString();
      final orderNumber = 'OC-$dateStr-$randomSuffix';

      double subtotal = 0;
      for (final item in cartItems) {
        subtotal += item.subtotal;
      }
      final deliveryFee = AppConstants.deliveryFee;
      final totalAmount = subtotal + deliveryFee;

      // 1. Insert order
      Map<String, dynamic>? newOrderData;
      try {
        newOrderData = await _adminClient
            .from('orders')
            .insert({
              'order_number': orderNumber,
              'customer_id': customerId,
              'subtotal': subtotal,
              'delivery_fee': deliveryFee,
              'total_amount': totalAmount,
              'payment_status': AppConstants.paymentPending,
              'order_status': AppConstants.statusPendingConfirmation,
              'delivery_address': deliveryAddress,
              'customer_phone': customerPhone,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .select()
            .single();
      } catch (_) {
        newOrderData = await _client
            .from('orders')
            .insert({
              'order_number': orderNumber,
              'customer_id': customerId,
              'subtotal': subtotal,
              'delivery_fee': deliveryFee,
              'total_amount': totalAmount,
              'payment_status': AppConstants.paymentPending,
              'order_status': AppConstants.statusPendingConfirmation,
              'delivery_address': deliveryAddress,
              'customer_phone': customerPhone,
              'created_at': now.toIso8601String(),
              'updated_at': now.toIso8601String(),
            })
            .select()
            .single();
      }

      final orderId = newOrderData['id'] as String;

      // 2. Insert order items
      final itemsToInsert = cartItems
          .map((item) => {
                'order_id': orderId,
                'product_id': item.productId,
                'product_name': item.productName ?? 'Product',
                'product_price': item.productPrice ?? 0.0,
                'quantity': item.quantity,
                'subtotal': item.subtotal,
              })
          .toList();

      try {
        await _adminClient.from('order_items').insert(itemsToInsert);
      } catch (_) {
        await _client.from('order_items').insert(itemsToInsert);
      }

      // 3. Insert payment
      try {
        await _adminClient.from('payments').insert({
          'order_id': orderId,
          'customer_id': customerId,
          'provider': 'xendit',
          'payment_reference': 'xnd_mock_$orderNumber',
          'payment_method': paymentMethod,
          'amount': totalAmount,
          'status': AppConstants.paymentPending,
          'created_at': now.toIso8601String(),
        });
      } catch (_) {
        await _client.from('payments').insert({
          'order_id': orderId,
          'customer_id': customerId,
          'provider': 'xendit',
          'payment_reference': 'xnd_mock_$orderNumber',
          'payment_method': paymentMethod,
          'amount': totalAmount,
          'status': AppConstants.paymentPending,
          'created_at': now.toIso8601String(),
        });
      }

      // 4. Insert order status history
      try {
        await _adminClient.from('order_status_history').insert({
          'order_id': orderId,
          'status': AppConstants.statusPendingConfirmation,
          'changed_by': customerId,
          'notes': 'Order placed by customer.',
          'created_at': now.toIso8601String(),
        });
      } catch (_) {
        await _client.from('order_status_history').insert({
          'order_id': orderId,
          'status': AppConstants.statusPendingConfirmation,
          'changed_by': customerId,
          'notes': 'Order placed by customer.',
          'created_at': now.toIso8601String(),
        });
      }


      await loadCustomerOrders(customerId);
      return await getOrderById(orderId);
    } catch (e) {
      debugPrint('createOrderDirect error: $e');
      _error = 'Failed to place order: $e';
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Update order status (Admin)
  Future<bool> updateOrderStatus(String orderId, String status,
      {String? notes, String? changedBy}) async {
    try {
      await _adminClient.from('orders').update({
        'order_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);

      // Record in history
      await _adminClient.from('order_status_history').insert({
        'order_id': orderId,
        'status': status,
        'changed_by': changedBy,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('updateOrderStatus error: $e');
      return false;
    }
  }

  // Accept/Reject delivery (Rider)
  Future<bool> respondToDelivery({
    required String assignmentId,
    required String orderId,
    required bool accepted,
    String? rejectionReason,
  }) async {
    try {
      final status = accepted ? 'accepted' : 'rejected';
      await _client.from('rider_assignments').update({
        'status': status,
        'rejection_reason': rejectionReason,
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', assignmentId);

      if (accepted) {
        await _client.from('orders').update({
          'order_status': 'rider_accepted',
          'accepted_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      } else {
        // Unassign rider
        await _client.from('orders').update({
          'order_status': 'pending_confirmation',
          'rider_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', orderId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Update delivery status (Rider)
  Future<bool> updateDeliveryStatus(String orderId, String status) async {
    try {
      final updates = <String, dynamic>{
        'order_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (status == 'delivered') {
        updates['delivered_at'] = DateTime.now().toIso8601String();
      }
      await _client.from('orders').update(updates).eq('id', orderId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // Order status history
  Future<List<OrderStatusHistory>> getOrderHistory(String orderId) async {
    try {
      final data = await _client
          .from('order_status_history')
          .select()
          .eq('order_id', orderId)
          .order('created_at');
      return (data as List)
          .map((e) => OrderStatusHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Dashboard stats
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final products = await _adminClient
          .from('products')
          .select('id')
          .eq('is_active', true);
      final customers = await _adminClient
          .from('profiles')
          .select('id')
          .eq('role', 'customer');
      final riders =
          await _adminClient.from('profiles').select('id').eq('role', 'rider');
      final orders = await _adminClient
          .from('orders')
          .select('id, order_status, total_amount, payment_status');

      final orderList = orders as List;
      final pending = orderList
          .where((o) => o['order_status'] == 'pending_confirmation')
          .length;
      final processing =
          orderList.where((o) => o['order_status'] == 'processing').length;
      final active = orderList
          .where((o) => ['rider_accepted', 'picked_up', 'out_for_delivery']
              .contains(o['order_status']))
          .length;
      final delivered =
          orderList.where((o) => o['order_status'] == 'delivered').length;
      final revenue = orderList
          .where((o) => o['payment_status'] == 'paid')
          .fold<double>(0,
              (sum, o) => sum + ((o['total_amount'] as num?)?.toDouble() ?? 0));

      return {
        'products': (products as List).length,
        'customers': (customers as List).length,
        'riders': (riders as List).length,
        'totalOrders': orderList.length,
        'pendingOrders': pending,
        'processingOrders': processing,
        'activeDeliveries': active,
        'completedDeliveries': delivered,
        'totalRevenue': revenue,
      };
    } catch (_) {
      return {};
    }
  }

  @override
  void dispose() {
    _customerOrdersSubscription?.unsubscribe();
    super.dispose();
  }
}
