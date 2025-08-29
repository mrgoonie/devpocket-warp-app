import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';

/// Common section container widget for SSH key details
class SshKeySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const SshKeySection({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Common info row widget for displaying label-value pairs
class SshKeyInfoRow extends StatelessWidget {
  final String label;
  final dynamic value;

  const SshKeyInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: value is Widget
                ? value
                : SelectableText(
                    value.toString(),
                    style: context.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w400,
                      color: context.isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}