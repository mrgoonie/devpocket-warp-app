import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';

/// Section header component for settings screen
class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

/// Generic settings card component
class SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showArrow;
  final Widget? trailing;

  const SettingsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showArrow = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.darkTextSecondary,
          ),
        ),
        trailing: trailing ?? (showArrow 
            ? const Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary)
            : null),
        onTap: onTap,
      ),
    );
  }
}