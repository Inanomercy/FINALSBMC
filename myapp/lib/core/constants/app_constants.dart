class AppConstants {
  // App Info
  static const String appName = 'OceanCart';
  static const String appVersion = '1.0.0';

  // Supabase
  static const String supabaseUrl = 'https://bjpybpumzhdesyzucexq.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_tumTQnd97CGHtzkooSfGQw_6JTmnSt3';
  static const String supabaseSecretKey = '';
  static const String xenditPublicKey = 'xnd_development_bDcrZdYMJashHCYsKshovf6B2KByWB8hY4enL9WyAdosnncnyCVimWJIDm9x';

  // Storage
  static const String productImagesBucket = 'product-images';
  static const String categoryImagesBucket = 'category-images';
  static const String avatarsBucket = 'avatars';

  // Delivery
  static const double deliveryFee = 50.0;

  // Roles
  static const String roleCustomer = 'customer';
  static const String roleAdmin = 'admin';
  static const String roleRider = 'rider';

  // Order Statuses
  static const String statusPendingPayment = 'pending_payment';
  static const String statusPendingConfirmation = 'pending_confirmation';
  static const String statusProcessing = 'processing';
  static const String statusAssignedToRider = 'assigned_to_rider';
  static const String statusRiderAccepted = 'rider_accepted';
  static const String statusPickedUp = 'picked_up';
  static const String statusOutForDelivery = 'out_for_delivery';
  static const String statusDelivered = 'delivered';
  static const String statusCancelled = 'cancelled';
  static const String statusPaymentFailed = 'payment_failed';

  // Payment Statuses
  static const String paymentPending = 'pending';
  static const String paymentPaid = 'paid';
  static const String paymentFailed = 'failed';
  static const String paymentExpired = 'expired';

  // Assignment Statuses
  static const String assignmentPending = 'pending';
  static const String assignmentAccepted = 'accepted';
  static const String assignmentRejected = 'rejected';

  // Notification Types
  static const String notifOrder = 'order';
  static const String notifPayment = 'payment';
  static const String notifDelivery = 'delivery';
  static const String notifRider = 'rider';
  static const String notifSystem = 'system';
}
