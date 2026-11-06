class XenditConfig {
  // Xendit public key is safe to use in the client app, but the secret key
  // must never be shipped to Flutter. The server-side Edge Function owns the
  // XENDIT_SECRET_KEY and calls the Xendit API securely.
  static const String publicKey = String.fromEnvironment(
    'XENDIT_PUBLIC_KEY',
    defaultValue: 'YOUR_XENDIT_PUBLIC_KEY',
  );

  static const String appBaseUrl = String.fromEnvironment(
    'APP_BASE_URL',
    defaultValue: 'oceancart://',
  );

  static const String invoiceApiBaseUrl = 'https://api.xendit.co';
  static const String checkoutBaseUrl = 'https://checkout.xendit.co/v2/checkout';

  static const bool isSandbox = true;

  static bool get isConfigured =>
      publicKey.startsWith('xnd_') &&
      !publicKey.startsWith('YOUR_') &&
      publicKey.isNotEmpty;

  static String get secretKeyWarning =>
      'Do not expose XENDIT_SECRET_KEY in Flutter. Keep it in Supabase Edge Function secrets only.';
}