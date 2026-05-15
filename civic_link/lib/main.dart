import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'services/auth_service.dart';
import 'ui/screens/dashboard_screen.dart';

// =============================================================================
// APP-WIDE CONSTANTS
// =============================================================================

/// Base URL for the Civic-Link backend API.
/// 10.0.2.2 = Android emulator loopback to host machine.
const kBaseUrl = 'http://192.168.1.9:8000';

/// Deep black — primary surface colour.
const kPrimaryBlack = Color(0xFF0A0A0A);

/// Neon green — primary accent / CTA colour.
const kAccentGreen = Color(0xFF00E676);

/// Subtle grey for secondary text and dividers.
const kSecondaryGrey = Color(0xFF1A1A2E);

/// Hint / muted text colour.
const kHintGrey = Color(0xFF6B6B80);

/// Input field fill colour.
const kInputFill = Color(0xFF141428);

// =============================================================================
// ENTRY POINT
// =============================================================================

/// Application entry point.
///
/// Ensures Flutter binding is initialised, then checks for a stored
/// authentication token to determine the initial route.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final authService = AuthService(baseUrl: kBaseUrl);
  final token = await authService.getAccessToken();

  runApp(
    ProviderScope(
      child: MyApp(
        isAuthenticated: token != null,
      ),
    ),
  );
}

// =============================================================================
// ROOT APPLICATION WIDGET
// =============================================================================

/// Root [MaterialApp] wrapped in [ProviderScope].
///
/// Routes to [DashboardScreen] if authenticated, otherwise [LoginScreen].
class MyApp extends StatelessWidget {
  /// Whether a valid auth token was found on startup.
  final bool isAuthenticated;

  const MyApp({
    super.key,
    required this.isAuthenticated,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Civic-Link',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kPrimaryBlack,
        colorScheme: ColorScheme.dark(
          primary: kAccentGreen,
          onPrimary: kPrimaryBlack,
          secondary: kAccentGreen,
          onSecondary: kPrimaryBlack,
          surface: kPrimaryBlack,
          onSurface: Colors.white,
          error: Colors.redAccent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kInputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          hintStyle: TextStyle(color: kHintGrey, fontSize: 15),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kAccentGreen,
            foregroundColor: kPrimaryBlack,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ),
        textTheme: TextTheme(
          headlineLarge: const TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -2,
          ),
          headlineMedium: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          bodyMedium: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
          labelSmall: TextStyle(
            color: kHintGrey,
            fontSize: 15,
          ),
        ),
        dividerColor: Colors.white.withOpacity(0.08),
      ),
      home: isAuthenticated ? const DashboardScreen() : const LoginScreen(),
    );
  }
}

// =============================================================================
// LOGIN SCREEN
// =============================================================================

/// A clean, full-screen login form.
///
/// Collects email and password, delegates authentication to [AuthService],
/// and navigates to [DashboardScreen] on success.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authService = AuthService(baseUrl: kBaseUrl);

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

    final result = await _authService.login(
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- Logo / Title ----
                  _buildHeader(),

                  const SizedBox(height: 48),

                  // ---- Form ----
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon:
                                const Icon(Icons.alternate_email, color: kHintGrey),
                            hintText: 'officer@police.gov.in',
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

                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon:
                                const Icon(Icons.lock_outline, color: kHintGrey),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        // Server error banner
                        if (_serverError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.red.shade900.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _serverError!,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Login button
                        SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed:
                                _isLoading ? null : _onLoginPressed,
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: kPrimaryBlack,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text('SECURE LOGIN'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ---- Footer ----
                  Center(
                    child: Text(
                      'Civic-Link DPI',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12,
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

  /// Top section with the app icon mark and title.
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: kAccentGreen.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: kAccentGreen.withOpacity(0.4), width: 2),
          ),
          child: Icon(
            Icons.security,
            color: kAccentGreen,
            size: 36,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'CIVIC-LINK',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Traffic Police • Pooling Platform',
          style: TextStyle(
            color: kHintGrey,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}