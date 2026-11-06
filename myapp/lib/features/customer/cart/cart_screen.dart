import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/cart_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Cart'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
                  title: const Text('Clear Cart'),
                  content: const Text('Remove all items from cart?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Clear', style: TextStyle(color: AppColors.error))),
                  ],
                ));
                if (ok == true && context.mounted) {
                  cart.clearCart(auth.userProfile!.id);
                }
              },
              child: const Text('Clear', style: TextStyle(color: AppColors.white)),
            ),
        ],
      ),
      body: cart.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : cart.items.isEmpty
              ? _EmptyCart()
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: cart.items.length,
                        itemBuilder: (_, i) {
                          final item = cart.items[i];
                          return Dismissible(
                            key: Key(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              color: AppColors.error,
                              child: const Icon(Icons.delete, color: AppColors.white),
                            ),
                            onDismissed: (_) => cart.removeItem(item.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      clipBehavior: Clip.antiAlias,
                                      child: item.productImageUrl != null && item.productImageUrl!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: item.productImageUrl!,
                                              width: 64,
                                              height: 64,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => _imagePlaceholder(),
                                            )
                                          : _imagePlaceholder(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName ?? 'Product', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text('₱${(item.productPrice ?? 0).toStringAsFixed(2)}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                  // Quantity Controls
                                  Row(
                                    children: [
                                      _qtyBtn(Icons.remove, () => cart.updateQuantity(item.id, item.quantity - 1)),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(6)),
                                        child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                      _qtyBtn(Icons.add, item.quantity < (item.productStock ?? 99) ? () => cart.updateQuantity(item.id, item.quantity + 1) : null),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Order Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppColors.white,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
                      ),
                      child: Column(
                        children: [
                          _summaryRow(context, 'Subtotal', '₱${cart.subtotal.toStringAsFixed(2)}'),
                          _summaryRow(context, 'Delivery Fee', '₱${AppConstants.deliveryFee.toStringAsFixed(2)}'),
                          const Divider(height: 16),
                          _summaryRow(context, 'Total', '₱${(cart.subtotal + AppConstants.deliveryFee).toStringAsFixed(2)}', bold: true),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: 'Proceed to Checkout',
                            icon: Icons.arrow_forward,
                            onPressed: () => context.push('/customer/checkout'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _imagePlaceholder() => Container(width: 64, height: 64, color: AppColors.greyLight,
    child: const Icon(Icons.image_outlined, color: AppColors.grey));

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: onTap != null ? AppColors.primary.withValues(alpha: 0.1) : AppColors.greyLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: onTap != null ? AppColors.primary : AppColors.grey),
    ),
  );

  Widget _summaryRow(BuildContext context, String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 16 : 14)),
        Text(value, style: TextStyle(color: bold ? AppColors.primary : AppColors.textPrimary, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, fontSize: bold ? 16 : 14)),
      ],
    ),
  );
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shopping_cart_outlined, size: 80, color: AppColors.grey),
          const SizedBox(height: 16),
          Text('Your cart is empty', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Add products to get started!', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => context.go('/customer'), child: const Text('Browse Products')),
        ],
      ),
    );
  }
}
