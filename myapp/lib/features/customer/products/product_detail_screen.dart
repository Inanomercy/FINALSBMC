import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/product.dart';
import '../../../shared/providers/product_provider.dart';
import '../../../shared/providers/cart_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  bool _loading = true;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    final p = await context.read<ProductProvider>().getProductById(widget.productId);

    if (!mounted) return;

    setState(() {
      _product = p;
      _loading = false;
    });
  }

  void _increment() {
    if (_product == null) return;
    if (_quantity < _product!.stock) {
      setState(() => _quantity++);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${_product!.stock} item(s) available in stock.'),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _decrement() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  Future<bool> _ensureAuthAndAddToCart() async {
    final auth = context.read<AuthProvider>();
    if (auth.userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to add items to your cart.'),
          backgroundColor: AppColors.error,
        ),
      );
      context.push('/login');
      return false;
    }

    if (_product == null || !_product!.isActive || _product!.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This product is no longer available.'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }

    await context.read<CartProvider>().addToCart(
      customerId: auth.userProfile!.id,
      productId: _product!.id,
      quantity: _quantity,
    );

    return true;
  }

  Future<void> _addToCart() async {
    final success = await _ensureAuthAndAddToCart();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_quantity x ${_product!.name} added to cart!'),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: 'View Cart',
            textColor: AppColors.white,
            onPressed: () => context.push('/customer/cart'),
          ),
        ),
      );
    }
  }

  Future<void> _buyNow() async {
    final success = await _ensureAuthAndAddToCart();
    if (success && mounted) {
      context.push('/customer/checkout');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_product?.name ?? 'Product Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text('$cartCount'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            onPressed: () => context.push('/customer/cart'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _product == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppColors.grey),
                      const SizedBox(height: 12),
                      const Text(
                        'This product is no longer available.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Back to Shopping'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Image Hero
                      AspectRatio(
                        aspectRatio: 1.1,
                        child: ClipRRect(
                          clipBehavior: Clip.antiAlias,
                          child: _product!.imageUrl != null && _product!.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _product!.imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (_, __) => _imagePlaceholder(),
                                  errorWidget: (_, __, ___) => _imagePlaceholder(),
                                )
                              : _imagePlaceholder(),
                        ),
                      ),
                      Container(
                        color: AppColors.white,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_product!.categoryName != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _product!.categoryName!.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Text(
                              _product!.name,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '₱${_product!.price.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_product!.stock > 0 ? AppColors.success : AppColors.error)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _product!.stock > 0 ? '${_product!.stock} in stock' : 'Out of Stock',
                                    style: TextStyle(
                                      color: _product!.stock > 0 ? AppColors.success : AppColors.error,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Description Card
                      Container(
                        width: double.infinity,
                        color: AppColors.white,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product Description',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _product!.description?.isNotEmpty == true
                                  ? _product!.description!
                                  : 'Fresh, sustainably sourced seafood prepared to OceanCart high-quality standards.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.5,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Quantity Selector Card
                      if (_product!.stock > 0)
                        Container(
                          color: AppColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Quantity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: _quantity > 1 ? _decrement : null,
                                    ),
                                    Text(
                                      '$_quantity',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: _quantity < _product!.stock ? _increment : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
      bottomNavigationBar: _product != null && _product!.stock > 0
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Add to Cart'),
                        onPressed: _addToCart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.flash_on),
                        label: const Text('Buy Now'),
                        onPressed: _buyNow,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: AppColors.greyLight,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 80, color: AppColors.grey),
      ),
    );
  }
}
