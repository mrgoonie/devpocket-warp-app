import 'dart:io';
import 'dart:convert';

/// Performance Benchmark Configuration - Phase 5D.1
/// Establishes baseline metrics and regression detection
/// 
/// Features:
/// - Baseline performance metric definitions
/// - Performance threshold configurations
/// - Regression detection algorithms
/// - Benchmark result storage and comparison
/// - Performance monitoring utilities

/// Performance benchmark thresholds and targets
class PerformanceBenchmarks {
  // Crypto Operations Performance Targets
  static const Map<String, Duration> cryptoTimeouts = {
    'ssh_key_generation_ed25519': Duration(seconds: 1),
    'ssh_key_generation_rsa2048': Duration(seconds: 5),
    'fingerprint_calculation': Duration(milliseconds: 100),
    'encryption_aes_gcm': Duration(milliseconds: 50),
    'decryption_aes_gcm': Duration(milliseconds: 50),
    'secure_storage_operation': Duration(milliseconds: 200),
  };
  
  // Memory Usage Thresholds
  static const Map<String, int> memoryThresholds = {
    'base_app_memory': 100 * 1024 * 1024, // 100MB
    'ssh_connection_overhead': 10 * 1024 * 1024, // 10MB per connection
    'websocket_connection_overhead': 5 * 1024 * 1024, // 5MB per connection
    'crypto_operation_memory': 2 * 1024 * 1024, // 2MB for crypto ops
    'terminal_session_memory': 15 * 1024 * 1024, // 15MB per session
  };
  
  // Load Testing Performance Targets
  static const Map<String, double> loadTestingTargets = {
    'concurrent_ssh_connections': 5.0, // minimum connections supported
    'websocket_message_throughput': 100.0, // messages per second
    'api_response_time_avg': 500.0, // milliseconds
    'terminal_command_response': 100.0, // milliseconds
    'concurrent_user_sessions': 5.0, // simultaneous user sessions
  };
  
  // Overall Application Performance Targets
  static const Map<String, Duration> appPerformanceTargets = {
    'app_startup_time': Duration(seconds: 3),
    'navigation_transition': Duration(milliseconds: 200),
    'terminal_connection_establishment': Duration(seconds: 5),
    'background_task_efficiency': Duration(milliseconds: 100),
  };
  
  // Performance Regression Detection Thresholds
  static const Map<String, double> regressionThresholds = {
    'warning_threshold': 1.2, // 20% slower than baseline
    'critical_threshold': 1.5, // 50% slower than baseline
    'memory_growth_threshold': 1.3, // 30% more memory than baseline
    'success_rate_threshold': 0.8, // 80% minimum success rate
  };
  
  /// Get timeout for specific operation
  static Duration getTimeout(String operation) {
    return cryptoTimeouts[operation] ?? const Duration(seconds: 30);
  }
  
  /// Get memory threshold for specific component
  static int getMemoryThreshold(String component) {
    return memoryThresholds[component] ?? (50 * 1024 * 1024); // 50MB default
  }
  
  /// Get load testing target for specific metric
  static double getLoadTarget(String metric) {
    return loadTestingTargets[metric] ?? 1.0;
  }
  
  /// Get app performance target
  static Duration getAppTarget(String target) {
    return appPerformanceTargets[target] ?? const Duration(seconds: 10);
  }
  
  /// Check if performance meets threshold
  static bool meetsThreshold(String operation, Duration actual) {
    final threshold = getTimeout(operation);
    return actual <= threshold;
  }
  
  /// Check if memory usage is within threshold
  static bool isMemoryWithinThreshold(String component, int actualBytes) {
    final threshold = getMemoryThreshold(component);
    return actualBytes <= threshold;
  }
  
  /// Calculate performance regression level
  static PerformanceRegression calculateRegression(double baseline, double current) {
    if (baseline <= 0) {
      return PerformanceRegression.noBaseline;
    }
    
    final ratio = current / baseline;
    
    if (ratio >= regressionThresholds['critical_threshold']!) {
      return PerformanceRegression.critical;
    } else if (ratio >= regressionThresholds['warning_threshold']!) {
      return PerformanceRegression.warning;
    } else if (ratio <= 0.8) { // 20% improvement
      return PerformanceRegression.improvement;
    } else {
      return PerformanceRegression.normal;
    }
  }
}

