import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/supabase_service.dart';
import '../../models/user_profile.dart';
import '../constants/app_constants.dart';

class AuthService {
  SupabaseClient get _client => SupabaseService.client;

  /// Helper to auto-confirm a user by their user ID via Supabase Admin API
  Future<bool> _autoConfirmUser(String userId) async {
    if (AppConstants.supabaseSecretKey.isEmpty) return false;
    try {
      final res = await http.put(
        Uri.parse('${AppConstants.supabaseUrl}/auth/v1/admin/users/$userId'),
        headers: {
          'apikey': AppConstants.supabaseSecretKey,
          'Authorization': 'Bearer ${AppConstants.supabaseSecretKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email_confirm': true}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Helper to auto-confirm an unconfirmed user by matching email
  Future<bool> _autoConfirmByEmail(String email) async {
    if (AppConstants.supabaseSecretKey.isEmpty) return false;
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.supabaseUrl}/auth/v1/admin/users'),
        headers: {
          'apikey': AppConstants.supabaseSecretKey,
          'Authorization': 'Bearer ${AppConstants.supabaseSecretKey}',
        },
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final users = data['users'] as List<dynamic>? ?? [];
        for (final u in users) {
          final uEmail = (u['email'] as String? ?? '').toLowerCase();
          if (uEmail == email.toLowerCase()) {
            final uid = u['id'] as String;
            return await _autoConfirmUser(uid);
          }
        }
      }
    } catch (_) {}
    return false;
  }

