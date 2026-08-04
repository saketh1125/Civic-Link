/// Civic-Link — application entry point.
///
/// Initialises Sentry (if DSN provided), then launches the app
/// with SplashScreen as the initial route. Theme is driven by
/// `AppTheme` (light + dark) via `themeProvider`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'core/design/app_decoration.dart';
import 'core/design/app_spacing.dart';
import 'core/design/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/registration_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/widgets/auth_header.dart';
import 'ui/widgets/error_banner.dart';
import 'ui/widgets/neon_button.dart';
import 'ui/widgets/password_field.dart';

export 'core/design/app_colors.dart';

// =============================================================================
// APP-WIDE CONSTANTS
// =============================================================================

/// Base URL for the Civic-Link backend API.
/// Override at build time: `flutter run --dart-define=BASE_URL=https://api.example.com`
const kBaseUrl = String.fromEnvironment(
  'BASE_URL',
  defaultValue: 'http://192.168.1.10:8000',
);

// =============================================================================
// ENTRY POINT
// =============================================================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  const environment =
      String.fromEnvironment('FLUTTER_ENV', defaultValue: 'development');

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.environment = environment;
      options.tracesSampleRate = 0.2;
      options.profilesSampleRate = 0.1;
      options.attachScreenshot = true;
      options.attachViewHierarchy = true;
      options.enableAutoSessionTracking = true;
    },
    appRunner: () => runApp(
      ProviderScope(
        child: MyApp(authService: AuthService(baseUrl: kBaseUrl)),
      ),
    ),
  );
}

// =============================================================================
// ROOT APPLICATION WIDGET
// =============================================================================

class MyApp extends StatelessWidget {
  final AuthService authService;

  const MyApp({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final themeMode = ref.watch(themeProvider);
        return MaterialApp(
          title: 'Civic-Link',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// =============================================================================
// LOGIN SCREEN
// =============================================================================

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _serverError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _serverError = null;
    });

    final notifier = ref.read(authProvider.notifier);
    final result = await notifier.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      setState(() {
        _serverError = result.errorMessage ?? 'Login failed. Try again.';
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.authPaddingH,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeader(),

                  const SizedBox(height: AppSpacing.huge),

                  // ---- Form ----
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'officer@police.gov.in',
                            prefixIcon:
                                Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                .hasMatch(value.trim())) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppSpacing.l),

                        // Password
                        PasswordField(
                          controller: _passwordController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _onLoginPressed(),
                        ),

                        const SizedBox(height: AppSpacing.m),

                        // Server error
                        if (_serverError != null) ...[
                          ErrorBanner(
                            message: _serverError!,
                            onDismiss: () =>
                                setState(() => _serverError = null),
                          ),
                          const SizedBox(height: AppSpacing.l),
                        ] else
                          const SizedBox(height: AppSpacing.l),

                        // Submit
                        NeonButton(
                          label: 'SECURE LOGIN',
                          icon: Icons.lock_open_rounded,
                          isLoading: _isLoading,
                          onPressed: _onLoginPressed,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.l),

                  // ---- Forgot Password ----
                  Center(
                    child: TextButton(
                      onPressed: () => _showResetDialog(context),
                      child: const Text('Forgot password?'),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s),

                  // ---- Registration Link ----
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const RegistrationScreen(),
                          ),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          children: [
                            TextSpan(
                              text: 'Register',
                              style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // ---- Footer ----
                  Center(
                    child: Text(
                      'CIVIC-LINK DPI',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showResetDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: const Text(
          'Password reset requires email verification. '
          'Please contact your HR administrator or use the '
          '"Change Password" option in Settings if you know '
          'your current password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
