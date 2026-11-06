import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/payment.dart';

class PaymentService {
  /// Create Xendit payment invoice via Edge Function
  Future<Map<String, dynamic>> createPayment({
    required String orderId,
    required String paymentMethod,
  }) async {
    final session = SupabaseService.currentSession;
    final url = Uri.parse('${AppConstants.supabaseUrl}/functions/v1/create-payment');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session?.accessToken ?? ''}',
        'apikey': AppConstants.supabaseAnonKey,
      },
      body: jsonEncode({
        'order_id': orderId,
        'payment_method': paymentMethod,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create payment: ${response.body}');
    }
  }

  /// Launch external Xendit checkout
  Future<bool> launchCheckout(String checkoutUrl) async {
    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null) return false;

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Fetch payment record from database
  Future<Payment?> getPaymentByOrderId(String orderId) async {
    try {
      final res = await SupabaseService.client
          .from('payments')
          .select()
          .eq('order_id', orderId)
          .maybeSingle();
      if (res != null) {
        return Payment.fromJson(res);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
