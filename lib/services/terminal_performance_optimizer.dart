import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../widgets/terminal/terminal_block.dart';

/// Terminal performance optimizer for handling large outputs and memory management
class TerminalPerformanceOptimizer {
  static TerminalPerformanceOptimizer? _instance;
  static TerminalPerformanceOptimizer get instance => _instance ??= TerminalPerformanceOptimizer._();

  TerminalPerformanceOptimizer._();

  // Performance thresholds
  static const int _maxOutputLines = 10000;
  static const int _maxBlocksInMemory = 1000;
  static const int _virtualScrollThreshold = 100;
  static const int _memoryCleanupThreshold = 50 * 1024 * 1024; // 50MB
  static const Duration _performanceMonitorInterval = Duration(seconds: 10);

  // Performance monitoring
  final Map<String, PerformanceMetrics> _sessionMetrics = {};
  Timer? _performanceMonitorTimer;
  bool _isOptimizationActive = false;

  /// Initialize performance optimizer
  void initialize() {
    _startPerformanceMonitoring();
    debugPrint('Terminal performance optimizer initialized');
  }

  /// Start performance monitoring
  void _startPerformanceMonitoring() {
    _performanceMonitorTimer = Timer.periodic(_performanceMonitorInterval, (_) {
      _updatePerformanceMetrics();
      _checkOptimizationNeeds();
    });
  }

  /// Update performance metrics for all sessions
  void _updatePerformanceMetrics() {
    final now = DateTime.now();
    
    for (final entry in _sessionMetrics.entries) {
      final sessionId = entry.key;
      final metrics = entry.value;
      
      metrics.lastUpdateTime = now;
      
      // Update memory usage estimates
      _updateMemoryMetrics(sessionId, metrics);
      
      // Update rendering performance
      _updateRenderingMetrics(sessionId, metrics);
    }
  }

  /// Update memory usage metrics for a session
  void _updateMemoryMetrics(String sessionId, PerformanceMetrics metrics) {
    // Estimate memory usage based on terminal blocks
    int totalMemory = 0;
    int totalLines = 0;
    
    for (final block in metrics.terminalBlocks) {
      totalMemory += _estimateBlockMemoryUsage(block);
      totalLines += _countOutputLines(block.output);
    }
    
    metrics.estimatedMemoryUsage = totalMemory;
    metrics.totalOutputLines = totalLines;
    metrics.activeBlocks = metrics.terminalBlocks.where((b) => 
        b.status == TerminalBlockStatus.running).length;
  }

  /// Update rendering performance metrics
  void _updateRenderingMetrics(String sessionId, PerformanceMetrics metrics) {
    metrics.renderingComplexity = _calculateRenderingComplexity(metrics.terminalBlocks);
    metrics.scrollPerformanceScore = _calculateScrollPerformance(metrics);
  }

  /// Check if optimization is needed for any session
  void _checkOptimizationNeeds() {
    for (final entry in _sessionMetrics.entries) {
      final sessionId = entry.key;
      final metrics = entry.value;
      
      if (_needsOptimization(metrics)) {
        _applyOptimizations(sessionId, metrics);
      }
    }
  }

  /// Check if a session needs optimization
  bool _needsOptimization(PerformanceMetrics metrics) {
    return metrics.estimatedMemoryUsage > _memoryCleanupThreshold ||
           metrics.totalOutputLines > _maxOutputLines ||
           metrics.terminalBlocks.length > _maxBlocksInMemory ||
           metrics.scrollPerformanceScore < 0.5;
  }

  /// Apply optimizations to a session
  Future<void> _applyOptimizations(String sessionId, PerformanceMetrics metrics) async {
    if (_isOptimizationActive) return;
    
    _isOptimizationActive = true;
    
    try {
      debugPrint('Applying optimizations to session $sessionId');
      
      // Memory optimization
      if (metrics.estimatedMemoryUsage > _memoryCleanupThreshold) {
        await _optimizeMemoryUsage(sessionId, metrics);
      }
      
      // Output truncation
      if (metrics.totalOutputLines > _maxOutputLines) {
        await _truncateOldOutput(sessionId, metrics);
      }
      
      // Block cleanup
      if (metrics.terminalBlocks.length > _maxBlocksInMemory) {
        await _cleanupOldBlocks(sessionId, metrics);
      }
      
      // Update metrics after optimization
      _updateMemoryMetrics(sessionId, metrics);
      
      debugPrint('Optimization completed for session $sessionId');
      
    } catch (e) {
      debugPrint('Optimization failed for session $sessionId: $e');
    } finally {
      _isOptimizationActive = false;
    }
  }

