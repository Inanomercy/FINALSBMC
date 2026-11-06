class Product {
  final String id;
  final String categoryId;
  final String name;
  final String? description;
  final double price;
  final int stock;
  final String? imageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? categoryName;
  final List<String> additionalImages;

  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    this.description,
    required this.price,
    required this.stock,
    this.imageUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.additionalImages = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final cat = json['categories'] as Map<String, dynamic>?;
    return Product(
      id: json['id'] as String,
      categoryId: json['category_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      categoryName: cat?['name'] as String?,
      additionalImages: const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'stock': stock,
      'image_url': imageUrl,
      'is_active': isActive,
    };
  }

  bool get isAvailable => isActive && stock > 0;

  Product copyWith({
    String? categoryId,
    String? name,
    String? description,
    double? price,
    int? stock,
    String? imageUrl,
    bool? isActive,
    String? categoryName,
  }) {
    return Product(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      categoryName: categoryName ?? this.categoryName,
      additionalImages: additionalImages,
    );
  }
}
