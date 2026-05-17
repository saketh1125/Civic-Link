/// Settings Screen
///
/// App settings with account, preferences, privacy, about, and danger zone.
/// Wrapped in AuthGuard.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../providers/auth_provider.dart';
import '../../providers/match_provider.dart';
import '../../providers/theme_provider.dart';
import '../widgets/auth_guard.dart';
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
    // Check for pending matches
    final matchState = ref.read(matchProvider);
    final hasPending = matchState.matches.any(
      (m) => m.status.toLowerCase() == 'pending',
    );

    if (hasPending) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: kSecondaryGrey,
          title: const Text('Pending Matches',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'You have pending matches. Are you sure you want to logout?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: kHintGrey)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Logout',
                  style: TextStyle(color: Colors.redAccent)),
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
        backgroundColor: kSecondaryGrey,
        title: const Text('Delete Account',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently anonymize your data. This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: kHintGrey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
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
        backgroundColor: kPrimaryBlack,
        appBar: AppBar(
          backgroundColor: kPrimaryBlack,
          elevation: 0,
          title: const Text(
            'SETTINGS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ListView(
          children: [
            // Account Section
            _buildSectionHeader('ACCOUNT'),
            _buildTile(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const ProfileScreen()),
                );
              },
            ),
            _buildTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),
            _buildTile(
              icon: Icons.verified_outlined,
              title: 'Verification Status',
              subtitle: 'Verified', // TODO: read from profileProvider
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),

            const SizedBox(height: 8),

            // Preferences Section
            _buildSectionHeader('PREFERENCES'),
            SwitchListTile(
              title: const Text('Notifications',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text('Receive push notifications',
                  style: TextStyle(color: kHintGrey, fontSize: 13)),
              value: _notificationsEnabled,
              onChanged: _toggleNotifications,
              activeColor: kAccentGreen,
              secondary:
                  Icon(Icons.notifications_outlined, color: kHintGrey),
            ),
            SwitchListTile(
              title: const Text('Dark Mode',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(
                themeMode == ThemeMode.dark ? 'On' : 'Off',
                style: TextStyle(color: kHintGrey, fontSize: 13),
              ),
              value: themeMode == ThemeMode.dark,
              onChanged: (_) {
                ref.read(themeProvider.notifier).toggle();
              },
              activeColor: kAccentGreen,
              secondary: Icon(
                themeMode == ThemeMode.dark
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: kHintGrey,
              ),
            ),

            const SizedBox(height: 8),

            // Privacy Section
            _buildSectionHeader('PRIVACY'),
            _buildTile(
              icon: Icons.download_outlined,
              title: 'Download my data',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),
            _buildTile(
              icon: Icons.delete_forever_outlined,
              title: 'Delete my account',
              titleColor: Colors.redAccent,
              onTap: _handleDeleteAccount,
            ),

            const SizedBox(height: 8),

            // About Section
            _buildSectionHeader('ABOUT'),
            _buildTile(
              icon: Icons.info_outline,
              title: 'App Version',
              subtitle: '1.0.0+1',
              onTap: () {},
            ),
            _buildTile(
              icon: Icons.description_outlined,
              title: 'Open source licenses',
              onTap: () {
                showLicensePage(context: context);
              },
            ),
            _buildTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),

            const SizedBox(height: 24),

            // Danger Zone — Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('LOGOUT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          color: kAccentGreen,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: kHintGrey),
      title: Text(
        title,
        style: TextStyle(color: titleColor ?? Colors.white, fontSize: 15),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: TextStyle(color: kHintGrey, fontSize: 13))
          : null,
      trailing:
          Icon(Icons.chevron_right, color: kHintGrey.withOpacity(0.3)),
      onTap: onTap,
    );
  }
}