/// Performance regression severity levels
enum PerformanceRegression {
  improvement,
  normal,
  warning,
  critical,
  noBaseline,
}

/// Performance benchmark result
class BenchmarkResult {
  final String testName;
  final String operation;
  final DateTime timestamp;
  final double value; // milliseconds, bytes, or count
  final String unit; // 'ms', 'bytes', 'count', etc.
  final bool success;
  final Map<String, dynamic> metadata;
  
  const BenchmarkResult({
    required this.testName,
    required this.operation,
    required this.timestamp,
    required this.value,
    required this.unit,
    required this.success,
    this.metadata = const {},
  });
  
  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'testName': testName,
      'operation': operation,
      'timestamp': timestamp.toIso8601String(),
      'value': value,
      'unit': unit,
      'success': success,
      'metadata': metadata,
    };
  }
  
  /// Create from JSON
  factory BenchmarkResult.fromJson(Map<String, dynamic> json) {
    return BenchmarkResult(
      testName: json['testName'],
      operation: json['operation'],
      timestamp: DateTime.parse(json['timestamp']),
      value: json['value'].toDouble(),
      unit: json['unit'],
      success: json['success'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }
  
  @override
  String toString() {
    return 'BenchmarkResult($operation: $value$unit, success: $success)';
  }
}

/// Performance benchmark storage and comparison
class BenchmarkStorage {
  static const String _benchmarkFile = 'performance_benchmarks.json';
  
  /// Save benchmark results
  static Future<void> saveBenchmarks(List<BenchmarkResult> results) async {
    try {
      final file = File(_benchmarkFile);
      final jsonData = results.map((r) => r.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonData));
    } catch (e) {
      print('Failed to save benchmarks: $e');
    }
  }
  
  /// Load benchmark results
  static Future<List<BenchmarkResult>> loadBenchmarks() async {
    try {
      final file = File(_benchmarkFile);
      if (!await file.exists()) {
        return [];
      }
      
      final jsonString = await file.readAsString();
      final jsonList = jsonDecode(jsonString) as List;
      
      return jsonList
          .map((json) => BenchmarkResult.fromJson(json))
          .toList();
    } catch (e) {
      print('Failed to load benchmarks: $e');
      return [];
    }
  }
  
  /// Get baseline for specific operation
  static Future<BenchmarkResult?> getBaseline(String operation) async {
    final benchmarks = await loadBenchmarks();
    final operationBenchmarks = benchmarks
        .where((b) => b.operation == operation && b.success)
        .toList();
    
    if (operationBenchmarks.isEmpty) {
      return null;
    }
    
    // Use median of recent successful results as baseline
    operationBenchmarks.sort((a, b) => a.value.compareTo(b.value));
    return operationBenchmarks[operationBenchmarks.length ~/ 2];
  }
  
  /// Compare current result with baseline
  static Future<BenchmarkComparison> compareWithBaseline(
    BenchmarkResult current,
  ) async {
    final baseline = await getBaseline(current.operation);
    
    if (baseline == null) {
      return BenchmarkComparison(
        current: current,
        baseline: null,
        regression: PerformanceRegression.noBaseline,
        percentageChange: 0.0,
        analysis: 'No baseline available for ${current.operation}',
      );
    }
    
    final percentageChange = ((current.value - baseline.value) / baseline.value) * 100;
    final regression = PerformanceBenchmarks.calculateRegression(baseline.value, current.value);
    
    String analysis;
    switch (regression) {
      case PerformanceRegression.improvement:
        analysis = 'Performance improved by ${percentageChange.abs().toStringAsFixed(1)}%';
        break;
      case PerformanceRegression.normal:
        analysis = 'Performance within normal range (${percentageChange.toStringAsFixed(1)}%)';
        break;
      case PerformanceRegression.warning:
        analysis = 'Performance regression detected (${percentageChange.toStringAsFixed(1)}% slower)';
        break;
      case PerformanceRegression.critical:
        analysis = 'Critical performance regression (${percentageChange.toStringAsFixed(1)}% slower)';
        break;
      case PerformanceRegression.noBaseline:
        analysis = 'No baseline available';
        break;
    }
    
    return BenchmarkComparison(
      current: current,
      baseline: baseline,
      regression: regression,
      percentageChange: percentageChange,
      analysis: analysis,
    );
  }
  
  /// Clear old benchmarks (keep only recent ones)
  static Future<void> cleanupOldBenchmarks({int keepDays = 30}) async {
    final benchmarks = await loadBenchmarks();
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    
    final recentBenchmarks = benchmarks
        .where((b) => b.timestamp.isAfter(cutoffDate))
        .toList();
    
    await saveBenchmarks(recentBenchmarks);
  }
}

