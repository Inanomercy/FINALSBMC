import 'package:supabase_flutter/supabase_flutter.dart';
export 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

class SupabaseService {
  static bool get isInitialized {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static SupabaseClient? _adminClientInstance;
  static SupabaseClient get adminClient {
    if (AppConstants.supabaseSecretKey.isEmpty) {
      return client;
    }
    _adminClientInstance ??= SupabaseClient(
      AppConstants.supabaseUrl,
      AppConstants.supabaseSecretKey,
    );
    return _adminClientInstance!;
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  static User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  static Session? get currentSession {
    try {
      return client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;
}
