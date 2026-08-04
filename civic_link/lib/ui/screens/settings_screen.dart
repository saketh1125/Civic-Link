/// Settings Screen
///
/// Rebuilt on the shared design-system widgets:
/// SectionHeader + SettingsTile + SwitchListTile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design/app_decoration.dart';
import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/auth_guard.dart';
import '../widgets/section_header.dart';
import '../widgets/settings_tile.dart';
import 'change_password_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPref();
  }

  Future<void> _loadNotificationPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      });
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    if (mounted) {
      setState(() => _notificationsEnabled = value);
    }
  }

  Future<void> _handleLogout() async {
    final matchState = ref.read(matchProvider);
    final hasPending = matchState.matches.any(
      (m) => m.status.toLowerCase() == 'pending',
    );

    if (hasPending) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.warning_amber_rounded,
            color: context.colors.tertiary,
            size: 32,
          ),
          title: const Text('Pending Matches'),
          content: const Text(
            'You have pending matches. Are you sure you want to log out?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: context.colors.error,
              ),
              child: const Text('Logout'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.delete_forever_rounded,
          color: context.colors.error,
          size: 32,
        ),
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently anonymize your data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // TODO: Call anonymization endpoint when available
      ref.read(authProvider.notifier).logout();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Account deletion requested. You will receive a confirmation email.'),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return AuthGuard(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SETTINGS'),
          leading: const BackButton(),
        ),
        body: ListView(
          children: [
            // ---- Account -------------------------------------------------------
            const SectionHeader('Account'),
            SettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Edit Profile',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            SettingsTile(
              icon: Icons.lock_outline_rounded,
              title: 'Change Password',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen()),
              ),
            ),
            SettingsTile(
              icon: Icons.verified_outlined,
              title: 'Verification Status',
              subtitle: 'Verified',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon')),
              ),
            ),

            const Gap(8),

            // ---- Preferences ---------------------------------------------------
            const SectionHeader('Preferences'),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              subtitle: const Text('Receive push notifications'),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
            ),
            SwitchListTile(
              secondary: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
              ),
              title: const Text('Dark Mode'),
              subtitle: Text(themeMode == ThemeMode.dark ? 'On' : 'Off'),
              value: themeMode == ThemeMode.dark,
              onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
            ),

            const Gap(8),

            // ---- Privacy --------------------------------------------------------
            const SectionHeader('Privacy'),
            SettingsTile(
              icon: Icons.download_outlined,
              title: 'Download my data',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon')),
              ),
            ),
            SettingsTile(
              icon: Icons.delete_forever_outlined,
              title: 'Delete my account',
              isDestructive: true,
              onTap: _handleDeleteAccount,
            ),

            const Gap(8),

            // ---- About ----------------------------------------------------------
            const SectionHeader('About'),
            SettingsTile(
              icon: Icons.info_outline_rounded,
              title: 'App Version',
              subtitle: '1.0.0+1',
              onTap: () {},
            ),
            SettingsTile(
              icon: Icons.description_outlined,
              title: 'Open source licenses',
              onTap: () => showLicensePage(context: context),
            ),
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon')),
              ),
            ),

            // ---- Danger zone -------------------------------------------------------
            const Gap(32),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: FilledButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('LOGOUT'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.colors.error,
                  foregroundColor: context.colors.onError,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const Gap(24),
          ],
        ),
      ),
    );
  }
}
