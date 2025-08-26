import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../themes/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../services/terminal_viewport_manager.dart';

/// A scrollable container widget for displaying welcome messages that may exceed viewport height.
/// 
/// Features:
/// - Automatic scrolling to bottom for new content
/// - Responsive height constraints based on viewport
/// - Smooth scroll animations
/// - Performance optimization for large content
class ScrollableWelcomeContainer extends ConsumerStatefulWidget {
  final String content;
  final bool autoScrollToBottom;
  final Duration scrollAnimationDuration;
  final Curve scrollAnimationCurve;

  const ScrollableWelcomeContainer({
    super.key,
    required this.content,
    this.autoScrollToBottom = true,
    this.scrollAnimationDuration = const Duration(milliseconds: 300),
    this.scrollAnimationCurve = Curves.easeOutCubic,
  });

  @override
  ConsumerState<ScrollableWelcomeContainer> createState() => _ScrollableWelcomeContainerState();
}

class _ScrollableWelcomeContainerState extends ConsumerState<ScrollableWelcomeContainer>
    with TickerProviderStateMixin {
  
  late ScrollController _scrollController;
  bool _isUserScrolling = false;
  bool _showScrollIndicator = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    
    // Listen for user scroll interactions
    _scrollController.addListener(_handleScrollChange);
    
    // Auto-scroll to bottom after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollToBottomIfNeeded();
    });
  }

  @override
  void didUpdateWidget(ScrollableWelcomeContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Auto-scroll when content changes (if enabled)
    if (oldWidget.content != widget.content && widget.autoScrollToBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoScrollToBottomIfNeeded();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScrollChange() {
    if (!_scrollController.hasClients) return;
    
    final isAtBottom = _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 50; // 50px tolerance
    
    setState(() {
      _isUserScrolling = !isAtBottom;
      _showScrollIndicator = _scrollController.position.maxScrollExtent > 
          _scrollController.position.viewportDimension;
    });
  }

  void _autoScrollToBottomIfNeeded() {
    if (!mounted || !_scrollController.hasClients) return;
    if (!widget.autoScrollToBottom || _isUserScrolling) return;

    // Smooth scroll to bottom
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: widget.scrollAnimationDuration,
      curve: widget.scrollAnimationCurve,
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: widget.scrollAnimationDuration,
      curve: widget.scrollAnimationCurve,
    );
    
    setState(() {
      _isUserScrolling = false;
    });
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
      child: Stack(
        children: [
          // Scrollable content
          Scrollbar(
            controller: _scrollController,
            thumbVisibility: _showScrollIndicator,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  
                  // Content
                  SelectableText(
                    widget.content,
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                      fontSize: scaledFontSize * 0.8, // Slightly smaller for welcome message
                      fontFamily: fontFamily,
                      height: 1.4, // Line height for better readability
                    ),
                  ),
                  
                  // Bottom padding for better scroll experience
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          
          // Scroll to bottom button (when user has scrolled up)
          if (_isUserScrolling && _showScrollIndicator)
            Positioned(
              right: 8,
              bottom: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _scrollToBottom,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.terminalBlue.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}