  /// Register a new customer
  Future<UserProfile> registerCustomer({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String address,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
    final cleanPhone = phone.trim();
    final cleanAddress = address.trim();

    String? createdUserId;

    // 1. Attempt admin user creation first (auto-confirms email and avoids SMTP rate limit)
    if (AppConstants.supabaseSecretKey.isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('${AppConstants.supabaseUrl}/auth/v1/admin/users'),
          headers: {
            'apikey': AppConstants.supabaseSecretKey,
            'Authorization': 'Bearer ${AppConstants.supabaseSecretKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': cleanEmail,
            'password': password,
            'email_confirm': true,
            'user_metadata': {
              'full_name': cleanName,
              'phone': cleanPhone,
              'address': cleanAddress,
              'role': AppConstants.roleCustomer,
            },
          }),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          createdUserId = data['id'] as String?;
        } else if (res.statusCode == 422 || res.statusCode == 400) {
          final body = jsonDecode(res.body);
          final msg = body['msg'] ?? body['message'] ?? '';
          if (msg.toString().toLowerCase().contains('already')) {
            throw Exception('This email is already registered.');
          }
        }
      } catch (e) {
        if (e.toString().contains('already registered')) rethrow;
        // If admin create had an issue, fallback to client signUp below
      }
    }

    // 2. If admin creation did not create the user, fallback to client signUp
    if (createdUserId == null) {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'full_name': cleanName,
          'phone': cleanPhone,
          'address': cleanAddress,
          'role': AppConstants.roleCustomer,
        },
      );

      if (response.user == null) {
        throw Exception('Registration failed. Please try again.');
      }
      createdUserId = response.user!.id;
      // Auto-confirm the user in case Supabase required email confirmation
      await _autoConfirmUser(createdUserId);
    }

    // 3. Authenticate with client to obtain an active session in local storage
    try {
      await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
    } catch (e) {
      if (e is AuthException &&
          (e.message.toLowerCase().contains('email not confirmed') ||
              e.code?.toLowerCase().contains('email_not_confirmed') == true)) {
        await _autoConfirmUser(createdUserId);
        await _client.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );
      }
    }

    // 4. Wait briefly for database trigger and fetch the profile
    await Future.delayed(const Duration(milliseconds: 400));
    return await _fetchProfile(createdUserId);
  }

  /// Login existing user
  Future<UserProfile> login(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();

    try {
      final response = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Invalid email or password.');
      }

      return await _fetchProfile(response.user!.id);
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      final code = (e.code ?? '').toLowerCase();
      // If Supabase blocked login because the email was not confirmed, auto-confirm and retry
      if (msg.contains('email not confirmed') || code.contains('email_not_confirmed')) {
        final confirmed = await _autoConfirmByEmail(cleanEmail);
        if (confirmed) {
          final retryResponse = await _client.auth.signInWithPassword(
            email: cleanEmail,
            password: password,
          );
          if (retryResponse.user != null) {
            return await _fetchProfile(retryResponse.user!.id);
          }
        }
      }
      rethrow;
    }
  }

  /// Fetch profile from DB with automatic fallback
  Future<UserProfile> _fetchProfile(String userId) async {
    // Retry up to 3 times to allow PostgreSQL trigger to populate profile
    for (int i = 0; i < 3; i++) {
      try {
        final data = await _client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (data != null) {
          return UserProfile.fromJson(data);
        }
      } catch (_) {}
      if (i < 2) await Future.delayed(const Duration(milliseconds: 300));
    }

    // Fallback: construct profile from auth.user metadata if profiles row is not found
    final user = _client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    final email = user?.email ?? '';
    final fullName = metadata['full_name'] as String? ?? (email.isNotEmpty ? email.split('@').first : 'User');
    final role = metadata['role'] as String? ?? AppConstants.roleCustomer;
    final phone = metadata['phone'] as String? ?? '';
    final address = metadata['address'] as String? ?? '';

    // Attempt to persist the profile record to the database
    try {
      await _client.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'role': role,
        'is_active': true,
      });
    } catch (_) {}

    return UserProfile(
      id: userId,
      fullName: fullName,
      email: email,
      phone: phone,
      address: address,
      role: role,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  /// Get current user profile
  Future<UserProfile?> getCurrentProfile() async {
    final user = SupabaseService.currentUser;
    if (user == null) return null;
    try {
      return await _fetchProfile(user.id);
    } catch (_) {
      return null;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _client.auth.signOut().timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Create a new rider account (Admin)
  Future<Map<String, dynamic>> createRiderAccount({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();
    final cleanPhone = phone.trim();

    String? createdUserId;

    // 1. Attempt admin user creation first via Supabase Admin API
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.supabaseUrl}/auth/v1/admin/users'),
        headers: {
          'apikey': AppConstants.supabaseSecretKey,
          'Authorization': 'Bearer ${AppConstants.supabaseSecretKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': cleanEmail,
          'password': password,
          'email_confirm': true,
          'user_metadata': {
            'full_name': cleanName,
            'phone': cleanPhone,
            'address': 'Rider',
            'role': AppConstants.roleRider,
          },
        }),
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        createdUserId = data['id'] as String?;
      }
    } catch (_) {}

    // 2. Fallback: Create via client auth signUp
    if (createdUserId == null) {
      try {
        final tempClient = SupabaseClient(
          AppConstants.supabaseUrl,
          AppConstants.supabaseAnonKey,
          authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
        );
        final response = await tempClient.auth.signUp(
          email: cleanEmail,
          password: password,
          data: {
            'full_name': cleanName,
            'phone': cleanPhone,
            'address': 'Rider',
            'role': AppConstants.roleRider,
          },
        ).timeout(const Duration(seconds: 8));

        createdUserId = response.user?.id;
        if (createdUserId != null) {
          await _autoConfirmUser(createdUserId);
        }
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('already')) {
          // If not already registered, log and proceed to check profile
        }
      }
    }

    // 3. If user already exists in auth, find existing profile ID
    if (createdUserId == null) {
      try {
        final existing = await SupabaseService.adminClient
            .from('profiles')
            .select('id')
            .eq('email', cleanEmail)
            .maybeSingle();
        if (existing != null) {
          createdUserId = existing['id'] as String?;
        }
      } catch (_) {
        try {
          final existing = await _client
              .from('profiles')
              .select('id')
              .eq('email', cleanEmail)
              .maybeSingle();
          if (existing != null) {
            createdUserId = existing['id'] as String?;
          }
        } catch (_) {}
      }
    }

    // 4. Ensure profile row exists and has role 'rider' and is_active = true
    final now = DateTime.now().toIso8601String();
    final profileData = <String, dynamic>{
      if (createdUserId != null) 'id': createdUserId,
      'full_name': cleanName,
      'email': cleanEmail,
      'phone': cleanPhone,
      'address': 'Rider',
      'role': AppConstants.roleRider,
      'is_active': true,
      'updated_at': now,
    };

    bool profileSaved = false;
    try {
      await SupabaseService.adminClient.from('profiles').upsert(profileData);
      profileSaved = true;
    } catch (_) {
      try {
        await _client.from('profiles').upsert(profileData);
        profileSaved = true;
      } catch (_) {}
    }

    if (createdUserId != null || profileSaved) {
      return {
        'success': true,
        'id': createdUserId,
        'email': cleanEmail,
        'full_name': cleanName,
      };
    } else {
      throw Exception('Failed to create rider account. Please verify details and try again.');
    }
  }

  /// Forgot password
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  /// Update password
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Update profile
  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? address,
    String? avatarUrl,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (address != null) updates['address'] = address;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    await _client.from('profiles').update(updates).eq('id', userId);
  }
}
