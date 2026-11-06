import 'package:flutter/foundation.dart';
import '../../core/services/supabase_service.dart';
import '../../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  SupabaseClient get _client => SupabaseService.client;

  List<CartItem> _items = [];
  bool _loading = false;

  List<CartItem> get items => _items;
  bool get isLoading => _loading;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal => _items.fold(0.0, (sum, i) => sum + i.subtotal);

  void _setLoading(bool v) { _loading = v; notifyListeners(); }

  Future<void> loadCart(String customerId) async {
    _setLoading(true);
    try {
      final data = await _client
          .from('cart_items')
          .select('*, products(name, price, image_url, stock, is_active)')
          .eq('customer_id', customerId)
          .order('created_at');
      _items = (data as List).map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _items = [];
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addToCart({required String customerId, required String productId, int quantity = 1}) async {
    // Check if already in cart
    final existing = _items.firstWhere((i) => i.productId == productId, orElse: () => CartItem(
      id: '', customerId: customerId, productId: productId,
      quantity: 0, createdAt: DateTime.now(), updatedAt: DateTime.now(),
    ));

    if (existing.id.isNotEmpty) {
      await updateQuantity(existing.id, existing.quantity + quantity);
    } else {
      try {
        await _client.from('cart_items').insert({
          'customer_id': customerId,
          'product_id': productId,
          'quantity': quantity,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        await loadCart(customerId);
      } catch (_) {}
    }
  }

  Future<void> updateQuantity(String cartItemId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(cartItemId);
      return;
    }
    try {
      await _client.from('cart_items').update({
        'quantity': quantity,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', cartItemId);
      final idx = _items.indexWhere((i) => i.id == cartItemId);
      if (idx >= 0) {
        _items[idx].quantity = quantity;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> removeItem(String cartItemId) async {
    try {
      await _client.from('cart_items').delete().eq('id', cartItemId);
      _items.removeWhere((i) => i.id == cartItemId);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> clearCart(String customerId) async {
    try {
      await _client.from('cart_items').delete().eq('customer_id', customerId);
      _items = [];
      notifyListeners();
    } catch (_) {}
  }

  void clearLocal() {
    _items = [];
    notifyListeners();
  }
}
