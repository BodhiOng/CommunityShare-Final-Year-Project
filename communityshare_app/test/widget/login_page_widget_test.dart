import 'package:communityshare_app/app/app_routes.dart';
import 'package:communityshare_app/constants.dart';
import 'package:communityshare_app/features/auth/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Widget buildLoginPage() {
    return MaterialApp(
      theme: buildAppTheme(),
      routes: {
        AppRoutes.register:
            (_) => const Scaffold(body: Text('Registration Page')),
      },
      home: const LoginPage(),
    );
  }

  testWidgets('TC1 open login page displays main controls', (tester) async {
    await tester.pumpWidget(buildLoginPage());
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text(AppCopy.appName), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Log in'), findsOneWidget);
  });

  testWidgets('TC2 tap login with empty fields shows validation messages', (
    tester,
  ) async {
    await tester.pumpWidget(buildLoginPage());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('TC3 invalid email shows valid email message', (tester) async {
    await tester.pumpWidget(buildLoginPage());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'bad');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
  });

  testWidgets('TC4 password visibility button toggles obscure state', (
    tester,
  ) async {
    await tester.pumpWidget(buildLoginPage());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('TC5 tapping Create account navigates to register route', (
    tester,
  ) async {
    await tester.pumpWidget(buildLoginPage());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Registration Page'), findsOneWidget);
  });
}
