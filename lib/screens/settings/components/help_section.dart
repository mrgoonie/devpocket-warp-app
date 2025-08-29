import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';

/// Help section component with links and privacy information
class HelpSection extends StatelessWidget {
  final VoidCallback onOpenRouterDocs;
  final VoidCallback onSupportedModels;
  final VoidCallback onPrivacyDialog;

  const HelpSection({
    super.key,
    required this.onOpenRouterDocs,
    required this.onSupportedModels,
    required this.onPrivacyDialog,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context.isDarkMode 
              ? AppTheme.darkBorderColor 
              : AppTheme.lightBorderColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.help,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Need Help?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _HelpItem(
              title: 'OpenRouter Documentation',
              subtitle: 'Learn about API usage and pricing',
              onTap: onOpenRouterDocs,
            ),
            
            _HelpItem(
              title: 'Supported Models',
              subtitle: 'View all available AI models',
              onTap: onSupportedModels,
            ),
            
            _HelpItem(
              title: 'Privacy & Security',
              subtitle: 'How we handle your API keys',
              onTap: onPrivacyDialog,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual help item component
class _HelpItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpItem({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}