import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../themes/app_theme.dart';
import '../../services/command_type_detector.dart';
import '../terminal/terminal_block.dart';

/// Widget for displaying intelligent status icons based on command type and execution status
class StatusIconWidget extends StatefulWidget {
  final TerminalBlockStatus status;
  final CommandType commandType;
  final bool showActivityIndicator;
  final double size;
  final Duration animationDuration;
  final String? tooltip;

  const StatusIconWidget({
    super.key,
    required this.status,
    required this.commandType,
    this.showActivityIndicator = false,
    this.size = 16.0,
    this.animationDuration = const Duration(milliseconds: 300),
    this.tooltip,
  });

  @override
  State<StatusIconWidget> createState() => _StatusIconWidgetState();
}

class _StatusIconWidgetState extends State<StatusIconWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Pulse animation for activity indicators
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Rotation animation for continuous commands
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _updateAnimations();
  }

  @override
  void didUpdateWidget(StatusIconWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status || 
        oldWidget.commandType != widget.commandType ||
        oldWidget.showActivityIndicator != widget.showActivityIndicator) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    // Stop all animations first
    _pulseController.stop();
    _rotationController.stop();
    
    if (widget.status == TerminalBlockStatus.running) {
      if (widget.showActivityIndicator && widget.commandType == CommandType.continuous) {
        // Continuous commands get rotation animation
        _rotationController.repeat();
      } else if (widget.showActivityIndicator) {
        // Other running commands get pulse animation
        _pulseController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = _getIcon();
    final color = _getColor();
    
    Widget iconWidget = Icon(
      icon,
      size: widget.size,
      color: color,
      semanticLabel: widget.tooltip ?? _getSemanticLabel(),
    );

    // Apply animations for running status
    if (widget.status == TerminalBlockStatus.running && widget.showActivityIndicator) {
      if (widget.commandType == CommandType.continuous) {
        // Rotation animation for continuous commands
        iconWidget = AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value,
              child: child,
            );
          },
          child: iconWidget,
        );
      } else {
        // Pulse animation for other commands
        iconWidget = AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: child,
            );
          },
          child: iconWidget,
        );
      }
    }

    // Add glow effect for running status
    if (widget.status == TerminalBlockStatus.running) {
      iconWidget = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: iconWidget,
      );
    }

    // Wrap with tooltip if provided
    if (widget.tooltip != null) {
      iconWidget = Tooltip(
        message: widget.tooltip!,
        child: iconWidget,
      );
    }

    return AnimatedContainer(
      duration: widget.animationDuration,
      child: iconWidget,
    );
  }

  /// Get appropriate icon based on command type and status
  IconData _getIcon() {
    switch (widget.status) {
      case TerminalBlockStatus.pending:
        return _getPendingIcon();
      case TerminalBlockStatus.running:
        return _getRunningIcon();
      case TerminalBlockStatus.interactive:
        return Icons.keyboard;
      case TerminalBlockStatus.completed:
        return Icons.check_circle;
      case TerminalBlockStatus.failed:
        return Icons.error;
      case TerminalBlockStatus.cancelled:
        return Icons.stop_circle;
    }
  }

  /// Get pending icon based on command type
  IconData _getPendingIcon() {
    switch (widget.commandType) {
      case CommandType.oneShot:
        return Icons.schedule;
      case CommandType.continuous:
        return Icons.timer;
      case CommandType.interactive:
        return Icons.pending;
    }
  }

  /// Get running icon based on command type
  IconData _getRunningIcon() {
    switch (widget.commandType) {
      case CommandType.oneShot:
        return Icons.flash_on; // Lightning bolt for quick commands
      case CommandType.continuous:
        return Icons.timeline; // Timeline/activity chart for continuous
      case CommandType.interactive:
        return Icons.keyboard; // Keyboard for interactive
    }
  }

  /// Get appropriate color based on status
  Color _getColor() {
    switch (widget.status) {
      case TerminalBlockStatus.pending:
        return AppTheme.terminalYellow;
      case TerminalBlockStatus.running:
        return _getRunningColor();
      case TerminalBlockStatus.interactive:
        return AppTheme.terminalCyan;
      case TerminalBlockStatus.completed:
        return AppTheme.terminalGreen;
      case TerminalBlockStatus.failed:
        return AppTheme.terminalRed;
      case TerminalBlockStatus.cancelled:
        return AppTheme.darkTextSecondary;
    }
  }

  /// Get running color based on command type
  Color _getRunningColor() {
    switch (widget.commandType) {
      case CommandType.oneShot:
        return AppTheme.terminalBlue;
      case CommandType.continuous:
        return AppTheme.terminalYellow;
      case CommandType.interactive:
        return AppTheme.terminalCyan;
    }
  }

  /// Get semantic label for accessibility
  String _getSemanticLabel() {
    final statusText = _getStatusText();
    final typeText = _getCommandTypeText();
    return '$typeText command is $statusText';
  }

  /// Get status text for accessibility
  String _getStatusText() {
    switch (widget.status) {
      case TerminalBlockStatus.pending:
        return 'pending';
      case TerminalBlockStatus.running:
        return 'running';
      case TerminalBlockStatus.interactive:
        return 'interactive';
      case TerminalBlockStatus.completed:
        return 'completed';
      case TerminalBlockStatus.failed:
        return 'failed';
      case TerminalBlockStatus.cancelled:
        return 'cancelled';
    }
  }

  /// Get command type text for accessibility
  String _getCommandTypeText() {
    switch (widget.commandType) {
      case CommandType.oneShot:
        return 'One-shot';
      case CommandType.continuous:
        return 'Continuous';
      case CommandType.interactive:
        return 'Interactive';
    }
  }
}

