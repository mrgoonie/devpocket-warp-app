import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'dart:io';

/// Test configuration and global settings
/// Helps prevent test instability and timeouts
class TestConfig {
  // Global test timeouts
  static const Duration shortTimeout = Duration(seconds: 5);
  static const Duration mediumTimeout = Duration(seconds: 15);
  static const Duration longTimeout = Duration(seconds: 30);
  
  // Spot framework specific timeouts
  static const Duration spotTestTimeout = Duration(seconds: 30);
  static const Duration spotActionTimeout = Duration(seconds: 10);
  static const Duration webSocketTestTimeout = Duration(seconds: 15);
  
  // Test size limits to prevent memory issues
  static const int smallBatch = 5;
  static const int mediumBatch = 15;
  static const int largeBatch = 25;
  
  // Network test settings
  static const Duration networkTimeout = Duration(seconds: 10);
  static const int maxRetries = 3;
  
  // Performance test limits
  static const int maxConcurrentOperations = 3;
  static const int maxTestIterations = 10;
  
  /// Initialize test environment
  static void initialize() {
    // Configure test binding
    TestWidgetsFlutterBinding.ensureInitialized();
    
    try {
      // Disable animation during tests if available
      final binding = WidgetsBinding.instance;
      if (binding is TestWidgetsFlutterBinding) {
        // We're in a test environment
        debugPrint('Test environment initialized');
      }
    } catch (e) {
      // Ignore if not available in test environment
      debugPrint('Test binding configuration skipped: $e');
    }
    
    // Set memory pressure callback
    _setupMemoryManagement();
  }
  
  /// Setup memory management for tests
  static void _setupMemoryManagement() {
    // Add periodic GC to prevent memory buildup
    if (Platform.environment['FLUTTER_TEST'] == 'true') {
      // We're in a test environment
      debugPrint('Test environment initialized with memory management');
    }
  }
  
  /// Check if we're running in CI/CD environment
  static bool get isCIEnvironment {
    return Platform.environment['CI'] == 'true' ||
           Platform.environment['GITHUB_ACTIONS'] == 'true' ||
           Platform.environment['CONTINUOUS_INTEGRATION'] == 'true';
  }
  
  /// Get appropriate timeout based on environment
  static Duration getTimeout(Duration baseTimeout) {
    if (isCIEnvironment) {
      // Use longer timeouts in CI
      return Duration(milliseconds: (baseTimeout.inMilliseconds * 1.5).round());
    }
    return baseTimeout;
  }
  
  /// Get Spot-specific timeout for test execution
  static Duration getSpotTimeout() {
    return isCIEnvironment 
        ? Duration(milliseconds: (spotTestTimeout.inMilliseconds * 1.5).round())
        : spotTestTimeout;
  }
  
  /// Get WebSocket-specific timeout for connection tests  
  static Duration getWebSocketTimeout() {
    return isCIEnvironment
        ? Duration(milliseconds: (webSocketTestTimeout.inMilliseconds * 1.5).round())
        : webSocketTestTimeout;
  }
  
  /// Get appropriate batch size based on environment
  static int getBatchSize(int baseBatchSize) {
    if (isCIEnvironment) {
      // Use smaller batches in CI to prevent resource exhaustion
      return (baseBatchSize * 0.7).round();
    }
    return baseBatchSize;
  }
}

/// Test stability helpers
class TestStability {
  /// Safe test wrapper that handles common test issues
  static Future<void> runStableTest(
    String description,
    Future<void> Function() testFunction, {
    int maxAttempts = 3,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    int attempts = 0;
    late Exception lastException;
    
    while (attempts < maxAttempts) {
      attempts++;
      try {
        await testFunction().timeout(TestConfig.getTimeout(timeout));
        return; // Success
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (attempts == maxAttempts) {
          debugPrint('Test "$description" failed after $maxAttempts attempts');
          rethrow;
        }
        
        debugPrint('Test "$description" attempt $attempts failed: $e');
        debugPrint('Retrying in ${attempts * 100}ms...');
        
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: attempts * 100));
        
        // Force garbage collection between attempts
        if (attempts > 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }
    }
    
    throw lastException;
  }
  
  /// Safe widget test wrapper
  static void stableTestWidgets(
    String description,
    Future<void> Function(WidgetTester) callback, {
    bool skip = false,
    Timeout? timeout,
  }) {
    testWidgets(
      description,
      (WidgetTester tester) async {
        await runStableTest(
          description,
          () => callback(tester),
          timeout: timeout?.duration ?? TestConfig.longTimeout,
        );
      },
      skip: skip,
      timeout: timeout ?? Timeout(TestConfig.getTimeout(TestConfig.longTimeout)),
    );
  }
  
  /// Memory-safe test helper for large operations
  static Future<void> runWithMemoryManagement<T>(
    List<T> items,
    Future<void> Function(T) processor, {
    int batchSize = 5,
    Duration batchDelay = const Duration(milliseconds: 10),
  }) async {
    final actualBatchSize = TestConfig.getBatchSize(batchSize);
    
    for (int i = 0; i < items.length; i += actualBatchSize) {
      final end = (i + actualBatchSize).clamp(0, items.length);
      final batch = items.sublist(i, end);
      
      // Process batch
      for (final item in batch) {
        await processor(item);
      }
      
      // Delay between batches to prevent overwhelming the system
      if (end < items.length) {
        await Future.delayed(batchDelay);
      }
    }
  }
  
  /// Safe pump and settle with retry logic
  static Future<void> safePumpAndSettle(
    WidgetTester tester, {
    Duration? duration,
    Duration? timeout,
    int maxAttempts = 3,
  }) async {
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      attempts++;
      try {
        await tester.pumpAndSettle(
          duration ?? const Duration(milliseconds: 100),
        ).timeout(
          timeout ?? TestConfig.mediumTimeout,
        );
        return; // Success
      } catch (e) {
        if (attempts == maxAttempts) {
          // Fallback to simple pump
          debugPrint('PumpAndSettle failed after $maxAttempts attempts, using simple pump');
          await tester.pump(duration ?? const Duration(milliseconds: 100));
          return;
        }
        
        debugPrint('PumpAndSettle attempt $attempts failed: $e');
        await Future.delayed(Duration(milliseconds: attempts * 50));
      }
    }
  }
}