import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/product_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/category.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/ocean_text_field.dart';
import '../../../core/utils/validators.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});
  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ProductProvider>().loadCategories());
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ProductProvider>().categories;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Category Management'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.add, color: AppColors.white), onPressed: () => _openForm(context, null)),
        ],
      ),
      body: categories.isEmpty
          ? const Center(child: Text('No categories yet. Add one!', style: TextStyle(color: AppColors.textSecondary)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: categories.length,
              itemBuilder: (_, i) {
                final cat = categories[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 4)]),
                  child: ListTile(
                    leading: SizedBox(
                      width: 50,
                      height: 50,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        clipBehavior: Clip.antiAlias,
                        child: cat.imageUrl != null && cat.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: cat.imageUrl!,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 50,
                                  height: 50,
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  child: const Icon(Icons.category, color: AppColors.primary),
                                ),
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.category, color: AppColors.primary),
                              ),
                      ),
                    ),
                    title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(cat.description ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20), onPressed: () => _openForm(context, cat)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                        onPressed: () async {
                          final ok = await showDialog<bool>(context: context, builder: (dialogCtx) => AlertDialog(
                            title: const Text('Delete Category'),
                            content: Text('Delete "${cat.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
                              TextButton(onPressed: () => Navigator.of(dialogCtx).pop(true),
                                child: const Text('Delete', style: TextStyle(color: AppColors.error))),
                            ],
                          ));
                          if (ok == true && context.mounted) await context.read<ProductProvider>().deleteCategory(cat.id);
                        },
                      ),
                    ]),
                  ),
                );
              },
            ),
    );
  }

  void _openForm(BuildContext context, Category? cat) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CategoryFormSheet(category: cat),
    );
  }
}

class _CategoryFormSheet extends StatefulWidget {
  final Category? category;
  const _CategoryFormSheet({this.category});
  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _descCtrl;
  XFile? _imageFile;
  String? _imageUrl;
  bool _loading = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name);
    _descCtrl = TextEditingController(text: widget.category?.description);
    _imageUrl = widget.category?.imageUrl;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final id = widget.category?.id ?? const Uuid().v4();
      String? uploadedUrl = _imageUrl;
      if (_imageFile != null) {
        uploadedUrl = await StorageService().uploadCategoryImage(_imageFile!, id);
      }
      final data = {'id': id, 'name': _nameCtrl.text.trim(), 'description': _descCtrl.text.trim(),
        'image_url': uploadedUrl, 'created_at': DateTime.now().toIso8601String()};
      if (!mounted) return;
      final provider = context.read<ProductProvider>();
      if (widget.category == null) { await provider.addCategory(data); }
      else { await provider.updateCategory(id, data); }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.category == null ? 'Add Category' : 'Edit Category', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 110,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.greyLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: kIsWeb
                          ? Image.network(
                              _imageFile!.path,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 110,
                              errorBuilder: (_, __, ___) => Container(
                                width: double.infinity,
                                height: 110,
                                color: AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.category, color: AppColors.primary),
                              ),
                            )
                          : Image.file(File(_imageFile!.path), fit: BoxFit.cover, width: double.infinity, height: 110),
                    )
                  : _imageUrl != null && _imageUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 110,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image, color: AppColors.grey, size: 32),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 32),
                            SizedBox(height: 4),
                            Text('Add Category Image', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
            ),
          ),
          const SizedBox(height: 12),
          OceanTextField(controller: _nameCtrl, label: 'Category Name', validator: (v) => Validators.required(v, fieldName: 'Category name')),
          const SizedBox(height: 12),
          OceanTextField(controller: _descCtrl, label: 'Description', maxLines: 2),
          const SizedBox(height: 16),
          PrimaryButton(label: widget.category == null ? 'Add Category' : 'Save', isLoading: _loading, onPressed: _save),
        ]),
      ),
    );
  }
}