/// Helper widget for combining status icon with text badge
class StatusIconBadge extends StatelessWidget {
  final TerminalBlockStatus status;
  final CommandType commandType;
  final bool showActivityIndicator;
  final double fontSize;
  final String? customText;

  const StatusIconBadge({
    super.key,
    required this.status,
    required this.commandType,
    this.showActivityIndicator = false,
    this.fontSize = 12.0,
    this.customText,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = customText ?? _getStatusText();
    final color = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusIconWidget(
            status: status,
            commandType: commandType,
            showActivityIndicator: showActivityIndicator,
            size: fontSize,
          ),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: fontSize * 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText() {
    switch (status) {
      case TerminalBlockStatus.pending:
        return 'Pending';
      case TerminalBlockStatus.running:
        return _getRunningText();
      case TerminalBlockStatus.interactive:
        return 'Interactive';
      case TerminalBlockStatus.completed:
        return 'Success';
      case TerminalBlockStatus.failed:
        return 'Failed';
      case TerminalBlockStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _getRunningText() {
    switch (commandType) {
      case CommandType.oneShot:
        return 'Executing';
      case CommandType.continuous:
        return 'Monitoring';
      case CommandType.interactive:
        return 'Interactive';
    }
  }

  Color _getStatusColor() {
    switch (status) {
      case TerminalBlockStatus.pending:
        return AppTheme.terminalYellow;
      case TerminalBlockStatus.running:
        return _getRunningColor();
      case TerminalBlockStatus.interactive:
        return AppTheme.terminalCyan;
      case TerminalBlockStatus.completed:
        return AppTheme.terminalGreen;
      case TerminalBlockStatus.failed:
        return AppTheme.terminalRed;
      case TerminalBlockStatus.cancelled:
        return AppTheme.darkTextSecondary;
    }
  }

  Color _getRunningColor() {
    switch (commandType) {
      case CommandType.oneShot:
        return AppTheme.terminalBlue;
      case CommandType.continuous:
        return AppTheme.terminalYellow;
      case CommandType.interactive:
        return AppTheme.terminalCyan;
    }
  }
}