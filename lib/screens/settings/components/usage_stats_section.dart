import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';
import '../../../providers/ai_provider.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';

/// Usage statistics section component showing AI usage metrics
class UsageStatsSection extends ConsumerWidget {
  final AIUsageStats usage;

  const UsageStatsSection({
    super.key,
    required this.usage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Row(
              children: [
                const Icon(
                  Icons.analytics,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Usage Statistics',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => ref.read(aiUsageProvider.notifier).resetStats(),
                  child: const Text('Reset'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _UsageStat(
                    label: 'Requests',
                    value: usage.requestCount.toString(),
                    icon: Icons.send,
                  ),
                ),
                Expanded(
                  child: _UsageStat(
                    label: 'Tokens',
                    value: '${(usage.tokenCount / 1000).toStringAsFixed(1)}K',
                    icon: Icons.token,
                  ),
                ),
                Expanded(
                  child: _UsageStat(
                    label: 'Cost',
                    value: '\$${usage.estimatedCost.toStringAsFixed(3)}',
                    icon: Icons.attach_money,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual usage statistic component
class _UsageStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _UsageStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}