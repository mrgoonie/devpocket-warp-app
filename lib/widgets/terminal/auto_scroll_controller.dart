import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

/// Intelligent auto-scroll controller for terminal views
/// Handles smooth scrolling with user override detection
class AutoScrollController extends ChangeNotifier {
  ScrollController? _scrollController;
  Timer? _scrollTimer;
  Timer? _userOverrideResetTimer;
  
  bool _autoScrollEnabled = true;
  bool _userOverrideActive = false;
  bool _isAnimating = false;
  double _lastMaxExtent = 0.0;
  double _scrollThreshold = 50.0; // Pixels from bottom to consider "at bottom"
  
  // Configuration
  Duration animationDuration = const Duration(milliseconds: 300);
  Curve animationCurve = Curves.easeOut;
  Duration userOverrideTimeout = const Duration(seconds: 5);
  Duration scrollDebounce = const Duration(milliseconds: 100);

  AutoScrollController({
    ScrollController? scrollController,
    bool autoScrollEnabled = true,
    double scrollThreshold = 50.0,
  }) : _autoScrollEnabled = autoScrollEnabled,
       _scrollThreshold = scrollThreshold {
    if (scrollController != null) {
      attachScrollController(scrollController);
    }
  }

  /// Current scroll controller
  ScrollController? get scrollController => _scrollController;
  
  /// Whether auto-scroll is enabled
  bool get autoScrollEnabled => _autoScrollEnabled;
  
  /// Whether user override is currently active
  bool get userOverrideActive => _userOverrideActive;
  
  /// Whether scrolling animation is in progress
  bool get isAnimating => _isAnimating;
  
  /// Whether currently at bottom of scroll view
  bool get isAtBottom {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return true;
    }
    
    final position = _scrollController!.position;
    return position.pixels >= (position.maxScrollExtent - _scrollThreshold);
  }

  /// Attach a scroll controller
  void attachScrollController(ScrollController scrollController) {
    if (_scrollController != null) {
      _scrollController!.removeListener(_onScrollChange);
    }
    
    _scrollController = scrollController;
    _scrollController!.addListener(_onScrollChange);
    _lastMaxExtent = _scrollController!.hasClients 
        ? _scrollController!.position.maxScrollExtent 
        : 0.0;
  }

  /// Detach current scroll controller
  void detachScrollController() {
    if (_scrollController != null) {
      _scrollController!.removeListener(_onScrollChange);
      _scrollController = null;
    }
  }

  /// Enable or disable auto-scroll
  void setAutoScrollEnabled(bool enabled) {
    if (_autoScrollEnabled != enabled) {
      _autoScrollEnabled = enabled;
      notifyListeners();
      
      if (enabled && !_userOverrideActive) {
        _scheduleScrollToBottom();
      }
    }
  }

  /// Manually scroll to bottom
  Future<void> scrollToBottom({
    Duration? duration,
    Curve? curve,
    bool force = false,
  }) async {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return;
    }

    if (!force && _userOverrideActive) {
      return; // Respect user override unless forced
    }

    _isAnimating = true;
    notifyListeners();

    try {
      await _scrollController!.animateTo(
        _scrollController!.position.maxScrollExtent,
        duration: duration ?? animationDuration,
        curve: curve ?? animationCurve,
      );
    } catch (e) {
      // Handle case where scroll controller is disposed
      debugPrint('Error during scroll animation: $e');
    } finally {
      _isAnimating = false;
      notifyListeners();
    }
  }

  /// Scroll to a specific position
  Future<void> scrollToPosition(
    double position, {
    Duration? duration,
    Curve? curve,
    bool triggerUserOverride = true,
  }) async {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return;
    }

    if (triggerUserOverride) {
      _triggerUserOverride();
    }

    _isAnimating = true;
    notifyListeners();

    try {
      await _scrollController!.animateTo(
        math.min(position, _scrollController!.position.maxScrollExtent),
        duration: duration ?? animationDuration,
        curve: curve ?? animationCurve,
      );
    } catch (e) {
      debugPrint('Error during scroll animation: $e');
    } finally {
      _isAnimating = false;
      notifyListeners();
    }
  }

  /// Scroll by a relative amount
  Future<void> scrollBy(
    double delta, {
    Duration? duration,
    Curve? curve,
    bool triggerUserOverride = true,
  }) async {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return;
    }

    final currentPosition = _scrollController!.position.pixels;
    final newPosition = currentPosition + delta;
    
    await scrollToPosition(
      newPosition,
      duration: duration,
      curve: curve,
      triggerUserOverride: triggerUserOverride,
    );
  }

  /// Force scroll to bottom regardless of user override
  Future<void> forceScrollToBottom({
    Duration? duration,
    Curve? curve,
  }) async {
    await scrollToBottom(
      duration: duration,
      curve: curve,
      force: true,
    );
  }

  /// Reset user override and enable auto-scroll
  void resetUserOverride() {
    _userOverrideResetTimer?.cancel();
    _userOverrideActive = false;
    notifyListeners();
    
    if (_autoScrollEnabled) {
      _scheduleScrollToBottom();
    }
  }

  /// Manually trigger user override
  void _triggerUserOverride() {
    if (!_userOverrideActive) {
      _userOverrideActive = true;
      notifyListeners();
    }
    
    // Reset the timeout timer
    _userOverrideResetTimer?.cancel();
    _userOverrideResetTimer = Timer(userOverrideTimeout, () {
      if (isAtBottom) {
        resetUserOverride();
      }
    });
  }

  /// Handle scroll changes
  void _onScrollChange() {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return;
    }

    final position = _scrollController!.position;
    final currentMaxExtent = position.maxScrollExtent;
    
    // Check if content size changed (new content added)
    if (currentMaxExtent > _lastMaxExtent && _autoScrollEnabled && !_userOverrideActive) {
      _scheduleScrollToBottom();
    }
    _lastMaxExtent = currentMaxExtent;
    
    // Detect user interaction
    if (position.isScrollingNotifier.value) {
      // Check if user scrolled away from bottom
      if (!isAtBottom && !_isAnimating) {
        _triggerUserOverride();
      }
      // If user scrolled back to bottom, reset override
      else if (isAtBottom && _userOverrideActive) {
        resetUserOverride();
      }
    }
  }

  /// Schedule scroll to bottom with debouncing
  void _scheduleScrollToBottom() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(scrollDebounce, () {
      if (_autoScrollEnabled && !_userOverrideActive) {
        scrollToBottom();
      }
    });
  }

  /// Get scroll metrics
  ScrollMetrics? getScrollMetrics() {
    if (_scrollController == null || !_scrollController!.hasClients) {
      return null;
    }
    return _scrollController!.position;
  }

  /// Get current scroll percentage (0.0 to 1.0)
  double getScrollPercentage() {
    final metrics = getScrollMetrics();
    if (metrics == null || metrics.maxScrollExtent == 0) {
      return 1.0; // Consider as "at bottom" when no scroll is possible
    }
    
    return math.min(1.0, metrics.pixels / metrics.maxScrollExtent);
  }

  /// Check if scroll view can scroll
  bool get canScroll {
    final metrics = getScrollMetrics();
    return metrics != null && metrics.maxScrollExtent > 0;
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _userOverrideResetTimer?.cancel();
    detachScrollController();
    super.dispose();
  }
}

