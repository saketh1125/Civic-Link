/// Splash Screen
///
/// Shows app logo centered. Restores session on init.
/// Routes to Dashboard if authenticated, Login if not.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../providers/auth_provider.dart';
import 'dashboard_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _restoreAndNavigate();
  }

  Future<void> _restoreAndNavigate() async {
    await ref.read(authProvider.notifier).restoreSession();

    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.isAuthenticated) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPrimaryBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: kAccentGreen.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: kAccentGreen.withOpacity(0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.security,
                color: kAccentGreen,
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'CIVIC-LINK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Traffic Police • Pooling Platform',
              style: TextStyle(
                color: kHintGrey,
                fontSize: 13,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(color: kAccentGreen),
          ],
        ),
      ),
    );
  }
}
