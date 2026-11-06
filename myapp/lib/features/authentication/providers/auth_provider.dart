import 'package:flutter/foundation.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../models/user_profile.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserProfile? _userProfile;
  String? _errorMessage;
  bool _isInitialized = false;

  AuthStatus get status => _status;
  UserProfile? get userProfile => _userProfile;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isInitialized => _isInitialized;

  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _status = AuthStatus.error;
    _errorMessage = msg;
    notifyListeners();
  }

  void _setAuthenticated(UserProfile profile) {
    _status = AuthStatus.authenticated;
    _userProfile = profile;
    _errorMessage = null;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _status = AuthStatus.unauthenticated;
    _userProfile = null;
    notifyListeners();
  }

  /// Initialize - check if user is already logged in
  Future<void> initialize() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (!SupabaseService.isInitialized) {
        _setUnauthenticated();
        return;
      }
      final profile = await _authService.getCurrentProfile()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (profile != null) {
        _setAuthenticated(profile);
      } else {
        _setUnauthenticated();
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _setUnauthenticated();
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Register customer
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String address,
  }) async {
    _setLoading();
    if (!SupabaseService.isInitialized) {
      _setError('Unable to connect to server. Please check internet connection.');
      return false;
    }
    try {
      final profile = await _authService
          .registerCustomer(
            email: email,
            password: password,
            fullName: fullName,
            phone: phone,
            address: address,
          )
          .timeout(const Duration(seconds: 15));
      _setAuthenticated(profile);
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    }
  }

  /// Login
  Future<bool> login(String email, String password) async {
    _setLoading();
    if (!SupabaseService.isInitialized) {
      _setError('Unable to connect to server. Please check internet connection.');
      return false;
    }
    try {
      final profile = await _authService
          .login(email, password)
          .timeout(const Duration(seconds: 15));
      _setAuthenticated(profile);
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _authService.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    _status = AuthStatus.unauthenticated;
    _userProfile = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Create rider account (Admin)
  Future<bool> createRider({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    try {
      final res = await _authService.createRiderAccount(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );
      return res['success'] == true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    }
  }

  /// Forgot password
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordReset(email);
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    }
  }

  /// Update profile
  Future<bool> updateProfile({
    String? fullName,
    String? phone,
    String? address,
    String? avatarUrl,
  }) async {
    if (_userProfile == null) return false;
    try {
      await _authService.updateProfile(
        userId: _userProfile!.id,
        fullName: fullName,
        phone: phone,
        address: address,
        avatarUrl: avatarUrl,
      );
      _userProfile = _userProfile!.copyWith(
        fullName: fullName,
        phone: phone,
        address: address,
        avatarUrl: avatarUrl,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_cleanError(e));
      return false;
    }
  }

  /// Reload profile from DB
  Future<void> refreshProfile() async {
    final profile = await _authService.getCurrentProfile();
    if (profile != null) {
      _userProfile = profile;
      notifyListeners();
    }
  }

  String _cleanError(dynamic error) {
    final msg = error is AuthException ? error.message : error.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Please verify your email first.';
    }
    if (msg.contains('already been registered') || msg.contains('User already registered') || msg.contains('already registered')) {
      return 'This email is already registered.';
    }
    if (msg.contains('Password should be at least')) {
      return 'Password must be at least 6 characters.';
    }
    if (msg.contains('over_email_send_rate_limit') || msg.contains('rate limit')) {
      return 'Too many attempts. Please try again in a few moments.';
    }
    if (error is AuthException && error.message.isNotEmpty) {
      return error.message;
    }
    if (msg.startsWith('Exception: ')) {
      return msg.substring('Exception: '.length);
    }
    return msg.isNotEmpty ? msg : 'Something went wrong. Please try again.';
  }
}