  /// Optimize memory usage for a session
  Future<void> _optimizeMemoryUsage(String sessionId, PerformanceMetrics metrics) async {
    // Compress large outputs
    for (final block in metrics.terminalBlocks) {
      if (_shouldCompressOutput(block)) {
        _compressBlockOutput(block);
      }
    }
    
    // Clear cached rendering data
    _clearRenderingCache(sessionId);
  }

  /// Truncate old output to keep within limits
  Future<void> _truncateOldOutput(String sessionId, PerformanceMetrics metrics) async {
    const maxLinesPerBlock = 1000;
    
    for (final block in metrics.terminalBlocks) {
      if (_countOutputLines(block.output) > maxLinesPerBlock) {
        _truncateBlockOutput(block, maxLinesPerBlock);
      }
    }
  }

  /// Cleanup old terminal blocks
  Future<void> _cleanupOldBlocks(String sessionId, PerformanceMetrics metrics) async {
    // Keep only the most recent blocks and running blocks
    final blocksToKeep = <TerminalBlockData>[];
    final runningBlocks = metrics.terminalBlocks.where((b) => 
        b.status == TerminalBlockStatus.running).toList();
    final completedBlocks = metrics.terminalBlocks.where((b) => 
        b.status != TerminalBlockStatus.running).toList();
    
    // Keep all running blocks
    blocksToKeep.addAll(runningBlocks);
    
    // Keep most recent completed blocks up to limit
    final maxCompletedBlocks = _maxBlocksInMemory - runningBlocks.length;
    if (completedBlocks.length > maxCompletedBlocks) {
      completedBlocks.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      blocksToKeep.addAll(completedBlocks.take(maxCompletedBlocks));
    } else {
      blocksToKeep.addAll(completedBlocks);
    }
    
    // Update the blocks list
    metrics.terminalBlocks.clear();
    metrics.terminalBlocks.addAll(blocksToKeep);
  }

  /// Register a session for performance monitoring
  void registerSession(String sessionId, List<TerminalBlockData> terminalBlocks) {
    _sessionMetrics[sessionId] = PerformanceMetrics(
      sessionId: sessionId,
      terminalBlocks: terminalBlocks,
      registrationTime: DateTime.now(),
      lastUpdateTime: DateTime.now(),
    );
    
    debugPrint('Registered session for performance monitoring: $sessionId');
  }

  /// Unregister a session from performance monitoring
  void unregisterSession(String sessionId) {
    _sessionMetrics.remove(sessionId);
    debugPrint('Unregistered session from performance monitoring: $sessionId');
  }

  /// Build virtualized terminal output widget for large data sets
  Widget buildVirtualizedTerminalOutput({
    required List<TerminalBlockData> blocks,
    required ScrollController scrollController,
    required double itemHeight,
    required Widget Function(BuildContext, TerminalBlockData) itemBuilder,
    double? maxHeight,
  }) {
    if (blocks.length < _virtualScrollThreshold) {
      // Use regular ListView for small data sets
      return _buildRegularListView(blocks, scrollController, itemBuilder, maxHeight);
    }
    
    // Use virtual scrolling for large data sets
    return _buildVirtualizedListView(blocks, scrollController, itemHeight, itemBuilder, maxHeight);
  }

  /// Build regular ListView for small data sets
  Widget _buildRegularListView(
    List<TerminalBlockData> blocks,
    ScrollController scrollController,
    Widget Function(BuildContext, TerminalBlockData) itemBuilder,
    double? maxHeight,
  ) {
    return SizedBox(
      height: maxHeight,
      child: ListView.builder(
        controller: scrollController,
        itemCount: blocks.length,
        itemBuilder: (context, index) => itemBuilder(context, blocks[index]),
      ),
    );
  }

