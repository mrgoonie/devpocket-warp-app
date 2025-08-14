import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ai_models.dart';
import '../themes/app_theme.dart';

class ErrorExplanationWidget extends StatefulWidget {
  final ErrorExplanation explanation;
  final Function(String)? onSuggestionTap;

  const ErrorExplanationWidget({
    super.key,
    required this.explanation,
    this.onSuggestionTap,
  });

  @override
  State<ErrorExplanationWidget> createState() => _ErrorExplanationWidgetState();
}

class _ErrorExplanationWidgetState extends State<ErrorExplanationWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.red.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Error Analysis',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.red,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Command that failed
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    '\$ ',
                    style: AppTheme.terminalTextStyle.copyWith(
                      color: Colors.red,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.explanation.originalCommand,
                      style: AppTheme.terminalTextStyle.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _copyToClipboard(widget.explanation.originalCommand),
                    icon: const Icon(Icons.copy, size: 16, color: Colors.red),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            
            // Explanation (always shown)
            const SizedBox(height: 12),
            Text(
              widget.explanation.explanation,
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
            
            // Expandable content
            if (_isExpanded) ...[
              // Potential Causes
              if (widget.explanation.potentialCauses.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Potential Causes:',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.explanation.potentialCauses.map(
                  (cause) => Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: Colors.red.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            cause,
                            style: TextStyle(
                              color: Colors.red.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              // Suggestions
              if (widget.explanation.suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Suggestions to Fix:',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.explanation.suggestions.asMap().entries.map(
                  (entry) {
                    final index = entry.key + 1;
                    final suggestion = entry.value;
                    final isCommand = _isLikelyCommand(suggestion);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                '$index',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              suggestion,
                              style: TextStyle(
                                color: Colors.red.withValues(alpha: 0.9),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (isCommand) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                final command = _extractCommand(suggestion);
                                if (command.isNotEmpty) {
                                  widget.onSuggestionTap?.call(command);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.play_arrow,
                                      size: 12,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Try',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
              
              // Timestamp
              const SizedBox(height: 12),
              Text(
                'Analysis generated at ${_formatTime(widget.explanation.timestamp)}',
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isLikelyCommand(String suggestion) {
    // Simple heuristic to detect if a suggestion contains a command
    return suggestion.contains('try running') ||
           suggestion.contains('run ') ||
           suggestion.contains('use ') ||
           suggestion.contains('execute ') ||
           suggestion.contains('`') ||
           suggestion.contains('\$');
  }

  String _extractCommand(String suggestion) {
    // Try to extract command from various formats
    // Look for commands in backticks
    final backtickMatch = RegExp(r'`([^`]+)`').firstMatch(suggestion);
    if (backtickMatch != null) {
      return backtickMatch.group(1) ?? '';
    }
    
    // Look for commands after "try running", "run", etc.
    final patterns = [
      RegExp(r'try running\s+(.+?)(?:\s|$|\.)', caseSensitive: false),
      RegExp(r'run\s+(.+?)(?:\s|$|\.)', caseSensitive: false),
      RegExp(r'use\s+(.+?)(?:\s|$|\.)', caseSensitive: false),
      RegExp(r'execute\s+(.+?)(?:\s|$|\.)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(suggestion);
      if (match != null) {
        return match.group(1)?.trim() ?? '';
      }
    }
    
    return '';
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red.withValues(alpha: 0.8),
      ),
    );
  }
}

// Compact version for inline display
class CompactErrorExplanationWidget extends StatelessWidget {
  final ErrorExplanation explanation;
  final VoidCallback? onExpand;

  const CompactErrorExplanationWidget({
    super.key,
    required this.explanation,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.help_outline,
                color: Colors.red,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Error Explanation',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onExpand != null) ...[
                const Spacer(),
                InkWell(
                  onTap: onExpand,
                  child: const Icon(
                    Icons.open_in_full,
                    color: Colors.red,
                    size: 16,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanation.explanation,
            style: TextStyle(
              color: Colors.red.withValues(alpha: 0.9),
              fontSize: 13,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (explanation.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${explanation.suggestions.length} suggestion${explanation.suggestions.length == 1 ? '' : 's'} available',
              style: TextStyle(
                color: Colors.red.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}