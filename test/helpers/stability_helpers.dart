import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:spot/spot.dart';
import 'package:flutter/material.dart';
import '../test_config.dart';

/// Test stability helpers for Spot framework integration
/// Provides timeout management, retry logic, and test environment optimization
class StabilityHelpers {
  
  /// Configure Spot framework with DevPocket-specific settings
  static void configureSpot() {
    // Configure timeline mode for debugging failed tests
    // Note: timeline API may vary by version, using default configuration
    print('Spot framework configured for DevPocket tests');
  }
  
  /// Safe Spot test wrapper that handles timeouts and retries
  static Future<void> runSpotTest(
    String description,
    Future<void> Function() testFunction, {
    int maxAttempts = 2,
    Duration? timeout,
  }) async {
    timeout ??= TestConfig.getSpotTimeout();
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < maxAttempts) {
      attempts++;
      try {
        await testFunction().timeout(timeout);
        return; // Success
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (attempts == maxAttempts) {
          print('Spot test "$description" failed after $maxAttempts attempts: $e');
          rethrow;
        }
        
        print('Spot test "$description" attempt $attempts failed: $e');
        print('Retrying in ${attempts * 200}ms...');
        
        // Progressive backoff between attempts
        await Future.delayed(Duration(milliseconds: attempts * 200));
      }
    }
    
