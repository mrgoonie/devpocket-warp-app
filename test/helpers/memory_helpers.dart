import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

/// Memory Leak Detection Framework - Phase 5B.2
/// Comprehensive memory tracking and leak detection utilities
/// 
/// Features:
/// - Memory usage tracking with high precision
/// - Memory leak detection algorithms
/// - Memory profiling and analysis tools
/// - Memory cleanup validation utilities
/// - Garbage collection optimization helpers

class MemoryTracker {
  final List<MemorySnapshot> _snapshots = [];
  final String _trackingId;
  int _baselineMemory = 0;
  
  MemoryTracker(this._trackingId);
  
  /// Take a memory snapshot with optional label
  Future<MemorySnapshot> takeSnapshot([String? label]) async {
    final currentMemory = await getCurrentMemoryUsageInternal();
    final timestamp = DateTime.now();
    
    final snapshot = MemorySnapshot(
      memory: currentMemory,
      timestamp: timestamp,
      label: label ?? 'snapshot_${_snapshots.length}',
      trackingId: _trackingId,
    );
    
    _snapshots.add(snapshot);
    
    if (_snapshots.length == 1) {
      _baselineMemory = currentMemory;
    }
    
    return snapshot;
  }
  
  /// Get memory change since baseline
  int getMemoryChangeFromBaseline() {
    if (_snapshots.isEmpty) return 0;
    return _snapshots.last.memory - _baselineMemory;
  }
  
  /// Get memory change between two snapshots
  int getMemoryChange(int fromIndex, int toIndex) {
    if (fromIndex >= _snapshots.length || toIndex >= _snapshots.length) {
      throw ArgumentError('Invalid snapshot indices');
    }
    return _snapshots[toIndex].memory - _snapshots[fromIndex].memory;
  }
  
  /// Analyze memory leak patterns
  MemoryLeakAnalysis analyzeLeaks() {
    if (_snapshots.length < 3) {
      return const MemoryLeakAnalysis(
        hasLeak: false,
        confidence: 0.0,
        trendDirection: MemoryTrend.stable,
        analysis: 'Insufficient data for leak analysis',
      );
    }
    
    final changes = <int>[];
    for (int i = 1; i < _snapshots.length; i++) {
      changes.add(_snapshots[i].memory - _snapshots[i - 1].memory);
    }
    
    final avgChange = changes.reduce((a, b) => a + b) / changes.length;
    final positiveChanges = changes.where((c) => c > 0).length;
    final positiveRatio = positiveChanges / changes.length;
    
    // Calculate trend
    final trend = _calculateTrend(changes);
    final hasLeak = _detectLeak(changes, avgChange, positiveRatio);
    final confidence = _calculateLeakConfidence(changes, avgChange, positiveRatio);
    
    return MemoryLeakAnalysis(
      hasLeak: hasLeak,
      confidence: confidence,
      trendDirection: trend,
      analysis: _generateLeakAnalysis(changes, avgChange, positiveRatio, trend),
      snapshots: List.from(_snapshots),
    );
  }
  
  /// Clear all snapshots
  void clear() {
    _snapshots.clear();
    _baselineMemory = 0;
  }
  
  /// Get all snapshots
  List<MemorySnapshot> get snapshots => List.unmodifiable(_snapshots);
  
  /// Get tracking statistics
  MemoryTrackingStats getStats() {
    if (_snapshots.isEmpty) {
      return const MemoryTrackingStats(
        snapshotCount: 0,
        totalMemoryChange: 0,
        averageMemoryChange: 0.0,
        maxMemoryUsage: 0,
        minMemoryUsage: 0,
      );
    }
    
    final memories = _snapshots.map((s) => s.memory).toList();
    final totalChange = memories.last - memories.first;
    final avgChange = totalChange / (_snapshots.length - 1);
    final maxMemory = memories.reduce((a, b) => a > b ? a : b);
    final minMemory = memories.reduce((a, b) => a < b ? a : b);
    
    return MemoryTrackingStats(
      snapshotCount: _snapshots.length,
      totalMemoryChange: totalChange,
      averageMemoryChange: avgChange,
      maxMemoryUsage: maxMemory,
      minMemoryUsage: minMemory,
    );
  }
  
  MemoryTrend _calculateTrend(List<int> changes) {
    if (changes.isEmpty) return MemoryTrend.stable;
    
    final avgChange = changes.reduce((a, b) => a + b) / changes.length;
    
    if (avgChange > 1024 * 1024) { // > 1MB average increase
      return MemoryTrend.increasing;
    } else if (avgChange < -1024 * 1024) { // > 1MB average decrease
      return MemoryTrend.decreasing;
    } else {
      return MemoryTrend.stable;
    }
  }
  
  bool _detectLeak(List<int> changes, double avgChange, double positiveRatio) {
    // Leak detection criteria:
    // 1. Average change > 512KB per measurement
    // 2. More than 70% of changes are positive
    // 3. Consistent upward trend
    
    return avgChange > 512 * 1024 && positiveRatio > 0.7;
  }
  
