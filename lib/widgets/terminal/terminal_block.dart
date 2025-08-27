import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../themes/app_theme.dart';
import '../../providers/theme_provider.dart';

/// Terminal block status indicating command execution state
enum TerminalBlockStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
  interactive,
}

/// Terminal block representing a single command execution with input/output separation
class TerminalBlock extends ConsumerStatefulWidget {
  final String command;
  final Stream<String>? outputStream;
  final TerminalBlockStatus status;
  final DateTime timestamp;
  final String? output;
  final VoidCallback? onRerun;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onInputSubmit;
  final bool isInteractive;
  final bool showCopyButton;
  final int blockIndex;

  const TerminalBlock({
    super.key,
    required this.command,
    this.outputStream,
    required this.status,
    required this.timestamp,
    this.output,
    this.onRerun,
    this.onCancel,
    this.onInputSubmit,
    this.isInteractive = false,
    this.showCopyButton = true,
    required this.blockIndex,
  });

  @override
  ConsumerState<TerminalBlock> createState() => _TerminalBlockState();
}

class _TerminalBlockState extends ConsumerState<TerminalBlock> {
  final StringBuffer _outputBuffer = StringBuffer();
  StreamSubscription<String>? _outputSubscription;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _outputScrollController = ScrollController();
  bool _isExpanded = true;
  bool _autoScroll = true;

  @override
  void initState() {
    super.initState();
    
    // Initialize with existing output if provided
    if (widget.output != null) {
      _outputBuffer.write(widget.output);
    }
    
    // Listen to output stream if provided
    if (widget.outputStream != null) {
      _outputSubscription = widget.outputStream!.listen(
        (data) {
          setState(() {
            _outputBuffer.write(data);
          });
          
          // Auto-scroll to bottom if enabled
          if (_autoScroll && _outputScrollController.hasClients) {
            Future.delayed(const Duration(milliseconds: 50), () {
              if (_outputScrollController.hasClients) {
                _outputScrollController.animateTo(
                  _outputScrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              }
            });
          }
        },
        onError: (error) {
          setState(() {
            _outputBuffer.write('\nError: $error\n');
          });
        },
        onDone: () {
          if (mounted) {
            setState(() {
              // Stream is done, update status if still running
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _inputController.dispose();
    _outputScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: _getStatusBorderColor(),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          if (_isExpanded) ...[
            _buildOutput(),
            if (widget.isInteractive && widget.status == TerminalBlockStatus.running)
              _buildInteractiveInput(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _getStatusColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          
          // Block index
          Text(
            '#${widget.blockIndex}',
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: ref.watch(fontSizeProvider) * 0.8,
              fontFamily: ref.watch(fontFamilyProvider),
            ),
          ),
          const SizedBox(width: 8),
          
          // Command
          Expanded(
            child: Text(
              widget.command,
              style: TextStyle(
                color: AppTheme.terminalGreen,
                fontSize: ref.watch(fontSizeProvider) * 0.9,
                fontFamily: ref.watch(fontFamilyProvider),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Status text
          Text(
            _getStatusText(),
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 8),
          
          // Action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showCopyButton && _outputBuffer.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  onPressed: _copyOutput,
                  tooltip: 'Copy Output',
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
                
              if (widget.onRerun != null && widget.status != TerminalBlockStatus.running)
                IconButton(
                  icon: const Icon(Icons.replay, size: 16),
                  onPressed: widget.onRerun,
                  tooltip: 'Rerun Command',
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
                
              if (widget.onCancel != null && widget.status == TerminalBlockStatus.running)
                IconButton(
                  icon: const Icon(Icons.stop, size: 16),
                  onPressed: widget.onCancel,
                  tooltip: 'Cancel Command',
                  iconSize: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
                
              IconButton(
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                ),
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                tooltip: _isExpanded ? 'Collapse' : 'Expand',
                iconSize: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutput() {
    final outputText = _outputBuffer.toString();
    
    if (outputText.isEmpty && widget.status == TerminalBlockStatus.pending) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Waiting to execute...',
          style: TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    if (outputText.isEmpty && widget.status == TerminalBlockStatus.running) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Executing command...',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 300, // Prevent blocks from becoming too tall
      ),
      child: Scrollbar(
        controller: _outputScrollController,
        child: SingleChildScrollView(
          controller: _outputScrollController,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              outputText,
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: ref.watch(fontSizeProvider) * 0.85,
                fontFamily: ref.watch(fontFamilyProvider),
                height: 1.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.keyboard,
            size: 16,
            color: AppTheme.darkTextSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _inputController,
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: ref.watch(fontSizeProvider) * 0.85,
                fontFamily: ref.watch(fontFamilyProvider),
              ),
              decoration: InputDecoration(
                hintText: 'Interactive input...',
                hintStyle: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty && widget.onInputSubmit != null) {
                  widget.onInputSubmit!(value);
                  _inputController.clear();
                }
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 16),
            onPressed: () {
              final value = _inputController.text;
              if (value.isNotEmpty && widget.onInputSubmit != null) {
                widget.onInputSubmit!(value);
                _inputController.clear();
              }
            },
            tooltip: 'Send Input',
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.status) {
      case TerminalBlockStatus.pending:
        return AppTheme.terminalYellow;
      case TerminalBlockStatus.running:
      case TerminalBlockStatus.interactive:
        return AppTheme.terminalBlue;
      case TerminalBlockStatus.completed:
        return AppTheme.terminalGreen;
      case TerminalBlockStatus.failed:
        return AppTheme.terminalRed;
      case TerminalBlockStatus.cancelled:
        return AppTheme.darkTextSecondary;
    }
  }

  Color _getStatusBorderColor() {
    return _getStatusColor().withValues(alpha: 0.3);
  }

  String _getStatusText() {
    switch (widget.status) {
      case TerminalBlockStatus.pending:
        return 'Pending';
      case TerminalBlockStatus.running:
        return 'Running';
      case TerminalBlockStatus.interactive:
        return 'Interactive';
      case TerminalBlockStatus.completed:
        return 'Completed';
      case TerminalBlockStatus.failed:
        return 'Failed';
      case TerminalBlockStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _copyOutput() async {
    final text = _outputBuffer.toString();
    if (text.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: text));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Output copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}

/// Terminal block data model
class TerminalBlockData {
  final String id;
  final String command;
  final TerminalBlockStatus status;
  final DateTime timestamp;
  final String output;
  final bool isInteractive;
  final int index;
  final int? exitCode;
  final Duration? duration;
  final String? errorMessage;

  TerminalBlockData({
    required this.id,
    required this.command,
    required this.status,
    required this.timestamp,
    this.output = '',
    this.isInteractive = false,
    required this.index,
    this.exitCode,
    this.duration,
    this.errorMessage,
  });

  TerminalBlockData copyWith({
    String? id,
    String? command,
    TerminalBlockStatus? status,
    DateTime? timestamp,
    String? output,
    bool? isInteractive,
    int? index,
    int? exitCode,
    Duration? duration,
    String? errorMessage,
  }) {
    return TerminalBlockData(
      id: id ?? this.id,
      command: command ?? this.command,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      output: output ?? this.output,
      isInteractive: isInteractive ?? this.isInteractive,
      index: index ?? this.index,
      exitCode: exitCode ?? this.exitCode,
      duration: duration ?? this.duration,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}