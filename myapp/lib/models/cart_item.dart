class CartItem {
  final String id;
  final String customerId;
  final String productId;
  int quantity;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined product info
  final String? productName;
  final double? productPrice;
  final String? productImageUrl;
  final int? productStock;

  CartItem({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.quantity,
    required this.createdAt,
    required this.updatedAt,
    this.productName,
    this.productPrice,
    this.productImageUrl,
    this.productStock,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>?;
    return CartItem(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      productId: json['product_id'] as String,
      quantity: json['quantity'] as int? ?? 1,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      productName: product?['name'] as String?,
      productPrice: (product?['price'] as num?)?.toDouble(),
      productImageUrl: product?['image_url'] as String?,
      productStock: product?['stock'] as int?,
    );
  }

  double get subtotal => (productPrice ?? 0) * quantity;
}
