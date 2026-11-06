import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/order.dart';
import '../../../models/payment.dart';
import '../../../shared/providers/order_provider.dart';
import '../services/payment_service.dart';
import 'package:provider/provider.dart';

class PaymentStatusScreen extends StatefulWidget {
  final String orderId;
  const PaymentStatusScreen({super.key, required this.orderId});

  @override
  State<PaymentStatusScreen> createState() => _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends State<PaymentStatusScreen> {
  final _paymentService = PaymentService();
  Order? _order;
  Payment? _payment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    final order = await context.read<OrderProvider>().getOrderById(widget.orderId);
    final payment = await _paymentService.getPaymentByOrderId(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _payment = payment;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Payment Status'), backgroundColor: AppColors.primary),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final isPaid = _order?.paymentStatus == AppConstants.paymentPaid || _payment?.status == AppConstants.paymentPaid;
    final isFailed = _order?.paymentStatus == AppConstants.paymentFailed || _payment?.status == AppConstants.paymentFailed;
    final isPending = !isPaid && !isFailed;

    final statusColor = isPaid ? AppColors.success : (isFailed ? AppColors.error : AppColors.warning);
    final statusIcon = isPaid ? Icons.check_circle : (isFailed ? Icons.error : Icons.hourglass_top);
    final statusTitle = isPaid ? 'Payment Successful!' : (isFailed ? 'Payment Failed' : 'Payment Pending');
    final statusMessage = isPaid
        ? 'Thank you! Your payment has been confirmed and your seafood order is being processed.'
        : (isFailed
            ? 'We were unable to process your payment. Please try again or select another payment method.'
            : 'Your order has been recorded. Please complete payment via Xendit to proceed.');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Payment Status'),
        backgroundColor: AppColors.primary,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _checkStatus),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: statusColor, size: 72),
              ),
              const SizedBox(height: 24),
              Text(
                statusTitle,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 28),
              if (_order != null) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Order Number', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            Text(_order!.orderNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Amount', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            Text(
                              '₱${_order!.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                            ),
                          ],
                        ),
                        if (_payment?.paidAt != null) ...[
                          const Divider(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Paid At', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                              Text(
                                DateFormat('MMM dd, yyyy • hh:mm a').format(_payment!.paidAt!),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
              if (isPending && _payment?.checkoutUrl != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.payment),
                    label: const Text('Complete Payment on Xendit'),
                    onPressed: () => _paymentService.launchCheckout(_payment!.checkoutUrl!),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go('/customer/orders'),
                  child: const Text('View My Orders'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go('/customer'),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
