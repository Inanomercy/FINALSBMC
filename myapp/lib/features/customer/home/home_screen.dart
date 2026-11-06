import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/product_provider.dart';
import '../../../shared/providers/cart_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import '../../../models/product.dart';
import '../../../models/category.dart';
import '../../../shared/widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  int _bannerIndex = 0;

  final List<Map<String, dynamic>> _banners = [
    {'title': 'Fresh Seafood\nDelivered Fast', 'subtitle': 'Order now and get it today!', 'icon': Icons.set_meal, 'gradient': [Color(0xFF087EA4), Color(0xFF063B5C)]},
    {'title': 'Catch of the Day\nSpecial Deals', 'subtitle': 'Up to 30% off on selected items', 'icon': Icons.local_offer, 'gradient': [Color(0xFF35C6D8), Color(0xFF087EA4)]},
    {'title': 'Free Delivery\nOver ₱500', 'subtitle': 'Shop more, save more!', 'icon': Icons.delivery_dining, 'gradient': [Color(0xFF063B5C), Color(0xFF35C6D8)]},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadProducts();
      context.read<ProductProvider>().loadCategories();
      final auth = context.read<AuthProvider>();
      if (auth.userProfile != null) {
        context.read<CartProvider>().loadCart(auth.userProfile!.id);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final productProvider = context.watch<ProductProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            backgroundColor: AppColors.primary,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shopping_cart_rounded, color: AppColors.white, size: 24),
                        const SizedBox(width: 8),
                        Text('OceanCart', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.white, fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text('Hi, ${auth.userProfile?.fullName.split(' ').first ?? 'there'}! 👋',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.white.withValues(alpha: 0.9))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search seafood products...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                    fillColor: AppColors.white,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) {
                    context.read<ProductProvider>().setSearch(v);
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: productProvider.isLoading
                ? const _LoadingSkeleton()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Promotional Banners
                      _buildBanners(context),
                      const SizedBox(height: 24),
                      // Categories
                      _buildSectionHeader(context, 'Categories', onViewAll: () {}),
                      const SizedBox(height: 12),
                      _buildCategories(context, productProvider.categories),
                      const SizedBox(height: 24),
                      // Featured Products
                      _buildSectionHeader(context, 'Featured Products'),
                      const SizedBox(height: 12),
                      _buildProductGrid(context, productProvider.featuredProducts),
                      const SizedBox(height: 24),
                      // New Arrivals
                      _buildSectionHeader(context, 'New Arrivals'),
                      const SizedBox(height: 12),
                      _buildProductGrid(context, productProvider.newArrivals),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanners(BuildContext context) {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 160,
            autoPlay: true,
            viewportFraction: 0.92,
            autoPlayInterval: const Duration(seconds: 4),
            onPageChanged: (i, _) => setState(() => _bannerIndex = i),
          ),
          items: _banners.map((b) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: (b['gradient'] as List).cast<Color>(), begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(b['title'] as String, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(b['subtitle'] as String, style: TextStyle(color: AppColors.white.withValues(alpha: 0.85), fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(b['icon'] as IconData, color: AppColors.white.withValues(alpha: 0.4), size: 72),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _bannerIndex == i ? 20 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _bannerIndex == i ? AppColors.primary : AppColors.greyLight,
              borderRadius: BorderRadius.circular(4),
            ),
          )),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, {VoidCallback? onViewAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (onViewAll != null)
            TextButton(onPressed: onViewAll, child: const Text('View All', style: TextStyle(color: AppColors.primary))),
        ],
      ),
    );
  }

  Widget _buildCategories(BuildContext context, List<Category> categories) {
    if (categories.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: Text('No categories yet', style: TextStyle(color: AppColors.textSecondary))),
      );
    }
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final cat = categories[i];
          return GestureDetector(
            onTap: () {
              context.read<ProductProvider>().setCategory(cat.id);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 72,
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: cat.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(imageUrl: cat.imageUrl!, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.category, color: AppColors.primary)),
                          )
                        : const Icon(Icons.category, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(height: 4),
                  Text(cat.name, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(BuildContext context, List<Product> products) {
    if (products.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('No products available', style: TextStyle(color: AppColors.textSecondary))),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.72,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length > 6 ? 6 : products.length,
      itemBuilder: (_, i) => ProductCard(product: products[i]),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Padding(
      padding: EdgeInsets.all(32),
      child: CircularProgressIndicator(color: AppColors.primary),
    ));
  }
}