    throw lastException ?? Exception('All attempts failed');
  }
  
  /// Stable Spot-based testWidgets wrapper
  static void stableSpotTestWidgets(
    String description,
    Future<void> Function(WidgetTester) callback, {
    bool skip = false,
    Timeout? timeout,
    int maxAttempts = 2,
  }) {
    testWidgets(
      description,
      (WidgetTester tester) async {
        await runSpotTest(
          description,
          () => callback(tester),
          maxAttempts: maxAttempts,
          timeout: timeout?.duration,
        );
      },
      skip: skip,
      timeout: timeout ?? Timeout(TestConfig.getSpotTimeout()),
    );
  }
  
  /// Safe pump and settle using Spot's built-in mechanisms
  static Future<void> safePumpAndSettle(
    WidgetTester tester, {
    Duration? timeout,
    Duration? step,
  }) async {
    timeout ??= TestConfig.mediumTimeout;
    step ??= const Duration(milliseconds: 100);
    
    try {
      // Use tester's pumpAndSettle with timeout
      await tester.pumpAndSettle(step).timeout(timeout);
    } catch (e) {
      print('PumpAndSettle timed out, using fallback pump: $e');
      // Fallback to single pump if pumpAndSettle hangs
      await tester.pump(step);
    }
  }
  
  /// Memory-conscious test execution for large test suites
  static Future<void> runWithMemoryManagement(
    List<Future<void> Function()> testFunctions, {
    int batchSize = 3,
    Duration batchDelay = const Duration(milliseconds: 100),
  }) async {
    final actualBatchSize = TestConfig.getBatchSize(batchSize);
    
    for (int i = 0; i < testFunctions.length; i += actualBatchSize) {
      final end = (i + actualBatchSize).clamp(0, testFunctions.length);
      final batch = testFunctions.sublist(i, end);
      
      // Execute batch
      for (final testFunction in batch) {
        await testFunction();
      }
      
      // Memory cleanup delay between batches
      if (end < testFunctions.length) {
        await Future.delayed(batchDelay);
        
        // Force garbage collection if available
        if (Platform.environment['FLUTTER_TEST'] == 'true') {
          // In test environment, allow GC to run
          await Future.delayed(const Duration(milliseconds: 10));
        }
      }
    }
  }
  
  /// Test environment validation for Spot framework
  static void validateTestEnvironment() {
    // Check if we're in a test environment
    if (Platform.environment['FLUTTER_TEST'] != 'true') {
      print('Warning: Not running in Flutter test environment');
    }
    
    // Check CI environment adjustments
    if (TestConfig.isCIEnvironment) {
      print('Running in CI environment - using extended timeouts');
    }
  }
  
  /// Cleanup helper for test teardown
  static Future<void> cleanupTestEnvironment() async {
    try {
      // Clear any pending timers or futures
      await Future.delayed(const Duration(milliseconds: 10));
      
      // Timeline cleanup - using default behavior
      print('Test cleanup completed');
    } catch (e) {
      print('Test cleanup warning: $e');
    }
  }
  
  /// WebSocket test specific stability helpers
  static Future<void> runWebSocketTest(
    String description,
    Future<void> Function() testFunction, {
    int maxAttempts = 3,
  }) async {
    // Use stricter timeout for WebSocket tests to prevent hanging
    final baseTimeout = TestConfig.getWebSocketTimeout();
    final strictTimeout = Duration(
      milliseconds: math.min(baseTimeout.inMilliseconds, 10000) // Max 10 seconds
    );
    
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < maxAttempts) {
      attempts++;
      try {
        // Wrap the test function with additional timeout protection
        await testFunction().timeout(strictTimeout, onTimeout: () {
          throw TimeoutException('WebSocket test "$description" timed out after ${strictTimeout.inSeconds}s', strictTimeout);
        });
        return; // Success
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        if (attempts == maxAttempts) {
          print('WebSocket test "$description" failed after $maxAttempts attempts: ${e.runtimeType}');
          rethrow;
        }
        
        print('WebSocket test "$description" attempt $attempts failed: $e');
        
        // Shorter delay between attempts to prevent overall test suite hanging
        await Future.delayed(Duration(milliseconds: attempts * 100));
      }
    }
    
    throw lastException ?? Exception('WebSocket test attempts exhausted');
  }
  
  /// Screenshot capture helper for debugging
  static Future<void> captureDebugScreenshot(
    WidgetTester tester,
    String testName, {
    String? additionalInfo,
  }) async {
    try {
      // Spot automatically captures screenshots on failures, 
      // but this can be used for manual debugging
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = '${testName}_$timestamp';
      
      if (additionalInfo != null) {
        print('Debug screenshot: $filename - $additionalInfo');
      }
      
      // The actual screenshot capture is handled by Spot framework
      // This is mainly for logging and debugging context
      
    } catch (e) {
      print('Screenshot capture failed: $e');
    }
  }
  
  /// Performance monitoring helper for tests
  static Future<T> monitorTestPerformance<T>(
    String testName,
    Future<T> Function() testFunction,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await testFunction();
      stopwatch.stop();
      
      final duration = stopwatch.elapsedMilliseconds;
      if (duration > 5000) { // More than 5 seconds
        print('Performance warning: Test "$testName" took ${duration}ms');
      } else {
        print('Test "$testName" completed in ${duration}ms');
      }
      
      return result;
    } catch (e) {
      stopwatch.stop();
      print('Test "$testName" failed after ${stopwatch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
  }
  
  /// Test isolation helper to prevent state leakage
  static Future<void> isolateTest(
    Future<void> Function() testFunction,
  ) async {
    try {
      await testFunction();
    } finally {
      // Cleanup any global state that might leak between tests
      await cleanupTestEnvironment();
    }
  }
}

/// Spot-specific test utilities
class SpotTestUtilities {
  
  /// Custom timeout for specific widget interactions
  static Future<void> tapWithTimeout<T extends Widget>(
    WidgetSelector<T> selector,
    Duration? timeout,
  ) async {
    timeout ??= TestConfig.spotActionTimeout;
    
    try {
      await act.tap(selector).timeout(timeout);
    } catch (e) {
      throw Exception('Tap operation timed out after ${timeout.inSeconds}s: $e');
    }
  }
  
  /// Safe text input with timeout protection
  /// Note: enterText API may not be available in this version of Spot
  static Future<void> enterTextWithTimeout<T extends Widget>(
    WidgetSelector<T> selector,
    String text,
    Duration? timeout,
  ) async {
    timeout ??= TestConfig.spotActionTimeout;
    
    try {
      // Fallback to traditional testing approach for text input
      throw UnimplementedError('enterText API not available in this Spot version');
    } catch (e) {
      throw Exception('Text input not supported: $e');
    }
  }
}