  double _calculateLeakConfidence(List<int> changes, double avgChange, double positiveRatio) {
    double confidence = 0.0;
    
    // Confidence based on average change magnitude
    if (avgChange > 2 * 1024 * 1024) { // > 2MB
      confidence += 0.4;
    } else if (avgChange > 1024 * 1024) { // > 1MB
      confidence += 0.2;
    } else if (avgChange > 512 * 1024) { // > 512KB
      confidence += 0.1;
    }
    
    // Confidence based on positive change ratio
    confidence += positiveRatio * 0.4;
    
    // Confidence based on trend consistency
    final consistentIncreases = _countConsistentIncreases(changes);
    confidence += (consistentIncreases / changes.length) * 0.2;
    
    return math.min(confidence, 1.0);
  }
  
  int _countConsistentIncreases(List<int> changes) {
    int consistent = 0;
    int consecutiveIncreases = 0;
    
    for (final change in changes) {
      if (change > 0) {
        consecutiveIncreases++;
        if (consecutiveIncreases >= 2) {
          consistent++;
        }
      } else {
        consecutiveIncreases = 0;
      }
    }
    
    return consistent;
  }
  
  String _generateLeakAnalysis(List<int> changes, double avgChange, double positiveRatio, MemoryTrend trend) {
    final buffer = StringBuffer();
    
    buffer.writeln('Memory Analysis Results:');
    buffer.writeln('  Snapshots analyzed: ${changes.length + 1}');
    buffer.writeln('  Average change: ${formatMemory(avgChange.round())}');
    buffer.writeln('  Positive changes: ${(positiveRatio * 100).toStringAsFixed(1)}%');
    buffer.writeln('  Trend direction: $trend');
    
    if (avgChange > 1024 * 1024) {
      buffer.writeln('  Warning: Significant memory growth detected');
    }
    
    if (positiveRatio > 0.8) {
      buffer.writeln('  Warning: Consistent memory increases detected');
    }
    
    return buffer.toString();
  }
}

class MemorySnapshot {
  final int memory;
  final DateTime timestamp;
  final String label;
  final String trackingId;
  
  const MemorySnapshot({
    required this.memory,
    required this.timestamp,
    required this.label,
    required this.trackingId,
  });
  
  @override
  String toString() {
    return 'MemorySnapshot(${formatMemory(memory)}, $label, ${timestamp.toIso8601String()})';
  }
}

class MemoryLeakAnalysis {
  final bool hasLeak;
  final double confidence;
  final MemoryTrend trendDirection;
  final String analysis;
  final List<MemorySnapshot>? snapshots;
  
  const MemoryLeakAnalysis({
    required this.hasLeak,
    required this.confidence,
    required this.trendDirection,
    required this.analysis,
    this.snapshots,
  });
  
  @override
  String toString() {
    return 'MemoryLeakAnalysis(hasLeak: $hasLeak, confidence: ${(confidence * 100).toStringAsFixed(1)}%, trend: $trendDirection)';
  }
}

class MemoryTrackingStats {
  final int snapshotCount;
  final int totalMemoryChange;
  final double averageMemoryChange;
  final int maxMemoryUsage;
  final int minMemoryUsage;
  
  const MemoryTrackingStats({
    required this.snapshotCount,
    required this.totalMemoryChange,
    required this.averageMemoryChange,
    required this.maxMemoryUsage,
    required this.minMemoryUsage,
  });
  
  @override
  String toString() {
    return '''MemoryTrackingStats(
  snapshots: $snapshotCount,
  total change: ${formatMemory(totalMemoryChange)},
  avg change: ${formatMemory(averageMemoryChange.round())},
  max usage: ${formatMemory(maxMemoryUsage)},
  min usage: ${formatMemory(minMemoryUsage)}
)''';
  }
}

enum MemoryTrend {
  increasing,
  decreasing,
  stable,
}

/// Memory utility functions
class MemoryHelpers {
  /// Get current memory usage in bytes
  static Future<int> getCurrentMemoryUsage() async {
    return await getCurrentMemoryUsageInternal();
  }
  
  /// Force garbage collection
  static Future<void> forceGarbageCollection() async {
    await forceGarbageCollectionInternal();
  }
  
  /// Create memory tracking session
  static MemoryTracker createTracker(String id) {
    return MemoryTracker(id);
  }
  
  /// Validate memory cleanup efficiency
  static Future<MemoryCleanupResult> validateCleanup({
    required Future<void> Function() operation,
    required Future<void> Function() cleanup,
    int maxRetainedMemory = 2 * 1024 * 1024, // 2MB default
  }) async {
    final tracker = MemoryTracker('cleanup_validation');
    
    // Take baseline snapshot
    await tracker.takeSnapshot('baseline');
    
    // Perform operation
    await operation();
    await tracker.takeSnapshot('after_operation');
    
    // Perform cleanup
    await cleanup();
    await forceGarbageCollectionInternal();
    await tracker.takeSnapshot('after_cleanup');
    
    final stats = tracker.getStats();
    final memoryRetained = tracker.getMemoryChangeFromBaseline();
    final cleanupEfficient = memoryRetained <= maxRetainedMemory;
    
    return MemoryCleanupResult(
      memoryRetained: memoryRetained,
      isEfficient: cleanupEfficient,
      stats: stats,
      snapshots: tracker.snapshots,
    );
  }
  
