import 'package:flutter/material.dart';

/// Manages animations for terminal block widgets
/// Provides centralized animation control for status indicators and interactive elements
class TerminalBlockAnimationManager {
  final TickerProvider _tickerProvider;
  
  late final AnimationController _statusAnimationController;
  late final AnimationController _interactiveAnimationController;
  
  late final Animation<double> _statusAnimation;
  late final Animation<double> _interactiveAnimation;

  bool _isInitialized = false;

  TerminalBlockAnimationManager({
    required TickerProvider tickerProvider,
  }) : _tickerProvider = tickerProvider;

  /// Initialize all animation controllers and animations
  void initialize() {
    if (_isInitialized) return;

    // Initialize animation controllers
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: _tickerProvider,
    );
    
    _interactiveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: _tickerProvider,
    );
    
    // Create animations with curves
    _statusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _statusAnimationController,
        curve: Curves.easeOut,
      ),
    );
    
    _interactiveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _interactiveAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _isInitialized = true;
  }

  /// Start initial animations
  void startInitialAnimations() {
    if (!_isInitialized) return;
    
    _statusAnimationController.forward();
  }

  /// Start interactive block animation
  void startInteractiveAnimation() {
    if (!_isInitialized) return;
    
    _interactiveAnimationController.repeat(reverse: true);
  }

  /// Stop interactive block animation
  void stopInteractiveAnimation() {
    if (!_isInitialized) return;
    
    _interactiveAnimationController.stop();
    _interactiveAnimationController.reset();
  }

  /// Animate status change
  void animateStatusChange() {
    if (!_isInitialized) return;
    
    _statusAnimationController.reset();
    _statusAnimationController.forward();
  }

  /// Get status animation value
  Animation<double> get statusAnimation => _statusAnimation;

  /// Get interactive animation value
  Animation<double> get interactiveAnimation => _interactiveAnimation;

  /// Get status animation controller for direct access
  AnimationController get statusController => _statusAnimationController;

  /// Get interactive animation controller for direct access
  AnimationController get interactiveController => _interactiveAnimationController;

  /// Check if animations are initialized
  bool get isInitialized => _isInitialized;

  /// Dispose all animation controllers
  void dispose() {
    if (!_isInitialized) return;
    
    _statusAnimationController.dispose();
    _interactiveAnimationController.dispose();
    _isInitialized = false;
  }
}

/// Animation state information for terminal blocks
class TerminalBlockAnimationState {
  final double statusValue;
  final double interactiveValue;
  final bool isInteractiveAnimating;
  final bool isStatusAnimating;

  const TerminalBlockAnimationState({
    required this.statusValue,
    required this.interactiveValue,
    required this.isInteractiveAnimating,
    required this.isStatusAnimating,
  });

  /// Create animation state from animation manager
  factory TerminalBlockAnimationState.fromManager(TerminalBlockAnimationManager manager) {
    return TerminalBlockAnimationState(
      statusValue: manager.isInitialized ? manager.statusAnimation.value : 0.0,
      interactiveValue: manager.isInitialized ? manager.interactiveAnimation.value : 0.0,
      isInteractiveAnimating: manager.isInitialized && 
          manager.interactiveController.isAnimating,
      isStatusAnimating: manager.isInitialized && 
          manager.statusController.isAnimating,
    );
  }

  @override
  String toString() {
    return 'TerminalBlockAnimationState{status: $statusValue, interactive: $interactiveValue}';
  }
}