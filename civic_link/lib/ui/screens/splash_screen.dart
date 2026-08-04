/// Splash Screen
///
/// Animated logo entrance while the session is restored.
/// Routes to Dashboard if authenticated, Login if not.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_decoration.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import 'dashboard_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.standard);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.entrance),
    );

    _restoreAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _restoreAndNavigate() async {
    // Hold the splash for at least the animation length so it doesn't flash.
    final authFuture = ref.read(authProvider.notifier).restoreSession();
    await Future.wait([
      authFuture,
      Future<void>.delayed(AppMotion.splashHold),
    ]);

    if (!mounted) return;

    final authState = ref.read(authProvider);
    final next = authState.isAuthenticated
        ? const DashboardScreen() as Widget
        : const LoginScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AuthHeader(circleSize: 96, iconSize: 48),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
