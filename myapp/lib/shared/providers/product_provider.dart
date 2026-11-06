import 'package:flutter/foundation.dart' hide Category;
import '../../core/services/supabase_service.dart';
import '../../models/product.dart';
import '../../models/category.dart';

class ProductProvider extends ChangeNotifier {
  SupabaseClient get _client => SupabaseService.client;
  SupabaseClient get _adminClient => SupabaseService.adminClient;

  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  String? _selectedCategoryId;
  String _sortBy = 'newest'; // newest, price_asc, price_desc

  List<Product> get products => _filteredProducts;
  List<Category> get categories => _categories;
  bool get isLoading => _loading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  String? get selectedCategoryId => _selectedCategoryId;
  String get sortBy => _sortBy;

  List<Product> get _filteredProducts {
    var list = _products.where((p) => p.isActive).toList();

    if (_selectedCategoryId != null) {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) => p.name.toLowerCase().contains(q) || (p.description?.toLowerCase().contains(q) ?? false)).toList();
    }

    switch (_sortBy) {
      case 'price_asc':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price_desc':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      default:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return list;
  }

  List<Product> get featuredProducts => _products.where((p) => p.isActive && p.stock > 0).take(8).toList();
  List<Product> get newArrivals {
    final sorted = [..._products.where((p) => p.isActive)]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(10).toList();
  }

  void setSearch(String q) {
    _searchQuery = q;
    notifyListeners();
  }

  void setCategory(String? id) {
    _selectedCategoryId = id;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategoryId = null;
    _sortBy = 'newest';
    notifyListeners();
  }

  Future<void> loadProducts() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _client
          .from('products')
          .select('*, categories(name)')
          .eq('is_active', true)
          .order('created_at', ascending: false);
      _products = (data as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      _error = 'Failed to load products.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadCategories() async {
    try {
      final data = await _client.from('categories').select().order('name');
      _categories = (data as List).map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<Product?> getProductById(String id) async {
    try {
      final data = await _client
          .from('products')
          .select('*, categories(name)')
          .eq('id', id)
          .eq('is_active', true)
          .single();
      return Product.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  // Admin operations
  Future<bool> addProduct(Map<String, dynamic> data) async {
    try {
      await _adminClient.from('products').insert(data);
      await loadAllProducts();
      await loadProducts();
      return true;
    } catch (e) {
      debugPrint('addProduct error: $e');
      rethrow;
    }
  }

  Future<bool> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      await _adminClient.from('products').update(data).eq('id', id);
      await loadAllProducts();
      await loadProducts();
      return true;
    } catch (e) {
      debugPrint('updateProduct error: $e');
      rethrow;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _adminClient.from('products').update({'is_active': false}).eq('id', id);
      await loadAllProducts();
      await loadProducts();
      return true;
    } catch (e) {
      debugPrint('deleteProduct error: $e');
      return false;
    }
  }

  Future<bool> addCategory(Map<String, dynamic> data) async {
    try {
      await _adminClient.from('categories').insert(data);
      await loadCategories();
      return true;
    } catch (e) {
      debugPrint('addCategory error: $e');
      rethrow;
    }
  }

  Future<bool> updateCategory(String id, Map<String, dynamic> data) async {
    try {
      await _adminClient.from('categories').update(data).eq('id', id);
      await loadCategories();
      return true;
    } catch (e) {
      debugPrint('updateCategory error: $e');
      rethrow;
    }
  }

  Future<bool> deleteCategory(String id) async {
    try {
      await _adminClient.from('categories').delete().eq('id', id);
      await loadCategories();
      return true;
    } catch (e) {
      debugPrint('deleteCategory error: $e');
      return false;
    }
  }

  // All products for admin (including inactive)
  List<Product> _allProducts = [];
  List<Product> get allProducts => _allProducts;

  Future<void> loadAllProducts() async {
    try {
      final data = await _adminClient.from('products').select('*, categories(name)').order('created_at', ascending: false);
      _allProducts = (data as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('loadAllProducts error: $e');
    }
  }
}
