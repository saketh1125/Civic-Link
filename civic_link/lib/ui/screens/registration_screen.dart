/// Registration Screen
///
/// User registration form with Zero-Liability email hashing.
/// Fields: full name, email, password, confirm password, phone, gender.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../core/design/app_decoration.dart';
import '../../core/design/app_spacing.dart';
import '../../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/error_banner.dart';
import '../widgets/neon_button.dart';
import '../widgets/password_field.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedGender = 'male';
  bool _isLoading = false;
  String? _serverError;

  final _genders = ['male', 'female', 'undisclosed'];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _onRegisterPressed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _serverError = null;
    });

    final result = await ref.read(authProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          phoneNumber: _phoneController.text.trim(),
          fullName: _nameController.text.trim(),
          gender: _selectedGender,
          companyName: 'Civic-Link',
          employeeId: '',
        );

    if (!mounted) return;

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account created. Check your email to verify.'),
          backgroundColor: context.colors.primary,
        ),
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _serverError = result.errorMessage ?? 'Registration failed.';
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
      appBar: AppBar(leading: const BackButton()),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.authPaddingH,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(AppSpacing.xxl),
                    const AuthHeader(
                      iconSize: 28,
                      circleSize: 64,
                      titleSize: 24,
                      subtitle: 'Join the Civic-Link platform',
                    ),
                    const Gap(AppSpacing.xxl),

                    // ---- Full Name ----
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Name is required';
                        }
                        if (v.trim().length < 2) return 'Min 2 characters';
                        return null;
                      },
                    ),
                    const Gap(AppSpacing.l),

                    // ---- Email ----
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'user@cmrcet.ac.in',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                            .hasMatch(v.trim())) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const Gap(AppSpacing.l),

                    // ---- Password ----
                    PasswordField(
                      controller: _passwordController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 8) return 'Min 8 characters';
                        return null;
                      },
                    ),
                    const Gap(AppSpacing.l),

                    // ---- Confirm Password ----
                    PasswordField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) {
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const Gap(AppSpacing.l),

                    // ---- Phone ----
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '+91-98765-43210',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Phone is required';
                        }
                        return null;
                      },
                    ),
                    const Gap(AppSpacing.l),

                    // ---- Gender ----
                    DropdownButtonFormField<String>(
                      initialValue: _selectedGender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        prefixIcon: Icon(Icons.wc_rounded),
                      ),
                      items: _genders
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child:
                                  Text(g[0].toUpperCase() + g.substring(1)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedGender = v);
                      },
                    ),
                    const Gap(AppSpacing.l),

                    // ---- Error banner ----
                    if (_serverError != null) ...[
                      ErrorBanner(
                        message: _serverError!,
                        onDismiss: () => setState(() => _serverError = null),
                      ),
                      const Gap(AppSpacing.l),
                    ],

                    // ---- Register ----
                    NeonButton(
                      label: 'CREATE ACCOUNT',
                      icon: Icons.person_add_rounded,
                      isLoading: _isLoading,
                      onPressed: _onRegisterPressed,
                    ),
                    const Gap(AppSpacing.xl),

                    // ---- Login link ----
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text.rich(
                          TextSpan(
                            text: 'Already have an account? ',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                            children: [
                              TextSpan(
                                text: 'Sign in',
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
                    const Gap(AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
