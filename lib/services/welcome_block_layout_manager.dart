import 'package:flutter/material.dart';
import '../widgets/terminal/scrollable_welcome_container.dart';
import '../widgets/terminal/expandable_welcome_widget.dart';
import 'terminal_viewport_manager.dart';

/// Strategy enum for different welcome message layout approaches
enum WelcomeLayoutStrategy {
  /// Use standard container with basic overflow protection
  standard,
  /// Use scrollable container for long content
  scrollable,
  /// Use expandable widget with show more/less functionality
  expandable,
  /// Use hybrid approach - expandable with fallback to scrollable
  hybrid,
}

/// Service for managing welcome message layout and deciding optimal display strategy.
/// 
/// Provides intelligent layout decisions based on content characteristics,
/// device constraints, and user preferences.
class WelcomeBlockLayoutManager {
  
  /// Determines the optimal layout strategy for given welcome message content
  static WelcomeLayoutStrategy determineLayoutStrategy({
    required String content,
    required BuildContext context,
    double fontSize = 14.0,
  }) {
    if (content.isEmpty) return WelcomeLayoutStrategy.standard;

    final lines = content.split('\n');
    final lineCount = lines.length;
    final characterCount = content.length;
    final maxHeight = TerminalViewportManager.calculateMaxWelcomeHeight(context);
    final estimatedHeight = _estimateContentHeight(content, fontSize);
    
    // Decision matrix based on content characteristics
    if (characterCount < 500 && lineCount <= 5) {
      // Short content - use standard layout
      return WelcomeLayoutStrategy.standard;
    } else if (characterCount < 2000 && lineCount <= 15) {
      // Medium content - use expandable for better UX
      return WelcomeLayoutStrategy.expandable;
    } else if (estimatedHeight > maxHeight && lineCount > 20) {
      // Very long content - use hybrid approach
      return WelcomeLayoutStrategy.hybrid;
    } else {
      // Long content - use scrollable
      return WelcomeLayoutStrategy.scrollable;
    }
  }
  
  /// Estimates the rendered height of content based on character count and line breaks
  static double _estimateContentHeight(String content, double fontSize) {
    final lines = content.split('\n');
    const averageCharsPerLine = 80; // Approximate chars per line on mobile
    
    double totalLines = 0;
    for (final line in lines) {
      if (line.isEmpty) {
        totalLines += 1;
      } else {
        totalLines += (line.length / averageCharsPerLine).ceil();
      }
    }
    
    // Line height ~1.4x font size + padding
    return (totalLines * fontSize * 1.4) + 50; // +50 for header and padding
  }
  
  /// Creates the appropriate welcome widget based on layout strategy
  static Widget createWelcomeWidget({
    required String content,
    required BuildContext context,
    WelcomeLayoutStrategy? strategy,
  }) {
    final finalStrategy = strategy ?? determineLayoutStrategy(
      content: content,
      context: context,
    );
    
    switch (finalStrategy) {
      case WelcomeLayoutStrategy.standard:
        return _createStandardWelcome(content, context);
      
      case WelcomeLayoutStrategy.scrollable:
        return ScrollableWelcomeContainer(content: content);
      
      case WelcomeLayoutStrategy.expandable:
        return ExpandableWelcomeWidget(content: content);
      
      case WelcomeLayoutStrategy.hybrid:
        return _createHybridWelcome(content, context);
    }
  }
  
  /// Creates a standard welcome container with basic overflow protection
  static Widget _createStandardWelcome(String content, BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: TerminalViewportManager.getResponsivePadding(context),
      constraints: TerminalViewportManager.calculateWelcomeConstraints(
        context,
        content: content,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // AppTheme.darkSurface
        border: Border.all(color: const Color(0xFF333333)), // AppTheme.darkBorderColor
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Color(0xFF00A8E6), // AppTheme.terminalBlue
              ),
              SizedBox(width: 6),
              Text(
                'Welcome Message',
                style: TextStyle(
                  color: Color(0xFF00A8E6), // AppTheme.terminalBlue
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Content
          Flexible(
            child: SelectableText(
              content,
              style: const TextStyle(
                color: Color(0xFFE1E1E1), // AppTheme.darkTextPrimary
                fontSize: 11.2, // 14 * 0.8
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Creates a hybrid welcome widget that uses expandable with scrollable fallback
  static Widget _createHybridWelcome(String content, BuildContext context) {
    // For very long content, start with expandable but allow fallback to scrollable
    return ExpandableWelcomeWidget(
      content: content,
      maxLines: 15, // Show more lines initially for hybrid approach
    );
  }
  
  /// Analyzes welcome message content and provides layout recommendations
  static Map<String, dynamic> analyzeContent(String content) {
    final lines = content.split('\n');
    final words = content.split(' ');
    
    return {
      'characterCount': content.length,
      'lineCount': lines.length,
      'wordCount': words.length,
      'averageLineLength': lines.isEmpty ? 0 : content.length / lines.length,
      'hasLongLines': lines.any((line) => line.length > 120),
      'hasSpecialChars': content.contains(RegExp(r'[#$%^&*+=|\\/<>~`@]')),
      'estimatedReadingTime': (words.length / 200).ceil(), // ~200 words per minute
      'complexity': _calculateContentComplexity(content),
    };
  }
  
  /// Calculates content complexity score (0-10)
  static int _calculateContentComplexity(String content) {
    int complexity = 0;
    
    // Length factor
    if (content.length > 1000) complexity += 2;
    if (content.length > 5000) complexity += 3;
    
    // Line count factor
    final lineCount = content.split('\n').length;
    if (lineCount > 20) complexity += 2;
    if (lineCount > 50) complexity += 3;
    
    // Special characters (technical content)
    if (content.contains(RegExp(r'[\[\]{}()$#@%^&*+=|\\/<>~`]'))) complexity += 1;
    
    // Multiple spacing patterns (formatted output)
    if (content.contains(RegExp(r'\s{3,}'))) complexity += 1;
    
    return complexity.clamp(0, 10);
  }
  
  /// Provides performance recommendations for welcome message handling
  static Map<String, dynamic> getPerformanceRecommendations(String content) {
    final analysis = analyzeContent(content);
    final characterCount = analysis['characterCount'] as int;
    final lineCount = analysis['lineCount'] as int;
    final complexity = analysis['complexity'] as int;
    
    return {
      'shouldUseVirtualization': characterCount > 10000,
      'shouldUsePagination': lineCount > 100,
      'shouldLazyLoad': complexity > 7,
      'shouldCache': characterCount > 5000,
      'maxRecommendedChars': 10000,
      'performanceRisk': _assessPerformanceRisk(characterCount, lineCount, complexity),
    };
  }
  
  static String _assessPerformanceRisk(int charCount, int lineCount, int complexity) {
    if (charCount > 20000 || lineCount > 200 || complexity > 8) {
      return 'high';
    } else if (charCount > 5000 || lineCount > 50 || complexity > 5) {
      return 'medium';
    } else {
      return 'low';
    }
  }
}