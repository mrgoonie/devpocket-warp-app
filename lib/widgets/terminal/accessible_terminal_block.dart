import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../models/enhanced_terminal_models.dart';
import '../../widgets/terminal/terminal_block.dart';
import '../../themes/app_theme.dart';

/// Accessible terminal block widget with comprehensive accessibility features
class AccessibleTerminalBlock extends StatefulWidget {
  final TerminalBlockData block;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Function(String)? onInteractionRequested;
  final bool enableHighContrast;
  final double fontScale;
  final bool enableKeyboardNavigation;
  
  const AccessibleTerminalBlock({
    super.key,
    required this.block,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onInteractionRequested,
    this.enableHighContrast = false,
    this.fontScale = 1.0,
    this.enableKeyboardNavigation = true,
  });

  @override
  State<AccessibleTerminalBlock> createState() => _AccessibleTerminalBlockState();
}

class _AccessibleTerminalBlockState extends State<AccessibleTerminalBlock> with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isHovered = false;
  late AnimationController _focusAnimationController;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _setupFocus();
  }

  void _setupAnimations() {
    _focusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _focusAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _focusAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _setupFocus() {
    _focusNode.addListener(() {
      if (mounted) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });
        
        if (_isFocused) {
          _focusAnimationController.forward();
          _announceBlockFocus();
        } else {
          _focusAnimationController.reverse();
        }
      }
    });
  }

  @override
  void dispose() {
    _focusAnimationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Announce block focus to screen readers
  void _announceBlockFocus() {
    final announcement = _buildSemanticAnnouncement();
    SemanticsService.announce(announcement, TextDirection.ltr);
  }

  /// Build semantic announcement for screen readers
  String _buildSemanticAnnouncement() {
    final statusText = _getStatusText(widget.block.status);
    final timeText = _formatTimestamp(widget.block.timestamp);
    
    String announcement = 'Terminal command block. Command: ${widget.block.command}. ';
    announcement += 'Status: $statusText. ';
    announcement += 'Executed at: $timeText. ';
    
    if (widget.block.output.isNotEmpty) {
      final outputPreview = _getOutputPreview(widget.block.output);
      announcement += 'Output: $outputPreview. ';
    }
    
    if (widget.block.isInteractive) {
      announcement += 'Interactive command. ';
    }
    
    if (widget.block.errorMessage != null) {
      announcement += 'Error: ${widget.block.errorMessage}. ';
    }
    
    return announcement;
  }

  /// Get status text for accessibility
  String _getStatusText(TerminalBlockStatus status) {
    switch (status) {
      case TerminalBlockStatus.pending:
        return 'Pending execution';
      case TerminalBlockStatus.running:
        return 'Currently running';
      case TerminalBlockStatus.completed:
        return 'Completed successfully';
      case TerminalBlockStatus.failed:
        return 'Failed with error';
      case TerminalBlockStatus.cancelled:
        return 'Cancelled by user';
      case TerminalBlockStatus.interactive:
        return 'Interactive mode active';
    }
  }

  /// Format timestamp for accessibility
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
  }

  /// Get output preview for accessibility
  String _getOutputPreview(String output) {
    if (output.isEmpty) return 'No output';
    
    // Get first few lines or characters for preview
    final lines = output.split('\n');
    if (lines.length > 3) {
      return '${lines.take(3).join('. ')}... and ${lines.length - 3} more lines';
    } else {
      final preview = output.length > 100 ? '${output.substring(0, 100)}...' : output;
      return preview.replaceAll('\n', '. ');
    }
  }

  /// Handle keyboard events
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.space:
          widget.onTap?.call();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.contextMenu:
          widget.onLongPress?.call();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyI:
          if (widget.block.isInteractive && widget.onInteractionRequested != null) {
            widget.onInteractionRequested!(widget.block.id);
            return KeyEventResult.handled;
          }
          break;
      }
    }
    return KeyEventResult.ignored;
  }

  /// Get accessibility theme colors
  AccessibilityColors _getAccessibilityColors(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    
    if (widget.enableHighContrast) {
      return brightness == Brightness.dark
          ? _getHighContrastDarkColors()
          : _getHighContrastLightColors();
    } else {
      return AccessibilityColors(
        background: theme.colorScheme.surface,
        foreground: theme.colorScheme.onSurface,
        border: theme.colorScheme.outline,
        focus: theme.colorScheme.primary,
        success: Colors.green,
        error: Colors.red,
        warning: Colors.orange,
        interactive: theme.colorScheme.primary,
      );
    }
  }

  /// Get high contrast dark theme colors
  AccessibilityColors _getHighContrastDarkColors() {
    return AccessibilityColors(
      background: Colors.black,
      foreground: Colors.white,
      border: Colors.white,
      focus: Colors.yellow,
      success: Colors.green[300]!,
      error: Colors.red[300]!,
      warning: Colors.orange[300]!,
      interactive: Colors.cyan,
    );
  }

  /// Get high contrast light theme colors
  AccessibilityColors _getHighContrastLightColors() {
    return AccessibilityColors(
      background: Colors.white,
      foreground: Colors.black,
      border: Colors.black,
      focus: Colors.blue[700]!,
      success: Colors.green[700]!,
      error: Colors.red[700]!,
      warning: Colors.orange[700]!,
      interactive: Colors.blue[700]!,
    );
  }

  /// Get status color for accessibility
  Color _getStatusColor(AccessibilityColors colors) {
    switch (widget.block.status) {
      case TerminalBlockStatus.pending:
        return colors.warning;
      case TerminalBlockStatus.running:
        return colors.interactive;
      case TerminalBlockStatus.completed:
        return colors.success;
      case TerminalBlockStatus.failed:
        return colors.error;
      case TerminalBlockStatus.cancelled:
        return colors.foreground.withOpacity(0.6);
      case TerminalBlockStatus.interactive:
        return colors.interactive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _getAccessibilityColors(context);
    final statusColor = _getStatusColor(colors);
    
    return Semantics(
      label: 'Terminal command block',
      hint: _buildSemanticHint(),
      value: widget.block.command,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      focused: _isFocused,
      selected: widget.isSelected,
      enabled: true,
      button: widget.onTap != null,
      child: Focus(
        focusNode: widget.enableKeyboardNavigation ? _focusNode : null,
        onKeyEvent: widget.enableKeyboardNavigation ? _handleKeyEvent : null,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedBuilder(
            animation: _focusAnimation,
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                decoration: BoxDecoration(
                  color: colors.background,
                  border: Border.all(
                    color: _getBorderColor(colors),
                    width: _getBorderWidth(),
                  ),
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: _buildBoxShadow(colors),
                ),
                child: InkWell(
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBlockHeader(colors, statusColor),
                        if (widget.block.output.isNotEmpty) ...[
                          const SizedBox(height: 8.0),
                          _buildBlockOutput(colors),
                        ],
                        if (widget.block.errorMessage != null) ...[
                          const SizedBox(height: 8.0),
                          _buildErrorMessage(colors),
                        ],
                        _buildBlockFooter(colors),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Build semantic hint for screen readers
  String _buildSemanticHint() {
    String hint = 'Double tap to select. Long press for options. ';
    
    if (widget.block.isInteractive) {
      hint += 'Press I to interact. ';
    }
    
    if (widget.block.status == TerminalBlockStatus.running) {
      hint += 'Command is currently running. ';
    }
    
    return hint;
  }

  /// Get border color based on focus and selection state
  Color _getBorderColor(AccessibilityColors colors) {
    if (_isFocused) {
      return colors.focus;
    } else if (widget.isSelected) {
      return colors.interactive;
    } else if (_isHovered) {
      return colors.border.withOpacity(0.8);
    } else {
      return colors.border.withOpacity(0.3);
    }
  }

  /// Get border width based on focus state
  double _getBorderWidth() {
    if (_isFocused) {
      return 3.0;
    } else if (widget.isSelected) {
      return 2.0;
    } else {
      return 1.0;
    }
  }

  /// Build box shadow for depth perception
  List<BoxShadow> _buildBoxShadow(AccessibilityColors colors) {
    if (_isFocused) {
      return [
        BoxShadow(
          color: colors.focus.withOpacity(0.3),
          blurRadius: 8.0,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (widget.isSelected) {
      return [
        BoxShadow(
          color: colors.interactive.withOpacity(0.2),
          blurRadius: 4.0,
          offset: const Offset(0, 1),
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 2.0,
          offset: const Offset(0, 1),
        ),
      ];
    }
  }

  /// Build block header with command and status
  Widget _buildBlockHeader(AccessibilityColors colors, Color statusColor) {
    return Semantics(
      label: 'Command and status',
      child: Row(
        children: [
          // Status indicator
          Semantics(
            label: 'Status indicator',
            hint: _getStatusText(widget.block.status),
            child: Container(
              width: 12.0 * widget.fontScale,
              height: 12.0 * widget.fontScale,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          
          // Command text
          Expanded(
            child: Semantics(
              label: 'Command',
              value: widget.block.command,
              child: SelectableText(
                widget.block.command,
                style: TextStyle(
                  color: colors.foreground,
                  fontSize: 14.0 * widget.fontScale,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          // Interactive indicator
          if (widget.block.isInteractive)
            Semantics(
              label: 'Interactive command',
              hint: 'This command supports interaction',
              child: Icon(
                Icons.touch_app,
                size: 16.0 * widget.fontScale,
                color: colors.interactive,
              ),
            ),
        ],
      ),
    );
  }

  /// Build block output section
  Widget _buildBlockOutput(AccessibilityColors colors) {
    return Semantics(
      label: 'Command output',
      hint: 'Terminal output from command execution',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: colors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(
            color: colors.border.withOpacity(0.2),
          ),
        ),
        child: SelectableText(
          widget.block.output,
          style: TextStyle(
            color: colors.foreground.withOpacity(0.9),
            fontSize: 12.0 * widget.fontScale,
            fontFamily: 'monospace',
            height: 1.4,
          ),
        ),
      ),
    );
  }

  /// Build error message section
  Widget _buildErrorMessage(AccessibilityColors colors) {
    return Semantics(
      label: 'Error message',
      hint: 'Command execution error details',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: colors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(
            color: colors.error.withOpacity(0.3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: 16.0 * widget.fontScale,
              color: colors.error,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: SelectableText(
                widget.block.errorMessage!,
                style: TextStyle(
                  color: colors.error,
                  fontSize: 12.0 * widget.fontScale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build block footer with timestamp and duration
  Widget _buildBlockFooter(AccessibilityColors colors) {
    return Semantics(
      label: 'Execution details',
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Row(
          children: [
            // Timestamp
            Semantics(
              label: 'Execution time',
              value: _formatTimestamp(widget.block.timestamp),
              child: Text(
                _formatTimestamp(widget.block.timestamp),
                style: TextStyle(
                  color: colors.foreground.withOpacity(0.6),
                  fontSize: 11.0 * widget.fontScale,
                ),
              ),
            ),
            
            if (widget.block.duration != null) ...[
              const SizedBox(width: 16.0),
              Semantics(
                label: 'Execution duration',
                value: _formatDuration(widget.block.duration!),
                child: Text(
                  _formatDuration(widget.block.duration!),
                  style: TextStyle(
                    color: colors.foreground.withOpacity(0.6),
                    fontSize: 11.0 * widget.fontScale,
                  ),
                ),
              ),
            ],
            
            if (widget.block.exitCode != null) ...[
              const SizedBox(width: 16.0),
              Semantics(
                label: 'Exit code',
                value: 'Exit code ${widget.block.exitCode}',
                child: Text(
                  'Exit: ${widget.block.exitCode}',
                  style: TextStyle(
                    color: widget.block.exitCode == 0 ? colors.success : colors.error,
                    fontSize: 11.0 * widget.fontScale,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Format duration for display
  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }
}

/// Accessibility color scheme
class AccessibilityColors {
  final Color background;
  final Color foreground;
  final Color border;
  final Color focus;
  final Color success;
  final Color error;
  final Color warning;
  final Color interactive;

  const AccessibilityColors({
    required this.background,
    required this.foreground,
    required this.border,
    required this.focus,
    required this.success,
    required this.error,
    required this.warning,
    required this.interactive,
  });
}