/// Auto-scroll behavior configuration
class AutoScrollBehavior {
  final bool enableAutoScroll;
  final Duration animationDuration;
  final Curve animationCurve;
  final Duration userOverrideTimeout;
  final double scrollThreshold;
  final Duration scrollDebounce;
  final bool respectUserScroll;
  final bool smoothAnimation;

  const AutoScrollBehavior({
    this.enableAutoScroll = true,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOut,
    this.userOverrideTimeout = const Duration(seconds: 5),
    this.scrollThreshold = 50.0,
    this.scrollDebounce = const Duration(milliseconds: 100),
    this.respectUserScroll = true,
    this.smoothAnimation = true,
  });

  AutoScrollBehavior copyWith({
    bool? enableAutoScroll,
    Duration? animationDuration,
    Curve? animationCurve,
    Duration? userOverrideTimeout,
    double? scrollThreshold,
    Duration? scrollDebounce,
    bool? respectUserScroll,
    bool? smoothAnimation,
  }) {
    return AutoScrollBehavior(
      enableAutoScroll: enableAutoScroll ?? this.enableAutoScroll,
      animationDuration: animationDuration ?? this.animationDuration,
      animationCurve: animationCurve ?? this.animationCurve,
      userOverrideTimeout: userOverrideTimeout ?? this.userOverrideTimeout,
      scrollThreshold: scrollThreshold ?? this.scrollThreshold,
      scrollDebounce: scrollDebounce ?? this.scrollDebounce,
      respectUserScroll: respectUserScroll ?? this.respectUserScroll,
      smoothAnimation: smoothAnimation ?? this.smoothAnimation,
    );
  }
}

/// Auto-scroll widget that provides intelligent scrolling behavior
class AutoScrollView extends StatefulWidget {
  final Widget child;
  final AutoScrollBehavior behavior;
  final AutoScrollController? controller;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Axis scrollDirection;

  const AutoScrollView({
    super.key,
    required this.child,
    this.behavior = const AutoScrollBehavior(),
    this.controller,
    this.scrollController,
    this.padding,
    this.physics,
    this.scrollDirection = Axis.vertical,
  });

  @override
  State<AutoScrollView> createState() => _AutoScrollViewState();
}

class _AutoScrollViewState extends State<AutoScrollView> {
  late ScrollController _scrollController;
  late AutoScrollController _autoScrollController;
  bool _controllerCreatedInternally = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize scroll controller
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _controllerCreatedInternally = true;
    }
    
    // Initialize auto-scroll controller
    if (widget.controller != null) {
      _autoScrollController = widget.controller!;
    } else {
      _autoScrollController = AutoScrollController();
    }
    
    // Configure auto-scroll controller
    _autoScrollController.attachScrollController(_scrollController);
    _configureAutoScrollController();
  }

  @override
  void didUpdateWidget(AutoScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update configuration if behavior changed
    if (oldWidget.behavior != widget.behavior) {
      _configureAutoScrollController();
    }
    
    // Handle scroll controller changes
    if (oldWidget.scrollController != widget.scrollController) {
      if (_controllerCreatedInternally && oldWidget.scrollController == null) {
        _scrollController.dispose();
      }
      
      if (widget.scrollController != null) {
        _scrollController = widget.scrollController!;
        _controllerCreatedInternally = false;
      } else {
        _scrollController = ScrollController();
        _controllerCreatedInternally = true;
      }
      
      _autoScrollController.attachScrollController(_scrollController);
    }
  }

  void _configureAutoScrollController() {
    _autoScrollController
      ..animationDuration = widget.behavior.animationDuration
      ..animationCurve = widget.behavior.animationCurve
      ..userOverrideTimeout = widget.behavior.userOverrideTimeout
      ..scrollDebounce = widget.behavior.scrollDebounce
      ..setAutoScrollEnabled(widget.behavior.enableAutoScroll);
  }

  @override
  void dispose() {
    if (_controllerCreatedInternally) {
      _scrollController.dispose();
    }
    
    if (widget.controller == null) {
      _autoScrollController.dispose();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: widget.padding,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      child: widget.child,
    );
  }
}