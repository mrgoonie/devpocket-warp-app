import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../themes/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../services/terminal_text_encoding_service.dart';
import '../../services/ansi_text_processor.dart';
import '../../services/active_block_manager.dart';
import '../../services/persistent_process_detector.dart';
import '../../services/command_type_detector.dart';
import '../../models/enhanced_terminal_models.dart';
import 'terminal_block.dart';
import 'status_icon_widget.dart';

/// Enhanced terminal block with improved rendering, encoding support, and interactive process handling
class EnhancedTerminalBlock extends ConsumerStatefulWidget {
  final EnhancedTerminalBlockData blockData;
  final Stream<String>? outputStream;
  final VoidCallback? onRerun;
  final VoidCallback? onCancel;
  final VoidCallback? onEnterFullscreen;
  final ValueChanged<String>? onInputSubmit;
  final VoidCallback? onTap; // New: for tap-to-focus functionality
  final bool showCopyButton;
  final bool showTimestamp;
  final double? customFontSize;
  final String? customFontFamily;
  final String? sessionId; // New: for active block management

  const EnhancedTerminalBlock({
    super.key,
    required this.blockData,
    this.outputStream,
    this.onRerun,
    this.onCancel,
    this.onEnterFullscreen,
    this.onInputSubmit,
    this.onTap,
    this.showCopyButton = true,
    this.showTimestamp = true,
    this.customFontSize,
    this.customFontFamily,
    this.sessionId,
  });

  @override
  ConsumerState<EnhancedTerminalBlock> createState() => _EnhancedTerminalBlockState();
}

