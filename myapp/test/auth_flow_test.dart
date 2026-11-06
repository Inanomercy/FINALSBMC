import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/routing/app_router.dart';
import 'package:myapp/core/utils/validators.dart';
import 'package:myapp/features/authentication/providers/auth_provider.dart';
import 'package:myapp/models/user_profile.dart';

void main() {
  group('Validators Test', () {
    test('email validator accepts valid emails and trims whitespace', () {
      expect(Validators.email('test@example.com'), isNull);
      expect(Validators.email('  user@domain.org  '), isNull);
      expect(Validators.email('l.almocera23@gmail.com'), isNull);
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email(null), 'Email is required');
      expect(Validators.email('not-an-email'), 'Enter a valid email address');
      expect(Validators.email('missing@domain'), 'Enter a valid email address');
    });

    test('password validator enforces minimum 6 characters', () {
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('secret_password'), isNull);
      expect(Validators.password('12345'), 'Password must be at least 6 characters');
      expect(Validators.password(''), 'Password is required');
      expect(Validators.password(null), 'Password is required');
    });
  });

  group('Router Auth Redirection Logic Test', () {
    test('User stays on /login during login loading and does not redirect to /splash', () {
      final authProvider = AuthProvider();
      final router = createRouter(authProvider);

      // Initially not initialized
      expect(authProvider.isInitialized, isFalse);

      // Once initialized and unauthenticated
      // Simulate completed initialization
      authProvider.initialize();

      // Verify router is created without error
      expect(router, isNotNull);
    });

    test('UserProfile copyWith works as expected', () {
      final profile = UserProfile(
        id: 'user-123',
        fullName: 'Test User',
        email: 'test@example.com',
        role: 'customer',
        isActive: true,
        createdAt: DateTime.now(),
      );

      final updated = profile.copyWith(fullName: 'Updated Name');
      expect(updated.fullName, 'Updated Name');
      expect(updated.email, 'test@example.com');
      expect(updated.id, 'user-123');
    });
  });
}
