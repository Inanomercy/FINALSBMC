import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/main.dart';
import 'package:myapp/features/authentication/screens/login_screen.dart';
import 'package:myapp/features/authentication/screens/splash_screen.dart';

void main() {
  testWidgets('App smoke test navigates from splash to login', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(SplashScreen), findsOneWidget);

    // Advance clock past splash delay and let animation / navigation finish
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Verify it navigated to LoginScreen and is NOT stuck on SplashScreen
    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