class _EnhancedTerminalBlockState extends ConsumerState<EnhancedTerminalBlock> 
    with TickerProviderStateMixin {
  final StringBuffer _outputBuffer = StringBuffer();
  final TextEditingController _inputController = TextEditingController();
  final TerminalTextEncodingService _encodingService = TerminalTextEncodingService.instance;
  final ActiveBlockManager _activeBlockManager = ActiveBlockManager.instance;
  final PersistentProcessDetector _processDetector = PersistentProcessDetector.instance;
  final CommandTypeDetector _commandTypeDetector = CommandTypeDetector.instance;
  
  StreamSubscription<String>? _outputSubscription;
  StreamSubscription<ActiveBlockEvent>? _activeBlockSubscription;
  late AnimationController _statusAnimationController;
  // Removed _expandAnimationController - no longer needed
  late AnimationController _interactiveAnimationController;
  late Animation<double> _statusAnimation;
  // Removed _expandAnimation - no longer needed
  late Animation<double> _interactiveAnimation;
  
  // Remove expansion state - blocks are now fixed height
  // bool _isExpanded = true;
  bool _showFullCommand = false;
  String _processedOutput = '';
  
  // Interactive process handling state
  bool _isActiveBlock = false;
  final bool _isFocused = false;
  ProcessInfo? _processInfo;
  
  // Command type detection state
  CommandTypeInfo? _commandTypeInfo;
  CommandType _commandType = CommandType.oneShot;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    // Removed _expandAnimationController initialization
    _interactiveAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _statusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statusAnimationController, curve: Curves.easeOut),
    );
    // Removed _expandAnimation initialization
    _interactiveAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _interactiveAnimationController, curve: Curves.easeInOut),
    );

    // Start animations
    _statusAnimationController.forward();
    // Always show expanded content - no expansion animation needed
    
    // Initialize output
    _initializeOutput();
    
    // Setup interactive process handling
    _setupInteractiveProcessHandling();
    
    // Setup command type detection
    _setupCommandTypeDetection();
    
    // Listen to output stream
    _setupOutputStream();
  }

  @override
  void didUpdateWidget(EnhancedTerminalBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.blockData.output != widget.blockData.output) {
      _initializeOutput();
    }
    
    if (oldWidget.outputStream != widget.outputStream) {
      _setupOutputStream();
    }
  }

  void _initializeOutput() {
    _outputBuffer.clear();
    if (widget.blockData.output.isNotEmpty) {
      _outputBuffer.write(widget.blockData.output);
      _processOutput();
    }
  }

  void _setupOutputStream() {
    _outputSubscription?.cancel();
    
    if (widget.outputStream != null) {
      _outputSubscription = widget.outputStream!.listen(
        (data) {
          setState(() {
            _outputBuffer.write(data);
            _processOutput();
          });
        },
        onError: (error) {
          setState(() {
            _outputBuffer.write('\n[ERROR] $error\n');
            _processOutput();
          });
        },
        onDone: () {
          if (mounted) {
            setState(() {
              // Stream completed
            });
          }
        },
      );
    }
  }

  void _processOutput() {
    final rawOutput = _outputBuffer.toString();
    // Use the new method that preserves ANSI codes for UI processing
    _processedOutput = _encodingService.processTerminalOutputWithAnsi(
      rawOutput,
      encoding: widget.blockData.encodingFormat,
    );
  }


  @override
  void dispose() {
    _outputSubscription?.cancel();
    _activeBlockSubscription?.cancel();
    _inputController.dispose();
    _statusAnimationController.dispose();
    _interactiveAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terminalTextColor = ref.watch(terminalTextColorProvider);
    final globalFontSize = ref.watch(fontSizeProvider);
    final globalFontFamily = ref.watch(fontFamilyProvider);
    final fontSize = widget.customFontSize ?? globalFontSize;
    final fontFamily = widget.customFontFamily ?? globalFontFamily;
    
    return AnimatedBuilder(
      animation: _statusAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _handleBlockTap,
          child: AnimatedBuilder(
            animation: _interactiveAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.95 + (0.05 * _statusAnimation.value),
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: AppTheme.darkSurface,
                  elevation: 2 + (2 * _statusAnimation.value) + (_isActiveBlock ? 2 : 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _getInteractiveStatusBorderColor(),
                      width: _getInteractiveBorderWidth(),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: _isFocused
                          ? Border.all(
                              color: AppTheme.terminalBlue.withValues(alpha: 0.6),
                              width: 2.0,
                            )
                          : null,
                      boxShadow: _isActiveBlock && _processInfo?.isPersistent == true
                          ? [
                              BoxShadow(
                                color: _getStatusColor().withValues(
                                  alpha: 0.3 + (0.2 * _interactiveAnimation.value),
                                ),
                                blurRadius: 8 + (4 * _interactiveAnimation.value),
                                spreadRadius: 1 + (1 * _interactiveAnimation.value),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildEnhancedHeader(fontSize, fontFamily),
                        // Always show output content - no expansion/collapse
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildEnhancedOutput(fontSize, fontFamily, terminalTextColor),
                            if (_shouldShowInteractiveInput())
                              _buildInteractiveInput(fontSize, fontFamily, terminalTextColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEnhancedHeader(double fontSize, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getStatusColor().withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Status indicators and action buttons
          Row(
            children: [
              // Intelligent status indicator
              StatusIconWidget(
                status: widget.blockData.status,
                commandType: _commandType,
                showActivityIndicator: _commandTypeInfo?.showActivityIndicator ?? false,
                size: 12,
                tooltip: _getStatusTooltip(),
              ),
              const SizedBox(width: 12),
              
              // Block index with enhanced styling
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${widget.blockData.index}',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: fontSize * 0.8,
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              
              // Spacer to push status badge and buttons to the right
              const Spacer(),
              
              // Status badge
              _buildEnhancedStatusBadge(fontSize),
              const SizedBox(width: 8),
              
              // Action buttons
              _buildActionButtons(),
              
              // Command type indicator
              if (_commandTypeInfo != null && _commandTypeInfo!.requiresSpecialHandling)
                _buildCommandTypeIndicator(),
                
              // Interactive process indicator
              if (_isActiveBlock && _processInfo != null)
                _buildInteractiveProcessIndicator(),
            ],
          ),
          
          // Row 2: Command display
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _showFullCommand = !_showFullCommand;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              child: Text(
                widget.blockData.command,
                style: TextStyle(
                  color: widget.blockData.isAgentCommand 
                      ? AppTheme.terminalBlue
                      : AppTheme.terminalGreen,
                  fontSize: fontSize * 0.9,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: _showFullCommand ? null : 1,
                overflow: _showFullCommand ? null : TextOverflow.ellipsis,
              ),
            ),
          ),
          
          // Metadata row
          if (widget.showTimestamp || widget.blockData.executionTime != null) ...[
            const SizedBox(height: 8),
            _buildMetadataRow(fontSize, fontFamily),
          ],
          
          // Error indicators
          if (widget.blockData.hasErrors) ...[
            const SizedBox(height: 8),
            _buildErrorIndicators(fontSize, fontFamily),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedStatusBadge(double fontSize) {
    return StatusIconBadge(
      status: widget.blockData.status,
      commandType: _commandType,
      showActivityIndicator: _commandTypeInfo?.showActivityIndicator ?? false,
      fontSize: fontSize * 0.8,
      customText: _getEnhancedStatusText(),
    );
  }
  
  /// Get enhanced status text that includes command type information
  String _getEnhancedStatusText() {
    final baseStatus = _getStatusText();
    if (widget.blockData.status == TerminalBlockStatus.running && _commandTypeInfo != null) {
      switch (_commandType) {
        case CommandType.oneShot:
          return 'Executing';
        case CommandType.continuous:
          return 'Monitoring';
        case CommandType.interactive:
          return 'Interactive';
      }
    }
    return baseStatus;
  }
  
  /// Get tooltip for status icon
  String _getStatusTooltip() {
    if (_commandTypeInfo == null) return _getStatusText();
    
    final typeDesc = _commandTypeInfo!.displayName;
    final statusText = _getStatusText();
    return '$typeDesc command - $statusText';
  }

  Widget _buildMetadataRow(double fontSize, String fontFamily) {
    return Wrap(
      spacing: 12,
      children: [
        if (widget.showTimestamp)
          _buildMetadataItem(
            icon: Icons.access_time,
            text: _formatTimestamp(widget.blockData.timestamp),
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        if (widget.blockData.executionTime != null)
          _buildMetadataItem(
            icon: Icons.timer,
            text: widget.blockData.formattedExecutionTime!,
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
        if (widget.blockData.exitCode != null)
          _buildMetadataItem(
            icon: Icons.code,
            text: 'Exit: ${widget.blockData.exitCode}',
            fontSize: fontSize,
            fontFamily: fontFamily,
          ),
      ],
    );
  }

  Widget _buildMetadataItem({
    required IconData icon,
    required String text,
    required double fontSize,
    required String fontFamily,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: fontSize * 0.8,
          color: AppTheme.darkTextSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: fontSize * 0.75,
            fontFamily: fontFamily,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorIndicators(double fontSize, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.terminalRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.terminalRed.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                size: 16,
                color: AppTheme.terminalRed,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.blockData.errors.length} error(s)',
                style: TextStyle(
                  color: AppTheme.terminalRed,
                  fontSize: fontSize * 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          ...widget.blockData.errors.take(3).map((error) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${error.message}',
                  style: TextStyle(
                    color: AppTheme.terminalRed,
                    fontSize: fontSize * 0.75,
                    fontFamily: fontFamily,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Expand/Collapse button removed - blocks are now fixed height
        
        // Fullscreen button (for interactive commands)
        if (widget.blockData.requiresFullscreenModal && widget.onEnterFullscreen != null)
          IconButton(
            onPressed: widget.onEnterFullscreen,
            icon: const Icon(
              Icons.fullscreen,
              color: AppTheme.terminalBlue,
            ),
            iconSize: 18,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            tooltip: 'Enter fullscreen mode',
          ),
        
        // Rerun button
        if (widget.onRerun != null && 
            widget.blockData.status != TerminalBlockStatus.running)
          IconButton(
            onPressed: widget.onRerun,
            icon: const Icon(
              Icons.replay,
              color: AppTheme.terminalGreen,
            ),
            iconSize: 18,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            tooltip: 'Rerun command',
          ),
        
        // Cancel button
        if (widget.onCancel != null && 
            widget.blockData.status == TerminalBlockStatus.running)
          IconButton(
            onPressed: widget.onCancel,
            icon: const Icon(
              Icons.stop,
              color: AppTheme.terminalRed,
            ),
            iconSize: 18,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            tooltip: 'Cancel command',
          ),
        
        // Copy command button
        if (widget.showCopyButton)
          IconButton(
            onPressed: _copyCommand,
            icon: const Icon(
              Icons.content_copy,
              color: AppTheme.terminalBlue,
            ),
            iconSize: 16,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            tooltip: 'Copy command',
          ),
        
        // Copy output button
        if (widget.showCopyButton && _processedOutput.isNotEmpty)
          IconButton(
            onPressed: _copyOutput,
            icon: const Icon(
              Icons.copy,
              color: AppTheme.terminalCyan,
            ),
            iconSize: 16,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            tooltip: 'Copy output',
          ),
        
        // Terminate active process button
        if (_isActiveBlock && _processInfo?.isPersistent == true)
          IconButton(
            onPressed: _terminateActiveProcess,
            icon: const Icon(
              Icons.close,
              color: AppTheme.terminalRed,
            ),
            iconSize: 16,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            tooltip: 'Terminate process',
          ),
      ],
    );
  }

  Widget _buildEnhancedOutput(double fontSize, String fontFamily, Color terminalTextColor) {
    if (_processedOutput.isEmpty && 
        widget.blockData.status == TerminalBlockStatus.pending) {
      return _buildEmptyState('Waiting to execute...', fontSize, fontFamily);
    }

    if (_processedOutput.isEmpty && 
        widget.blockData.status == TerminalBlockStatus.running) {
      return _buildLoadingState(fontSize, fontFamily);
    }

    // Fixed height container with no scrollable behavior
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      child: AnsiTextProcessor.instance.createSelectableTerminalText(
        _processedOutput,
        defaultStyle: TextStyle(
          color: terminalTextColor,
          fontSize: fontSize,
          fontFamily: fontFamily,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, double fontSize, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.terminal,
              size: 32,
              color: AppTheme.darkTextSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: fontSize * 0.9,
                fontFamily: fontFamily,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(double fontSize, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _getStatusColor(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _getLoadingText(),
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: fontSize * 0.9,
                fontFamily: fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveInput(double fontSize, String fontFamily, Color terminalTextColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.keyboard,
            size: 16,
            color: AppTheme.terminalBlue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _inputController,
              style: TextStyle(
                color: terminalTextColor,
                fontSize: fontSize,
                fontFamily: fontFamily,
              ),
              decoration: InputDecoration(
                hintText: 'Enter input for interactive command...',
                hintStyle: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: fontSize,
                ),
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _handleInteractiveInput(value);
                  _inputController.clear();
                }
              },
            ),
          ),
          IconButton(
            onPressed: () {
              final text = _inputController.text;
              if (text.isNotEmpty) {
                _handleInteractiveInput(text);
                _inputController.clear();
              }
            },
            icon: const Icon(
              Icons.send,
              color: AppTheme.terminalGreen,
            ),
            iconSize: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomContextMenu(BuildContext context, EditableTextState editableTextState) {
    final List<ContextMenuButtonItem> buttonItems = [
      ...editableTextState.contextMenuButtonItems,
      ContextMenuButtonItem(
        label: 'Copy Output',
        onPressed: () {
          _copyOutput();
          ContextMenuController.removeAny();
        },
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Color _getStatusColor() {
    switch (widget.blockData.status) {
      case TerminalBlockStatus.pending:
        return AppTheme.terminalYellow;
      case TerminalBlockStatus.running:
        return AppTheme.terminalBlue;
      case TerminalBlockStatus.interactive:
        return AppTheme.terminalCyan;
      case TerminalBlockStatus.completed:
        return widget.blockData.wasSuccessful ? AppTheme.terminalGreen : AppTheme.terminalYellow;
      case TerminalBlockStatus.failed:
        return AppTheme.terminalRed;
      case TerminalBlockStatus.cancelled:
        return AppTheme.darkTextSecondary;
    }
  }

  // Removed unused methods _getStatusBorderColor and _getStatusIcon
  // These are now handled by StatusIconWidget

  String _getStatusText() {
    switch (widget.blockData.status) {
      case TerminalBlockStatus.pending:
        return 'Pending';
      case TerminalBlockStatus.running:
        return 'Running';
      case TerminalBlockStatus.interactive:
        return 'Interactive';
      case TerminalBlockStatus.completed:
        return widget.blockData.wasSuccessful ? 'Success' : 'Warning';
      case TerminalBlockStatus.failed:
        return 'Failed';
      case TerminalBlockStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
  
  /// Get loading text based on command type
  String _getLoadingText() {
    switch (_commandType) {
      case CommandType.oneShot:
        return 'Executing command...';
      case CommandType.continuous:
        return 'Starting monitoring...';
      case CommandType.interactive:
        return 'Initializing interactive session...';
    }
  }

  Future<void> _copyOutput() async {
    if (_processedOutput.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: _processedOutput));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Output copied to clipboard'),
            duration: Duration(seconds: 2),
            backgroundColor: AppTheme.terminalGreen,
          ),
        );
      }
    }
  }

  Future<void> _copyCommand() async {
    await Clipboard.setData(ClipboardData(text: widget.blockData.command));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Command copied to clipboard'),
          duration: Duration(seconds: 2),
          backgroundColor: AppTheme.terminalBlue,
        ),
      );
    }
  }

  /// Get interactive status border color with active block consideration
  Color _getInteractiveStatusBorderColor() {
    if (_isActiveBlock) {
      if (_isFocused) {
        return AppTheme.terminalBlue;
      } else if (_processInfo?.isPersistent == true) {
        return _getStatusColor().withValues(alpha: 0.6);
      } else {
        return _getStatusColor().withValues(alpha: 0.5);
      }
    }
    return _getStatusColor().withValues(alpha: 0.3);
  }

  /// Get interactive border width
  double _getInteractiveBorderWidth() {
    if (_isActiveBlock) {
      return _isFocused ? 2.5 : 2.0;
    }
    return 1.5;
  }

  /// Check if interactive input should be shown
  bool _shouldShowInteractiveInput() {
    // Show if it's traditionally interactive
    if (widget.blockData.isInteractive && 
        widget.blockData.status == TerminalBlockStatus.running) {
      return true;
    }
    
    // Show if it's an active block that requires input
    if (_isActiveBlock && _processInfo?.requiresInput == true) {
      return true;
    }
    
    return false;
  }

  /// Build command type indicator
  Widget _buildCommandTypeIndicator() {
    if (_commandTypeInfo == null) return const SizedBox.shrink();

    final typeInfo = _commandTypeInfo!;
    Color typeColor = _getCommandTypeColor();
    IconData typeIcon = _getCommandTypeIcon();

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: typeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            typeIcon,
            size: 10,
            color: typeColor,
          ),
          const SizedBox(width: 4),
          Text(
            typeInfo.displayName,
            style: TextStyle(
              color: typeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Build interactive process indicator
  Widget _buildInteractiveProcessIndicator() {
    if (_processInfo == null) return const SizedBox.shrink();

    String typeText = '';
    IconData typeIcon = Icons.radio_button_checked;
    Color typeColor = AppTheme.terminalGreen;

    switch (_processInfo!.type) {
      case ProcessType.oneshot:
        typeText = 'One Shot';
        typeIcon = Icons.flash_on;
        typeColor = AppTheme.terminalGreen;
        break;
      case ProcessType.persistent:
        typeText = 'Persistent';
        typeIcon = Icons.autorenew;
        typeColor = AppTheme.terminalYellow;
        break;
      case ProcessType.repl:
        typeText = 'REPL';
        typeIcon = Icons.code;
        typeColor = AppTheme.terminalBlue;
        break;
      case ProcessType.devServer:
        typeText = 'Dev Server';
        typeIcon = Icons.dns;
        typeColor = AppTheme.terminalGreen;
        break;
      case ProcessType.watcher:
        typeText = 'Watcher';
        typeIcon = Icons.visibility;
        typeColor = AppTheme.terminalYellow;
        break;
      case ProcessType.interactive:
        typeText = 'Interactive';
        typeIcon = Icons.keyboard;
        typeColor = AppTheme.terminalCyan;
        break;
      case ProcessType.buildTool:
        typeText = 'Build Tool';
        typeIcon = Icons.build;
        typeColor = AppTheme.terminalPurple;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: typeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: typeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            typeIcon,
            size: 10,
            color: typeColor,
          ),
          const SizedBox(width: 4),
          Text(
            typeText,
            style: TextStyle(
              color: typeColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (_processInfo!.isPersistent && _isActiveBlock) ...
            [
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: _interactiveAnimation,
                builder: (context, child) {
                  return Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: typeColor.withValues(
                        alpha: 0.5 + (0.5 * _interactiveAnimation.value),
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            ],
        ],
      ),
    );
  }
  
  /// Get color for command type indicator
  Color _getCommandTypeColor() {
    switch (_commandType) {
      case CommandType.oneShot:
        return AppTheme.terminalBlue;
      case CommandType.continuous:
        return AppTheme.terminalYellow;
      case CommandType.interactive:
        return AppTheme.terminalCyan;
    }
  }
  
  /// Get icon for command type indicator
  IconData _getCommandTypeIcon() {
    switch (_commandType) {
      case CommandType.oneShot:
        return Icons.flash_on;
      case CommandType.continuous:
        return Icons.timeline;
      case CommandType.interactive:
        return Icons.keyboard;
    }
  }

  /// Setup interactive process handling
  void _setupInteractiveProcessHandling() {
    // Check if this block has an interactive process
    final processInfo = _processDetector.detectProcessType(widget.blockData.command);
    if (processInfo.isPersistent) {
      setState(() {
        _processInfo = processInfo;
      });
    }
  }
  
  /// Setup command type detection
  void _setupCommandTypeDetection() {
    // Detect command type for status icon display
    _commandTypeInfo = _commandTypeDetector.detectCommandType(widget.blockData.command);
    setState(() {
      _commandType = _commandTypeInfo!.type;
    });
  }

  /// Handle block tap for focus management
  void _handleBlockTap() {
    if (widget.blockData.status == TerminalBlockStatus.running && _processInfo?.isPersistent == true) {
      _activeBlockManager.focusBlock(widget.blockData.id);
      setState(() {
        _isActiveBlock = true;
      });
    }
  }

  /// Terminate the active process
  void _terminateActiveProcess() {
    if (_isActiveBlock && _processInfo?.isPersistent == true) {
      _activeBlockManager.terminateBlock(widget.blockData.id);
      setState(() {
        _isActiveBlock = false;
        _processInfo = null;
      });
    }
  }

  /// Handle interactive input for active processes
  void _handleInteractiveInput(String input) {
    if (_isActiveBlock && _processInfo?.isPersistent == true) {
      _activeBlockManager.sendInputToBlock(widget.blockData.id, input);
    }
  }
  
  /// Debug method to get command type information
  Map<String, dynamic> debugCommandTypeInfo() {
    return _commandTypeDetector.debugCommandInfo(widget.blockData.command);
  }
}