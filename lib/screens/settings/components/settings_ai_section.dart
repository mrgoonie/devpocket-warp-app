import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';
import 'settings_common_widgets.dart';
import '../api_key_screen.dart';

/// AI configuration section with status card and configuration option
class SettingsAISection extends StatelessWidget {
  final bool hasValidKey;
  final bool canUseAI;

  const SettingsAISection({
    super.key,
    required this.hasValidKey,
    required this.canUseAI,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(title: 'AI Features'),
        const SizedBox(height: 12),
        
        _AIStatusCard(
          hasValidKey: hasValidKey,
          canUseAI: canUseAI,
        ),
        
        SettingsCard(
          icon: hasValidKey ? Icons.psychology : Icons.psychology_outlined,
          title: 'AI Configuration',
          subtitle: hasValidKey 
              ? 'API key configured - AI features enabled'
              : 'Configure OpenRouter API key for AI features',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ApiKeyScreen()),
          ),
          trailing: hasValidKey 
              ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
              : const Icon(Icons.warning, color: Colors.orange, size: 20),
        ),
      ],
    );
  }
}

/// AI status card showing current AI features status
class _AIStatusCard extends StatelessWidget {
  final bool hasValidKey;
  final bool canUseAI;

  const _AIStatusCard({
    required this.hasValidKey,
    required this.canUseAI,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasValidKey
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasValidKey
                ? [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                  ]
                : [
                    Colors.orange.withValues(alpha: 0.1),
                    Colors.orange.withValues(alpha: 0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasValidKey ? Icons.psychology : Icons.warning,
                  color: hasValidKey ? AppTheme.primaryColor : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasValidKey ? 'AI Features Active' : 'AI Features Disabled',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: hasValidKey ? AppTheme.primaryColor : Colors.orange,
                        ),
                      ),
                      Text(
                        hasValidKey 
                            ? 'Agent Mode, Smart Suggestions, Error Explanations'
                            : 'Configure OpenRouter API key to enable',
                        style: TextStyle(
                          fontSize: 14,
                          color: (hasValidKey ? AppTheme.primaryColor : Colors.orange).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (hasValidKey && canUseAI) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Ready to assist with terminal commands',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}