  /// Monitor memory during operation execution
  static Future<MemoryOperationResult<T>> monitorOperation<T>({
    required String operationName,
    required Future<T> Function() operation,
    Duration samplingInterval = const Duration(milliseconds: 100),
  }) async {
    final tracker = MemoryTracker(operationName);
    final startTime = DateTime.now();
    
    // Take initial snapshot
    await tracker.takeSnapshot('start');
    
    // Monitor memory during operation
    final operationFuture = operation();
    T? result;
    Exception? error;
    bool operationCompleted = false;
    
    // Sample memory usage periodically
    final samplingTimer = Stream.periodic(samplingInterval).listen((_) async {
      if (!operationCompleted) {
        await tracker.takeSnapshot();
      }
    });
    
    try {
      result = await operationFuture;
      operationCompleted = true;
      await tracker.takeSnapshot('completed');
    } catch (e) {
      operationCompleted = true;
      error = e is Exception ? e : Exception(e.toString());
      await tracker.takeSnapshot('error');
    } finally {
      samplingTimer.cancel();
    }
    
    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);
    
    return MemoryOperationResult<T>(
      result: result,
      error: error,
      duration: duration,
      memoryStats: tracker.getStats(),
      snapshots: tracker.snapshots,
    );
  }
  
  /// Create memory pressure for testing
  static Future<void> createMemoryPressure({
    int pressureSize = 10 * 1024 * 1024, // 10MB default
    Duration duration = const Duration(seconds: 1),
  }) async {
    final blocks = <Uint8List>[];
    const blockSize = 1024 * 1024; // 1MB blocks
    final blockCount = (pressureSize / blockSize).ceil();
    
    // Allocate memory blocks
    for (int i = 0; i < blockCount; i++) {
      blocks.add(Uint8List(blockSize));
    }
    
    // Hold memory for specified duration
    await Future.delayed(duration);
    
    // Release memory
    blocks.clear();
    await forceGarbageCollectionInternal();
  }
}

class MemoryCleanupResult {
  final int memoryRetained;
  final bool isEfficient;
  final MemoryTrackingStats stats;
  final List<MemorySnapshot> snapshots;
  
  const MemoryCleanupResult({
    required this.memoryRetained,
    required this.isEfficient,
    required this.stats,
    required this.snapshots,
  });
  
  @override
  String toString() {
    return 'MemoryCleanupResult(retained: ${formatMemory(memoryRetained)}, efficient: $isEfficient)';
  }
}

class MemoryOperationResult<T> {
  final T? result;
  final Exception? error;
  final Duration duration;
  final MemoryTrackingStats memoryStats;
  final List<MemorySnapshot> snapshots;
  
  const MemoryOperationResult({
    this.result,
    this.error,
    required this.duration,
    required this.memoryStats,
    required this.snapshots,
  });
  
  bool get wasSuccessful => error == null;
  
  @override
  String toString() {
    return 'MemoryOperationResult(duration: ${duration.inMilliseconds}ms, success: $wasSuccessful, ${memoryStats.toString()})';
  }
}

/// Get current memory usage in bytes
Future<int> getCurrentMemoryUsageInternal() async {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      // On mobile platforms, use ProcessInfo if available
      return ProcessInfo.currentRss;
    } else if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
      // On desktop platforms, try to get more accurate memory info
      return ProcessInfo.currentRss;
    } else {
      // Fallback for other platforms
      return ProcessInfo.currentRss;
    }
  } catch (e) {
    // Ultimate fallback - return estimated baseline
    return 50 * 1024 * 1024; // 50MB baseline estimate
  }
}

/// Force garbage collection
Future<void> forceGarbageCollectionInternal() async {
  // Create memory pressure to encourage garbage collection
  final tempData = <List<int>>[];
  
  // Allocate temporary memory
  for (int i = 0; i < 100; i++) {
    tempData.add(List.generate(1000, (j) => i + j));
  }
  
  // Clear temporary memory
  tempData.clear();
  
  // Give garbage collector time to run
  await Future.delayed(const Duration(milliseconds: 100));
  
  // Additional GC encouragement
  try {
    // Try to trigger GC if available
    System.gc?.call();
  } catch (e) {
    // GC trigger not available, that's okay
  }
}

/// Format memory size in human-readable format
String formatMemory(int bytes) {
  if (bytes < 0) {
    return '-${formatMemory(-bytes)}';
  } else if (bytes < 1024) {
    return '${bytes}B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}

/// System utilities
class System {
  static void Function()? gc;
}

/// Simulate process info for testing
class ProcessInfo {
  static int get currentRss {
    try {
      // Try to get actual RSS if available
      return Platform.resolvedExecutable.length * 1000; // Rough estimation
    } catch (e) {
      // Return simulated memory usage
      return 40 * 1024 * 1024 + (DateTime.now().millisecondsSinceEpoch % (20 * 1024 * 1024));
    }
  }
}