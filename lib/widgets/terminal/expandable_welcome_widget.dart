import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../services/terminal_viewport_manager.dart';

/// An expandable welcome message widget that provides progressive content disclosure.
/// 
/// Features:
/// - Intelligent content truncation with show more/less functionality
/// - Fade-out visual effect for truncated content
/// - Responsive behavior based on content length and screen size
/// - Smooth expand/collapse animations
class ExpandableWelcomeWidget extends ConsumerStatefulWidget {
  final String content;
  final int maxLines;
  final Duration animationDuration;
  final Curve animationCurve;

  const ExpandableWelcomeWidget({
    super.key,
    required this.content,
    this.maxLines = 10,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeInOutCubic,
  });

  @override
  ConsumerState<ExpandableWelcomeWidget> createState() => _ExpandableWelcomeWidgetState();
}

class _ExpandableWelcomeWidgetState extends ConsumerState<ExpandableWelcomeWidget>
    with SingleTickerProviderStateMixin {
  
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: widget.animationCurve,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Checks if the content needs truncation based on line count
  bool get _needsTruncation {
    final lines = widget.content.split('\n');
    return lines.length > widget.maxLines;
  }

  /// Gets the truncated content up to maxLines
  String get _truncatedContent {
    final lines = widget.content.split('\n');
    if (lines.length <= widget.maxLines) {
      return widget.content;
    }
    return lines.take(widget.maxLines).join('\n');
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = ref.watch(fontFamilyProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final scaledFontSize = fontSize * TerminalViewportManager.getFontSizeScale(context);
    
    final constraints = TerminalViewportManager.calculateWelcomeConstraints(
      context,
      content: widget.content,
      fontSize: scaledFontSize,
      isExpandable: true,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: TerminalViewportManager.getResponsivePadding(context),
      constraints: constraints,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border.all(color: AppTheme.darkBorderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Use minimum space needed
        children: [
          // Header
          const Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.terminalBlue,
              ),
              SizedBox(width: 6),
              Text(
                'Welcome Message',
                style: TextStyle(
                  color: AppTheme.terminalBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Content with expansion animation - wrapped in Flexible to prevent overflow
          Flexible(
            child: AnimatedBuilder(
              animation: _expandAnimation,
              builder: (context, child) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Content display - wrapped in Flexible
                    Flexible(
                      child: Stack(
                        children: [
                          // Main content
                          SelectableText(
                            _isExpanded ? widget.content : _truncatedContent,
                            style: TextStyle(
                              color: AppTheme.darkTextPrimary,
                              fontSize: scaledFontSize * 0.8,
                              fontFamily: fontFamily,
                              height: 1.4,
                            ),
                          ),

                          // Fade-out overlay for truncated content
                          if (!_isExpanded && _needsTruncation)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      AppTheme.darkSurface.withOpacity(0.0),
                                      AppTheme.darkSurface.withOpacity(0.8),
                                      AppTheme.darkSurface,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Show more/less button
                    if (_needsTruncation)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: AnimatedRotation(
                          turns: _expandAnimation.value * 0.5,
                          duration: widget.animationDuration,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _toggleExpanded,
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _isExpanded ? 'Show Less' : 'Show More',
                                      style: TextStyle(
                                        color: AppTheme.terminalBlue,
                                        fontSize: scaledFontSize * 0.75,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    AnimatedRotation(
                                      turns: _isExpanded ? 0.5 : 0.0,
                                      duration: widget.animationDuration,
                                      child: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: AppTheme.terminalBlue,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}