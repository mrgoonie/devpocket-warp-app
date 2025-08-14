import 'package:flutter/material.dart';
import '../models/ai_models.dart';
import '../themes/app_theme.dart';

class CommandSuggestionWidget extends StatelessWidget {
  final CommandSuggestion suggestion;
  final VoidCallback? onExecute;
  final VoidCallback? onCopy;

  const CommandSuggestionWidget({
    super.key,
    required this.suggestion,
    this.onExecute,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Suggestion',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildConfidenceBadge(suggestion.confidence),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Command
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                suggestion.command,
                style: AppTheme.terminalTextStyle.copyWith(
                  color: AppTheme.terminalGreen,
                ),
              ),
            ),
            
            // Explanation
            if (suggestion.explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                suggestion.explanation,
                style: TextStyle(
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ],
            
            // Tags
            if (suggestion.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: suggestion.tags.map((tag) => Chip(
                  label: Text(
                    tag,
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                  side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
            ],
            
            // Actions
            const SizedBox(height: 16),
            Row(
              children: [
                if (onCopy != null) ...[
                  TextButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (onExecute != null) ...[
                  ElevatedButton.icon(
                    onPressed: onExecute,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('Execute'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    Color color = Colors.orange;
    String label = 'Low';
    
    if (confidence >= 0.8) {
      color = Colors.green;
      label = 'High';
    } else if (confidence >= 0.6) {
      color = Colors.orange;
      label = 'Medium';
    } else {
      color = Colors.red;
      label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label Confidence',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}