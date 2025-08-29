import 'package:flutter/material.dart';
import 'settings_common_widgets.dart';

/// Support section with help, bug report, and rating options
class SettingsSupportSection extends StatelessWidget {
  const SettingsSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'Support'),
        const SizedBox(height: 12),
        
        SettingsCard(
          icon: Icons.help_outline,
          title: 'Help & Documentation',
          subtitle: 'Learn how to use DevPocket',
          onTap: _openDocumentation,
        ),
        
        SettingsCard(
          icon: Icons.bug_report,
          title: 'Report a Bug',
          subtitle: 'Help us improve DevPocket',
          onTap: () => _reportBug(context),
        ),
        
        SettingsCard(
          icon: Icons.star_outline,
          title: 'Rate DevPocket',
          subtitle: 'Love the app? Let us know!',
          onTap: _rateApp,
        ),
      ],
    );
  }

  void _openDocumentation() {
    // TODO: Open documentation URL
  }

  void _reportBug(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug report feature coming soon!')),
    );
  }

  void _rateApp() {
    // TODO: Open app store rating
  }
}