class Payment {
  final String id;
  final String orderId;
  final String customerId;
  final String provider;
  final String? paymentReference;
  final String? paymentMethod;
  final double amount;
  final String status;
  final String? checkoutUrl;
  final DateTime? paidAt;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.orderId,
    required this.customerId,
    this.provider = 'xendit',
    this.paymentReference,
    this.paymentMethod,
    required this.amount,
    required this.status,
    this.checkoutUrl,
    this.paidAt,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      orderId: json['order_id'] as String,
      customerId: json['customer_id'] as String,
      provider: json['provider'] as String? ?? 'xendit',
      paymentReference: json['payment_reference'] as String?,
      paymentMethod: json['payment_method'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'pending',
      checkoutUrl: json['checkout_url'] as String?,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}
