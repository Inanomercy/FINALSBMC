class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final double productPrice;
  final int quantity;
  final double subtotal;

  const OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.quantity,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String? ?? '',
      productPrice: (json['product_price'] as num?)?.toDouble() ?? 0.0,
      quantity: json['quantity'] as int? ?? 1,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String customerId;
  final String? riderId;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final String paymentStatus;
  final String orderStatus;
  final String deliveryAddress;
  final String customerPhone;
  final DateTime? assignedAt;
  final DateTime? acceptedAt;
  final DateTime? deliveredAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined
  final String? customerName;
  final String? riderName;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    this.riderId,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    required this.paymentStatus,
    required this.orderStatus,
    required this.deliveryAddress,
    required this.customerPhone,
    this.assignedAt,
    this.acceptedAt,
    this.deliveredAt,
    required this.createdAt,
    required this.updatedAt,
    this.customerName,
    this.riderName,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final rider = json['rider'] as Map<String, dynamic>?;
    final itemsJson = json['order_items'] as List<dynamic>?;
    return Order(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String? ?? '',
      customerId: json['customer_id'] as String,
      riderId: json['rider_id'] as String?,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      orderStatus: json['order_status'] as String? ?? 'pending_payment',
      deliveryAddress: json['delivery_address'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      assignedAt: json['assigned_at'] != null ? DateTime.parse(json['assigned_at'] as String) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at'] as String) : null,
      deliveredAt: json['delivered_at'] != null ? DateTime.parse(json['delivered_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      customerName: customer?['full_name'] as String?,
      riderName: rider?['full_name'] as String?,
      items: itemsJson?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
