import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/product_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/product.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/ocean_text_field.dart';
import '../../../core/utils/validators.dart';
import '../../authentication/providers/auth_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uuid/uuid.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});
  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadAllProducts();
      context.read<ProductProvider>().loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final products = _search.text.isEmpty
        ? provider.allProducts
        : provider.allProducts.where((p) => p.name.toLowerCase().contains(_search.text.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Product Management'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.white),
            tooltip: 'Add Product',
            onPressed: () => _openProductForm(context, null),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.white),
            tooltip: 'Sign Out',
            onPressed: () => _confirmSignOut(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(hintText: 'Search products...', prefixIcon: Icon(Icons.search, color: AppColors.primary)),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : products.isEmpty
                    ? const Center(child: Text('No products found'))
                    : ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (_, i) {
                          final p = products[i];
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 4)]),
                            child: ListTile(
                              leading: SizedBox(
                                width: 50,
                                height: 50,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  clipBehavior: Clip.antiAlias,
                                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: p.imageUrl!,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            width: 50,
                                            height: 50,
                                            color: AppColors.greyLight,
                                            child: const Icon(Icons.image, color: AppColors.grey, size: 24),
                                          ),
                                        )
                                      : Container(
                                          width: 50,
                                          height: 50,
                                          color: AppColors.greyLight,
                                          child: const Icon(Icons.image, color: AppColors.grey, size: 24),
                                        ),
                                ),
                              ),
                              title: Text(
                                p.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '₱${p.price.toStringAsFixed(2)} • Stock: ${p.stock}',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: p.isActive ? AppColors.success.withValues(alpha: 0.12) : AppColors.error.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(p.isActive ? 'Active' : 'Inactive',
                                        style: TextStyle(fontSize: 10, color: p.isActive ? AppColors.success : AppColors.error)),
                                    ),
                                  ]),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'edit') _openProductForm(context, p);
                                  if (action == 'toggle') {
                                    await provider.updateProduct(p.id, {'is_active': !p.isActive});
                                  }
                                  if (action == 'delete' && context.mounted) {
                                    final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
                                      title: const Text('Delete Product'),
                                      content: Text('Delete "${p.name}"?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true),
                                          child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                                      ],
                                    ));
                                    if (ok == true && context.mounted) await provider.deleteProduct(p.id);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'toggle', child: Text('Toggle Active')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.error))),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out and exit Admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  void _openProductForm(BuildContext context, Product? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: ProductFormSheet(product: product),
        ),
      ),
    );
  }
}

class ProductFormSheet extends StatefulWidget {
  final Product? product;
  const ProductFormSheet({super.key, this.product});
  @override
  State<ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _descCtrl, _priceCtrl, _stockCtrl;
  String? _categoryId;
  XFile? _imageFile;
  String? _imageUrl;
  bool _isActive = true;
  bool _loading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name);
    _descCtrl = TextEditingController(text: p?.description);
    _priceCtrl = TextEditingController(text: p?.price.toString());
    _stockCtrl = TextEditingController(text: p?.stock.toString());
    _categoryId = p?.categoryId;
    _imageUrl = p?.imageUrl;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _priceCtrl.dispose(); _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category')));
      return;
    }
    setState(() => _loading = true);
    try {
      String? uploadedUrl = _imageUrl;
      final productId = widget.product?.id ?? const Uuid().v4();

      if (_imageFile != null) {
        uploadedUrl = await StorageService().uploadProductImage(_imageFile!, productId);
      }

      final data = {
        'id': productId,
        'category_id': _categoryId,
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text),
        'stock': int.parse(_stockCtrl.text),
        'image_url': uploadedUrl,
        'is_active': _isActive,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (!mounted) return;
      final provider = context.read<ProductProvider>();
      if (widget.product == null) {
        await provider.addProduct(data);
      } else {
        await provider.updateProduct(productId, data);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProductProvider>().categories;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.product == null ? 'Add Product' : 'Edit Product', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.greyLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: _imageFile != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: kIsWeb
                                ? Image.network(
                                    _imageFile!.path,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 140,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: double.infinity,
                                      height: 140,
                                      color: AppColors.greyLight,
                                      child: const Icon(Icons.image, color: AppColors.grey, size: 32),
                                    ),
                                  )
                                : Image.file(
                                    File(_imageFile!.path),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 140,
                                  ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.edit, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Change Image', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _imageFile = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      )
                    : _imageUrl != null && _imageUrl!.isNotEmpty
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                child: CachedNetworkImage(
                                  imageUrl: _imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 140,
                                  placeholder: (_, __) => const Center(
                                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                                  ),
                                  errorWidget: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image, color: AppColors.grey, size: 36),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.edit, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Change Image', style: TextStyle(color: Colors.white, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 36),
                              SizedBox(height: 4),
                              Text('Tap to add product image', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
              ),
            ),
            const SizedBox(height: 12),
            OceanTextField(controller: _nameCtrl, label: 'Product Name', validator: (v) => Validators.required(v, fieldName: 'Product name')),
            const SizedBox(height: 12),
            OceanTextField(controller: _descCtrl, label: 'Description', maxLines: 3),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId?.isEmpty ?? true ? null : _categoryId,
              hint: const Text('Select Category'),
              items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (v) => setState(() => _categoryId = v),
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OceanTextField(controller: _priceCtrl, label: 'Price (₱)', keyboardType: TextInputType.number, validator: Validators.price)),
              const SizedBox(width: 12),
              Expanded(child: OceanTextField(controller: _stockCtrl, label: 'Stock', keyboardType: TextInputType.number, validator: Validators.stock)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Active', style: TextStyle(fontSize: 14)),
              const Spacer(),
              Switch(value: _isActive, onChanged: (v) => setState(() => _isActive = v), activeThumbColor: AppColors.primary),
            ]),
            const SizedBox(height: 16),
            PrimaryButton(label: widget.product == null ? 'Add Product' : 'Save Changes', isLoading: _loading, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