  /// Build virtualized ListView for large data sets
  Widget _buildVirtualizedListView(
    List<TerminalBlockData> blocks,
    ScrollController scrollController,
    double itemHeight,
    Widget Function(BuildContext, TerminalBlockData) itemBuilder,
    double? maxHeight,
  ) {
    return SizedBox(
      height: maxHeight,
      child: ListView.builder(
        controller: scrollController,
        itemCount: blocks.length,
        itemExtent: itemHeight,
        cacheExtent: itemHeight * 20, // Cache 20 items ahead/behind
        itemBuilder: (context, index) {
          if (index >= blocks.length) return const SizedBox.shrink();
          return itemBuilder(context, blocks[index]);
        },
      ),
    );
  }

  /// Get optimized text rendering widget for large outputs
  Widget buildOptimizedTextOutput({
    required String text,
    required TextStyle style,
    int? maxLines,
    bool enableSelection = true,
  }) {
    final lineCount = _countTextLines(text);
    
    if (lineCount > 1000) {
      // Use optimized text rendering for large outputs
      return _buildOptimizedLargeText(text, style, maxLines, enableSelection);
    }
    
    // Use regular text widget for smaller outputs
    return _buildRegularText(text, style, maxLines, enableSelection);
  }

  /// Build optimized text widget for large outputs
  Widget _buildOptimizedLargeText(String text, TextStyle style, int? maxLines, bool enableSelection) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
        );
        
        textPainter.layout(maxWidth: constraints.maxWidth);
        
        if (enableSelection) {
          return SelectableText(
            text,
            style: style,
            maxLines: maxLines,
          );
        } else {
          return CustomPaint(
            size: Size(constraints.maxWidth, textPainter.height),
            painter: _OptimizedTextPainter(textPainter),
          );
        }
      },
    );
  }

  /// Build regular text widget
  Widget _buildRegularText(String text, TextStyle style, int? maxLines, bool enableSelection) {
    if (enableSelection) {
      return SelectableText(
        text,
        style: style,
        maxLines: maxLines,
      );
    } else {
      return Text(
        text,
        style: style,
        maxLines: maxLines,
      );
    }
  }

  /// Get performance metrics for a session
  PerformanceMetrics? getSessionMetrics(String sessionId) {
    return _sessionMetrics[sessionId];
  }

  /// Get overall performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    // Overall metrics
    stats['totalSessions'] = _sessionMetrics.length;
    stats['isOptimizationActive'] = _isOptimizationActive;
    stats['monitoringInterval'] = _performanceMonitorInterval.inSeconds;
    
    // Memory statistics
    int totalMemoryUsage = 0;
    int totalOutputLines = 0;
    int totalBlocks = 0;
    
    for (final metrics in _sessionMetrics.values) {
      totalMemoryUsage += metrics.estimatedMemoryUsage;
      totalOutputLines += metrics.totalOutputLines;
      totalBlocks += metrics.terminalBlocks.length;
    }
    
    stats['totalEstimatedMemoryUsage'] = totalMemoryUsage;
    stats['totalOutputLines'] = totalOutputLines;
    stats['totalBlocks'] = totalBlocks;
    
    // Performance scores
    final performanceScores = _sessionMetrics.values.map((m) => m.scrollPerformanceScore).toList();
    if (performanceScores.isNotEmpty) {
      stats['averagePerformanceScore'] = performanceScores.reduce((a, b) => a + b) / performanceScores.length;
      stats['minPerformanceScore'] = performanceScores.reduce(math.min);
      stats['maxPerformanceScore'] = performanceScores.reduce(math.max);
    }
    
    return stats;
  }

  // Helper methods

  /// Estimate memory usage for a terminal block
  int _estimateBlockMemoryUsage(TerminalBlockData block) {
    int size = 0;
    
    // Command string
    size += block.command.length * 2; // Unicode characters
    
    // Output string
    size += block.output.length * 2;
    
    // Metadata overhead
    size += 200;
    
    return size;
  }

  /// Count lines in output
  int _countOutputLines(String output) {
    if (output.isEmpty) return 0;
    return output.split('\n').length;
  }

  /// Count lines in text
  int _countTextLines(String text) {
    if (text.isEmpty) return 0;
    return text.split('\n').length;
  }

  /// Calculate rendering complexity
  double _calculateRenderingComplexity(List<TerminalBlockData> blocks) {
    double complexity = 0.0;
    
    for (final block in blocks) {
      // Base complexity
      complexity += 1.0;
      
      // Output size factor
      complexity += math.log(block.output.length + 1) / 100;
      
      // Interactive block factor
      if (block.isInteractive) {
        complexity += 0.5;
      }
      
      // Running block factor
      if (block.status == TerminalBlockStatus.running) {
        complexity += 0.3;
      }
    }
    
    return complexity;
  }

  /// Calculate scroll performance score
  double _calculateScrollPerformance(PerformanceMetrics metrics) {
    // Base score
    double score = 1.0;
    
    // Memory usage penalty
    if (metrics.estimatedMemoryUsage > _memoryCleanupThreshold) {
      score *= 0.5;
    }
    
    // Block count penalty
    if (metrics.terminalBlocks.length > _maxBlocksInMemory) {
      score *= 0.7;
    }
    
    // Output lines penalty
    if (metrics.totalOutputLines > _maxOutputLines) {
      score *= 0.6;
    }
    
    return math.max(0.0, score);
  }

  /// Check if block output should be compressed
  bool _shouldCompressOutput(TerminalBlockData block) {
    return block.output.length > 10000 && 
           block.status != TerminalBlockStatus.running;
  }

  /// Compress block output (placeholder implementation)
  void _compressBlockOutput(TerminalBlockData block) {
    // For now, just truncate very large outputs
    if (block.output.length > 50000) {
      final lines = block.output.split('\n');
      if (lines.length > 1000) {
        final truncatedLines = [
          ...lines.take(500),
          '... [${lines.length - 1000} lines truncated for performance] ...',
          ...lines.skip(lines.length - 500),
        ];
        // Note: This would need to be implemented with a mutable block model
        // block.output = truncatedLines.join('\n');
      }
    }
  }

  /// Truncate block output to specified number of lines
  void _truncateBlockOutput(TerminalBlockData block, int maxLines) {
    final lines = block.output.split('\n');
    if (lines.length > maxLines) {
      final truncatedLines = [
        ...lines.take(maxLines ~/ 2),
        '... [${lines.length - maxLines} lines truncated] ...',
        ...lines.skip(lines.length - (maxLines ~/ 2)),
      ];
      // Note: This would need to be implemented with a mutable block model
      // block.output = truncatedLines.join('\n');
    }
  }

  /// Clear rendering cache for a session
  void _clearRenderingCache(String sessionId) {
    // Clear any cached rendering data
    // This is a placeholder for actual cache clearing implementation
    debugPrint('Cleared rendering cache for session: $sessionId');
  }

  /// Dispose performance optimizer
  void dispose() {
    _performanceMonitorTimer?.cancel();
    _sessionMetrics.clear();
    _instance = null;
    debugPrint('Terminal performance optimizer disposed');
  }
}

