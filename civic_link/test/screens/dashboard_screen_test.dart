import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:civic_link/providers/auth_provider.dart';
import 'package:civic_link/ui/screens/dashboard_screen.dart';

import '../helpers/pump_app.dart';
import '../helpers/mock_providers.dart';

void main() {
  group('DashboardScreen', () {
    testWidgets('renders with authenticated state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() {
              final n = FakeAuthNotifier();
              n.setPreAuthenticated();
              return n;
            }),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('CIVIC SCORE'), findsOneWidget);
      expect(find.text('CRUISING'), findsOneWidget);
    });

    testWidgets('displays default score of 100', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() {
              final n = FakeAuthNotifier();
              n.setPreAuthenticated();
              return n;
            }),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('100.0'), findsOneWidget);
    });

  testWidgets('shows profile and settings buttons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() {
            final n = FakeAuthNotifier();
            n.setPreAuthenticated();
            return n;
          }),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

    testWidgets('shows collecting data when history is empty',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() {
              final n = FakeAuthNotifier();
              n.setPreAuthenticated();
              return n;
            }),
          ],
          child: MaterialApp(
            theme: buildAppTheme(),
            home: const DashboardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('COLLECTING DATA...'), findsOneWidget);
    });
  });
}
