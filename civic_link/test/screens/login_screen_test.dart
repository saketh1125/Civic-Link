import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:civic_link/main.dart';
import 'package:civic_link/providers/auth_provider.dart';
import 'package:civic_link/providers/civic_score_provider.dart';
import 'package:civic_link/services/auth_service.dart';
import 'package:civic_link/ui/screens/registration_screen.dart';

import '../helpers/pump_app.dart';
import '../helpers/mock_providers.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders email field, password field, and login button',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(FakeAuthNotifier.new),
            civicScoreProvider.overrideWith(FakeCivicScoreNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.widgetWithText(ElevatedButton, 'SECURE LOGIN'),
          findsOneWidget);
      expect(find.text('CIVIC-LINK'), findsOneWidget);
    });

    testWidgets('shows validation errors on empty submit', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(FakeAuthNotifier.new),
            civicScoreProvider.overrideWith(FakeCivicScoreNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'SECURE LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows validation error on invalid email', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(FakeAuthNotifier.new),
            civicScoreProvider.overrideWith(FakeCivicScoreNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0), 'notanemail');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'Password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'SECURE LOGIN'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Password is required'), findsNothing);
    });

    testWidgets('shows loading indicator during login', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() {
              final n = FakeAuthNotifier();
              n.setLoginResult(
                AuthResult.success(
                  LoginResponse(
                    accessToken: 'token',
                    refreshToken: 'refresh',
                    tokenType: 'bearer',
                    expiresIn: 3600,
                  ),
                ),
              );
              return n;
            }),
            civicScoreProvider.overrideWith(FakeCivicScoreNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0),
          'officer@police.gov.in');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'Password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'SECURE LOGIN'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays error banner on login failure', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() {
              final n = FakeAuthNotifier();
              n.setLoginResult(
                AuthResult.failure('Incorrect email or password.',
                    statusCode: 401),
              );
              return n;
            }),
            civicScoreProvider.overrideWith(FakeCivicScoreNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).at(0),
          'officer@police.gov.in');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'WrongPassword');

      await tester.tap(find.widgetWithText(ElevatedButton, 'SECURE LOGIN'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Incorrect email or password.'), findsOneWidget);
    });

    testWidgets('navigates to registration screen when link is tapped',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(FakeAuthNotifier.new),
            civicScoreProvider.overrideWith(FakeCivicScoreNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.tap(find.text("Don't have an account? Register"));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrationScreen), findsOneWidget);
    });

    testWidgets('shows snackbar on forgot password tap', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(FakeAuthNotifier.new),
            civicScoreProvider.overrideWith(FakeCivicScoreNotifier.new),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(find.text('Password reset coming soon.'), findsOneWidget);
    });
  });
}