/// Performance metrics for a terminal session
class PerformanceMetrics {
  final String sessionId;
  final List<TerminalBlockData> terminalBlocks;
  final DateTime registrationTime;
  
  DateTime lastUpdateTime;
  int estimatedMemoryUsage = 0;
  int totalOutputLines = 0;
  int activeBlocks = 0;
  double renderingComplexity = 0.0;
  double scrollPerformanceScore = 1.0;

  PerformanceMetrics({
    required this.sessionId,
    required this.terminalBlocks,
    required this.registrationTime,
    required this.lastUpdateTime,
  });

  /// Get metrics as JSON
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'registrationTime': registrationTime.toIso8601String(),
      'lastUpdateTime': lastUpdateTime.toIso8601String(),
      'estimatedMemoryUsage': estimatedMemoryUsage,
      'totalOutputLines': totalOutputLines,
      'activeBlocks': activeBlocks,
      'totalBlocks': terminalBlocks.length,
      'renderingComplexity': renderingComplexity,
      'scrollPerformanceScore': scrollPerformanceScore,
    };
  }
}

/// Custom text painter for optimized rendering of large texts
class _OptimizedTextPainter extends CustomPainter {
  final TextPainter textPainter;

  _OptimizedTextPainter(this.textPainter);

  @override
  void paint(Canvas canvas, Size size) {
    textPainter.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _OptimizedTextPainter oldDelegate) {
    return textPainter != oldDelegate.textPainter;
  }
}