/// Auth Guard Widget
///
/// Watches authProvider and redirects to login if not authenticated.
/// Wraps all protected screens.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../main.dart';

class AuthGuard extends ConsumerStatefulWidget {
  final Widget child;

  const AuthGuard({super.key, required this.child});

  @override
  ConsumerState<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends ConsumerState<AuthGuard> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authState = ref.read(authProvider);

    if (!authState.isAuthenticated || authState.accessToken == null) {
      _redirect();
      return;
    }

    final valid = await ref.read(authProvider.notifier).checkSessionValidity();
    if (!valid) {
      _redirect();
      return;
    }

    if (mounted) {
      setState(() => _checking = false);
    }
  }

  void _redirect() {
    ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: kPrimaryBlack,
        body: Center(
          child: CircularProgressIndicator(color: kAccentGreen),
        ),
      );
    }
    return widget.child;
  }
}
