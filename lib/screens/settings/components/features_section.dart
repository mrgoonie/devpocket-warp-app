import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/ai_provider.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';

/// AI features configuration section component
class FeaturesSection extends ConsumerWidget {
  const FeaturesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(aiFeatureSettingsProvider);
    
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
                  Icons.tune,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'AI Features',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            _FeatureToggle(
              title: 'Agent Mode',
              subtitle: 'Natural language to commands',
              value: settings.agentModeEnabled,
              onChanged: () => ref.read(aiFeatureSettingsProvider.notifier).toggleAgentMode(),
            ),
            
            _FeatureToggle(
              title: 'Auto Error Explanation',
              subtitle: 'Automatically explain command failures',
              value: settings.autoErrorExplanation,
              onChanged: () => ref.read(aiFeatureSettingsProvider.notifier).toggleAutoErrorExplanation(),
            ),
            
            _FeatureToggle(
              title: 'Smart Suggestions',
              subtitle: 'Context-aware command suggestions',
              value: settings.smartSuggestionsEnabled,
              onChanged: () => ref.read(aiFeatureSettingsProvider.notifier).toggleSmartSuggestions(),
            ),
            
            _FeatureToggle(
              title: 'Caching',
              subtitle: 'Cache responses to reduce costs',
              value: settings.cachingEnabled,
              onChanged: () => ref.read(aiFeatureSettingsProvider.notifier).toggleCaching(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual feature toggle component
class _FeatureToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onChanged;

  const _FeatureToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          Switch(
            value: value,
            onChanged: (_) => onChanged(),
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}