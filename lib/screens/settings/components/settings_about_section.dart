import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../themes/app_theme.dart';
import '../../auth/login_screen.dart';
import 'settings_common_widgets.dart';

/// About section with version info and logout button
class SettingsAboutSection extends ConsumerWidget {
  const SettingsAboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'About'),
        const SizedBox(height: 12),
        
        const SettingsCard(
          icon: Icons.info_outline,
          title: 'Version',
          subtitle: '1.0.0 (Build 100)',
          showArrow: false,
        ),
        
        const SizedBox(height: 32),
        
        _LogoutButton(onLogout: () => _handleLogout(context, ref)),
      ],
    );
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog first
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                // ignore: use_build_context_synchronously
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terminalRed,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

/// Logout button component
class _LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;

  const _LogoutButton({
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout, color: AppTheme.terminalRed),
        label: const Text(
          'Sign Out',
          style: TextStyle(color: AppTheme.terminalRed),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.terminalRed, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}