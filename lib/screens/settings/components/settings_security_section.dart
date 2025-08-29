import 'package:flutter/material.dart';
import 'settings_common_widgets.dart';

/// Security settings section with password change option
class SettingsSecuritySection extends StatelessWidget {
  const SettingsSecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Security'),
        const SizedBox(height: 12),
        
        SettingsCard(
          icon: Icons.lock,
          title: 'Change Password',
          subtitle: 'Update your account password',
          onTap: () => _showChangePasswordDialog(context),
        ),
      ],
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change password feature coming soon!')),
    );
  }
}