import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/product_provider.dart';
import '../../../shared/widgets/product_card.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadCategories();
      context.read<ProductProvider>().loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductProvider>();
    final categories = provider.categories;
    final products = _selectedCategoryId == null
        ? provider.products
        : provider.products.where((p) => p.categoryId == _selectedCategoryId).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Category chips
          if (categories.isNotEmpty)
            Container(
              height: 48,
              color: AppColors.white,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                children: [
                  _chip('All', null),
                  ...categories.map((c) => _chip(c.name, c.id)),
                ],
              ),
            ),
          // Products grid
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.inbox, size: 64, color: AppColors.grey),
                            const SizedBox(height: 12),
                            Text('No products found', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, childAspectRatio: 0.72,
                          crossAxisSpacing: 8, mainAxisSpacing: 8,
                        ),
                        itemCount: products.length,
                        itemBuilder: (_, i) => ProductCard(product: products[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? categoryId) {
    final selected = _selectedCategoryId == categoryId;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = categoryId),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.greyLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? AppColors.white : AppColors.textPrimary,
          fontSize: 12, fontWeight: FontWeight.w500,
        )),
      ),
    );
  }
}
