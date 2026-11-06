import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/providers/cart_provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  bool _loading = false;
  String _paymentMethod = 'ewallet_gcash';

  final List<Map<String, String>> _paymentMethods = [
    {'id': 'ewallet_gcash', 'label': 'GCash', 'icon': 'G'},
    {'id': 'ewallet_paymaya', 'label': 'Maya', 'icon': 'M'},
    {'id': 'credit_card', 'label': 'Credit/Debit Card', 'icon': 'C'},
    {'id': 'qr_ph', 'label': 'QR Ph', 'icon': 'Q'},
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _addressCtrl = TextEditingController(text: auth.userProfile?.address ?? '');
    _phoneCtrl = TextEditingController(text: auth.userProfile?.phone ?? '');
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final cart = context.read<CartProvider>();
    final auth = context.read<AuthProvider>();
    final authProfile = auth.userProfile;
    if (cart.items.isEmpty || authProfile == null) return;

    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Your session is no longer valid. Please sign in again.'),
              backgroundColor: AppColors.error),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await http
          .post(
            Uri.parse(
                '${AppConstants.supabaseUrl}/functions/v1/create-xendit-invoice'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
              'apikey': AppConstants.supabaseAnonKey,
            },
            body: jsonEncode({
              'customer_id': authProfile.id,
              'delivery_address': _addressCtrl.text.trim(),
              'customer_phone': _phoneCtrl.text.trim(),
              'payment_method': _paymentMethod,
              'items': cart.items
                  .map((i) =>
                      {'product_id': i.productId, 'quantity': i.quantity})
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw Exception(
            'Invoice service returned an invalid response (${response.statusCode}).');
      }
      if (response.statusCode != 200) {
        throw Exception(data['error']?.toString() ??
            'Invoice request failed (${response.statusCode}).');
      }

      final checkoutUrl = data['checkout_url']?.toString().trim() ?? '';
      final orderId = data['order_id']?.toString() ?? '';
      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          orderId.isEmpty) {
        throw Exception(
            'Invoice service did not return a valid Xendit checkout link.');
      }

      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception(
            'Could not open the Xendit invoice. Please check your browser and try again.');
      }

      if (mounted) {
        await cart.clearCart(authProfile.id);
        if (mounted) {
          context.go('/customer/payment/$orderId');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Order booked. Complete payment in Xendit.'),
                backgroundColor: AppColors.success),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final total = cart.subtotal + AppConstants.deliveryFee;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: const Text('Checkout'), backgroundColor: AppColors.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Delivery Info
              _sectionCard(
                context,
                'Delivery Information',
                Icons.location_on_outlined,
                Column(
                  children: [
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Delivery Address',
                          hintText: 'House No., Street, Barangay, City'),
                      maxLines: 3,
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Address is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Contact Number', hintText: '09xxxxxxxxx'),
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Phone is required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Order Items
              _sectionCard(
                context,
                'Order Items (${cart.itemCount})',
                Icons.shopping_bag_outlined,
                Column(
                  children: cart.items
                      .map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(
                                        '${item.productName} x${item.quantity}',
                                        style: const TextStyle(fontSize: 13))),
                                Text('₱${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method
              _sectionCard(
                context,
                'Payment Method',
                Icons.payment,
                Column(
                  children: _paymentMethods
                      .map((m) => RadioListTile<String>(
                            value: m['id']!,
                            // ignore: deprecated_member_use
                            groupValue: _paymentMethod,
                            // ignore: deprecated_member_use
                            onChanged: (v) =>
                                setState(() => _paymentMethod = v!),
                            title: Text(m['label']!,
                                style: const TextStyle(fontSize: 14)),
                            activeColor: AppColors.primary,
                            contentPadding: EdgeInsets.zero,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Summary
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: AppColors.cardShadow, blurRadius: 6)
                    ]),
                child: Column(
                  children: [
                    _summaryRow(
                        'Subtotal', '₱${cart.subtotal.toStringAsFixed(2)}'),
                    _summaryRow('Delivery Fee',
                        '₱${AppConstants.deliveryFee.toStringAsFixed(2)}'),
                    const Divider(height: 16),
                    _summaryRow('Total', '₱${total.toStringAsFixed(2)}',
                        bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Place Order & Pay',
                isLoading: _loading,
                onPressed: _placeOrder,
                icon: Icons.lock_outline,
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Secured by Xendit Payment Gateway',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard(
      BuildContext context, String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: AppColors.cardShadow, blurRadius: 6)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.headlineSmall)
          ]),
          const Divider(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                  color: bold ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  fontSize: bold ? 16 : 14)),
        ]),
      );
}