/// Benchmark comparison result
class BenchmarkComparison {
  final BenchmarkResult current;
  final BenchmarkResult? baseline;
  final PerformanceRegression regression;
  final double percentageChange;
  final String analysis;
  
  const BenchmarkComparison({
    required this.current,
    required this.baseline,
    required this.regression,
    required this.percentageChange,
    required this.analysis,
  });
  
  bool get isRegression => regression == PerformanceRegression.warning || 
                          regression == PerformanceRegression.critical;
  
  bool get isImprovement => regression == PerformanceRegression.improvement;
  
  @override
  String toString() {
    return 'BenchmarkComparison(${current.operation}: $analysis)';
  }
}

/// Performance monitoring utilities
class PerformanceMonitor {
  static final List<BenchmarkResult> _sessionResults = [];
  
  /// Record a benchmark result
  static void recordBenchmark(BenchmarkResult result) {
    _sessionResults.add(result);
  }
  
  /// Create benchmark result for timing
  static BenchmarkResult createTimingResult({
    required String testName,
    required String operation,
    required Duration duration,
    required bool success,
    Map<String, dynamic> metadata = const {},
  }) {
    return BenchmarkResult(
      testName: testName,
      operation: operation,
      timestamp: DateTime.now(),
      value: duration.inMicroseconds / 1000.0, // Convert to milliseconds
      unit: 'ms',
      success: success,
      metadata: metadata,
    );
  }
  
  /// Create benchmark result for memory usage
  static BenchmarkResult createMemoryResult({
    required String testName,
    required String operation,
    required int bytes,
    required bool success,
    Map<String, dynamic> metadata = const {},
  }) {
    return BenchmarkResult(
      testName: testName,
      operation: operation,
      timestamp: DateTime.now(),
      value: bytes.toDouble(),
      unit: 'bytes',
      success: success,
      metadata: metadata,
    );
  }
  
  /// Create benchmark result for throughput
  static BenchmarkResult createThroughputResult({
    required String testName,
    required String operation,
    required double rate,
    required String unit,
    required bool success,
    Map<String, dynamic> metadata = const {},
  }) {
    return BenchmarkResult(
      testName: testName,
      operation: operation,
      timestamp: DateTime.now(),
      value: rate,
      unit: unit,
      success: success,
      metadata: metadata,
    );
  }
  
  /// Get session benchmark results
  static List<BenchmarkResult> getSessionResults() {
    return List.unmodifiable(_sessionResults);
  }
  
  /// Save all session results to storage
  static Future<void> saveSessionResults() async {
    if (_sessionResults.isEmpty) return;
    
    final existingBenchmarks = await BenchmarkStorage.loadBenchmarks();
    final allBenchmarks = [...existingBenchmarks, ..._sessionResults];
    
    await BenchmarkStorage.saveBenchmarks(allBenchmarks);
    
    print('Saved ${_sessionResults.length} benchmark results');
  }
  
