import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../themes/app_theme.dart';
import '../../../providers/theme_provider.dart';
import '../../../services/ansi_text_processor.dart';
import '../../../services/command_type_detector.dart';
import '../../../models/enhanced_terminal_models.dart';
import '../status_icon_widget.dart';
import 'terminal_block_state_manager.dart';
import 'terminal_block_animation_manager.dart';
import 'terminal_block_interaction_handler.dart';

/// Renders UI components for terminal block widgets
/// Handles all visual aspects including header, output, input, and status indicators
class TerminalBlockRenderer {
  final EnhancedTerminalBlockData blockData;
  final TerminalBlockStateManager stateManager;
  final TerminalBlockAnimationManager animationManager;
  final TerminalBlockInteractionHandler interactionHandler;
  
  // Display options
  final bool showCopyButton;
  final bool showTimestamp;
  final double? customFontSize;
  final String? customFontFamily;

  const TerminalBlockRenderer({
    required this.blockData,
    required this.stateManager,
    required this.animationManager,
    required this.interactionHandler,
    this.showCopyButton = true,
    this.showTimestamp = true,
    this.customFontSize,
    this.customFontFamily,
  });

  /// Build the complete terminal block widget
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([
        animationManager.statusAnimation,
        animationManager.interactiveAnimation,
        stateManager.outputNotifier,
        stateManager.activeBlockNotifier,
        stateManager.focusNotifier,
      ]),
      builder: (context, child) {
        return _buildBlockContainer(context, isDarkMode);
      },
    );
  }

  /// Build the main block container
  Widget _buildBlockContainer(BuildContext context, bool isDarkMode) {
    final isActive = stateManager.isActiveBlock;
    final isFocused = stateManager.isFocused;
    
    return GestureDetector(
      onTap: interactionHandler.handleBlockTap,
      onLongPress: () => interactionHandler.handleLongPress(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: _buildBlockDecoration(isDarkMode, isActive, isFocused),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, isDarkMode),
            _buildContent(context, isDarkMode),
            if (stateManager.canAcceptInput()) 
              _buildInputSection(context, isDarkMode),
          ],
        ),
      ),
    );
  }

  /// Build block decoration with focus and active states
  BoxDecoration _buildBlockDecoration(bool isDarkMode, bool isActive, bool isFocused) {
    Color borderColor = isDarkMode 
        ? AppTheme.darkBorderColor 
        : AppTheme.lightBorderColor;

    if (isFocused) {
      borderColor = AppTheme.primaryColor;
    } else if (isActive) {
      borderColor = AppTheme.terminalCyan;
    }

    return BoxDecoration(
      color: isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
      border: Border.all(
        color: borderColor.withValues(alpha: 0.3 + (animationManager.statusAnimation.value * 0.4)),
        width: isFocused ? 2.0 : 1.0,
      ),
      borderRadius: BorderRadius.circular(8.0),
      boxShadow: [
        if (isFocused || isActive)
          BoxShadow(
            color: borderColor.withValues(alpha: 0.2),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }

  /// Build the block header
  Widget _buildHeader(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: (isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground)
            .withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7.0)),
      ),
      child: Row(
        children: [
          _buildStatusIcon(),
          const SizedBox(width: 8.0),
          Expanded(child: _buildCommandDisplay(isDarkMode)),
          _buildHeaderActions(context, isDarkMode),
        ],
      ),
    );
  }

  /// Build status icon with animation
  Widget _buildStatusIcon() {
    final status = blockData.status;
    final isActive = stateManager.isActiveBlock;
    
    return AnimatedBuilder(
      animation: animationManager.statusAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.6 + (animationManager.statusAnimation.value * 0.4),
          child: Stack(
            alignment: Alignment.center,
            children: [
              StatusIconWidget(
                status: status,
                commandType: CommandType.oneShot,
                showActivityIndicator: isActive,
              ),
              if (isActive && animationManager.interactiveAnimation.value > 0)
                Container(
                  width: 20.0,
                  height: 20.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.terminalCyan.withValues(
                        alpha: animationManager.interactiveAnimation.value * 0.5,
                      ),
                      width: 2.0,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Build command display
  Widget _buildCommandDisplay(bool isDarkMode) {
    final command = blockData.command;
    final showFull = stateManager.showFullCommand;
    final displayCommand = showFull ? command : _truncateCommand(command);
    
    return GestureDetector(
      onTap: () => stateManager.setShowFullCommand(!showFull),
      child: Text(
        displayCommand,
        style: TextStyle(
          color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
          fontSize: customFontSize ?? 14.0,
          fontFamily: customFontFamily ?? 'JetBrainsMono',
          fontWeight: FontWeight.w500,
        ),
        maxLines: showFull ? null : 1,
        overflow: showFull ? null : TextOverflow.ellipsis,
      ),
    );
  }

  /// Build header actions
  Widget _buildHeaderActions(BuildContext context, bool isDarkMode) {
    final actions = <Widget>[];
    
    // Timestamp
    if (showTimestamp) {
      actions.add(_buildTimestamp(isDarkMode));
      actions.add(const SizedBox(width: 8.0));
    }
    
    // Copy button
    if (showCopyButton) {
      actions.add(_buildCopyButton(isDarkMode));
    }
    
    // Additional action buttons for active blocks
    if (stateManager.isActiveBlock) {
      actions.add(const SizedBox(width: 8.0));
      actions.add(_buildActiveBlockActions(isDarkMode));
    }

    return Row(children: actions);
  }

  /// Build timestamp display
  Widget _buildTimestamp(bool isDarkMode) {
    return Text(
      _formatTimestamp(blockData.timestamp),
      style: TextStyle(
        color: (isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
        fontSize: 11.0,
        fontFamily: customFontFamily ?? 'JetBrainsMono',
      ),
    );
  }

  /// Build copy button
  Widget _buildCopyButton(bool isDarkMode) {
    return IconButton(
      icon: Icon(
        Icons.copy,
        size: 16.0,
        color: (isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
      ),
      onPressed: () {
        // Copy functionality handled by interaction handler
        interactionHandler.handleKeyEvent(
          KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyC,
            logicalKey: LogicalKeyboardKey.keyC,
            timeStamp: Duration.zero,
          ),
        );
      },
      tooltip: 'Copy Output',
    );
  }

  /// Build active block actions
  Widget _buildActiveBlockActions(bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (interactionHandler.onCancel != null)
          IconButton(
            icon: const Icon(
              Icons.stop,
              size: 16.0,
              color: AppTheme.terminalRed,
            ),
            onPressed: interactionHandler.onCancel,
            tooltip: 'Stop Process',
          ),
        if (interactionHandler.onEnterFullscreen != null)
          IconButton(
            icon: Icon(
              Icons.fullscreen,
              size: 16.0,
              color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            onPressed: interactionHandler.onEnterFullscreen,
            tooltip: 'Enter Fullscreen',
          ),
      ],
    );
  }

  /// Build content section (output)
  Widget _buildContent(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      child: _buildOutputDisplay(isDarkMode),
    );
  }

  /// Build output display
  Widget _buildOutputDisplay(bool isDarkMode) {
    final output = stateManager.processedOutput;
    
    if (output.isEmpty) {
      return Text(
        'No output',
        style: TextStyle(
          color: isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          fontSize: customFontSize ?? 13.0,
          fontFamily: customFontFamily ?? 'JetBrainsMono',
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return SelectableText.rich(
      AnsiTextProcessor.instance.processAnsiText(output),
      style: TextStyle(
        color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
        fontSize: customFontSize ?? 13.0,
        fontFamily: customFontFamily ?? 'JetBrainsMono',
        height: 1.4,
      ),
    );
  }

  /// Build input section for interactive blocks
  Widget _buildInputSection(BuildContext context, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: (isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground)
            .withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7.0)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.keyboard_arrow_right,
            color: AppTheme.terminalCyan,
            size: 16.0,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: interactionHandler.buildInputField(
              context: context,
              style: TextStyle(
                color: isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                fontSize: customFontSize ?? 13.0,
                fontFamily: customFontFamily ?? 'JetBrainsMono',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Truncate command for display
  String _truncateCommand(String command) {
    const maxLength = 60;
    if (command.length <= maxLength) return command;
    return '${command.substring(0, maxLength)}...';
  }

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}