  /// Generate performance report
  static Future<PerformanceReport> generateReport() async {
    final sessionResults = getSessionResults();
    final regressions = <BenchmarkComparison>[];
    final improvements = <BenchmarkComparison>[];
    final warnings = <String>[];
    
    // Compare each result with baseline
    for (final result in sessionResults) {
      final comparison = await BenchmarkStorage.compareWithBaseline(result);
      
      if (comparison.isRegression) {
        regressions.add(comparison);
        if (comparison.regression == PerformanceRegression.critical) {
          warnings.add('CRITICAL: ${comparison.analysis}');
        }
      } else if (comparison.isImprovement) {
        improvements.add(comparison);
      }
    }
    
    return PerformanceReport(
      timestamp: DateTime.now(),
      totalBenchmarks: sessionResults.length,
      successfulBenchmarks: sessionResults.where((r) => r.success).length,
      regressions: regressions,
      improvements: improvements,
      warnings: warnings,
      sessionResults: sessionResults,
    );
  }
  
  /// Clear session results
  static void clearSession() {
    _sessionResults.clear();
  }
  
  /// Validate performance against thresholds
  static List<String> validatePerformance(List<BenchmarkResult> results) {
    final violations = <String>[];
    
    for (final result in results) {
      if (!result.success) {
        violations.add('${result.operation} failed to execute');
        continue;
      }
      
      // Check timing thresholds
      if (result.unit == 'ms') {
        final duration = Duration(milliseconds: result.value.round());
        if (!PerformanceBenchmarks.meetsThreshold(result.operation, duration)) {
          final threshold = PerformanceBenchmarks.getTimeout(result.operation);
          violations.add('${result.operation} exceeded timeout: ${result.value}ms > ${threshold.inMilliseconds}ms');
        }
      }
      
      // Check memory thresholds
      if (result.unit == 'bytes') {
        if (!PerformanceBenchmarks.isMemoryWithinThreshold(result.operation, result.value.round())) {
          final threshold = PerformanceBenchmarks.getMemoryThreshold(result.operation);
          violations.add('${result.operation} exceeded memory threshold: ${result.value} > $threshold bytes');
        }
      }
    }
    
    return violations;
  }
}

/// Performance test report
class PerformanceReport {
  final DateTime timestamp;
  final int totalBenchmarks;
  final int successfulBenchmarks;
  final List<BenchmarkComparison> regressions;
  final List<BenchmarkComparison> improvements;
  final List<String> warnings;
  final List<BenchmarkResult> sessionResults;
  
  const PerformanceReport({
    required this.timestamp,
    required this.totalBenchmarks,
    required this.successfulBenchmarks,
    required this.regressions,
    required this.improvements,
    required this.warnings,
    required this.sessionResults,
  });
  
  double get successRate => totalBenchmarks > 0 ? successfulBenchmarks / totalBenchmarks : 0.0;
  
  bool get hasRegressions => regressions.isNotEmpty;
  bool get hasCriticalRegressions => regressions.any((r) => r.regression == PerformanceRegression.critical);
  bool get hasWarnings => warnings.isNotEmpty;
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Performance Report - ${timestamp.toIso8601String()}');
    buffer.writeln('Total Benchmarks: $totalBenchmarks');
    buffer.writeln('Successful: $successfulBenchmarks (${(successRate * 100).toStringAsFixed(1)}%)');
    buffer.writeln('Regressions: ${regressions.length}');
    buffer.writeln('Improvements: ${improvements.length}');
    
    if (hasWarnings) {
      buffer.writeln('\\nWARNINGS:');
      for (final warning in warnings) {
        buffer.writeln('  - $warning');
      }
    }
    
    if (hasRegressions) {
      buffer.writeln('\\nREGRESSIONS:');
      for (final regression in regressions) {
        buffer.writeln('  - ${regression.analysis}');
      }
    }
    
    if (improvements.isNotEmpty) {
      buffer.writeln('\\nIMPROVEMENTS:');
      for (final improvement in improvements) {
        buffer.writeln('  - ${improvement.analysis}');
      }
    }
    
    return buffer.toString();
  }
}

/// Format memory size for display
String formatMemorySize(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  } else if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  } else {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}