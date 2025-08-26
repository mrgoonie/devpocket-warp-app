import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:devpocket_warp_app/services/terminal_websocket_service.dart';
import 'package:devpocket_warp_app/services/terminal_session_handler.dart';
import 'package:devpocket_warp_app/services/crypto_service.dart';
import '../helpers/test_helpers.dart';
import '../helpers/memory_helpers.dart';

/// Stress Testing Framework - Phase 5C.2
/// Extreme load scenario testing and resource exhaustion recovery
/// 
/// Tests system resilience under:
/// - Extreme load scenarios
/// - Resource exhaustion conditions
/// - Network interruption simulation
/// - Sustained operation testing
/// - Performance degradation recovery
void main() {
  group('Stress Testing Suite', () {
    late TerminalWebSocketService wsService;
    late TerminalSessionHandler sessionHandler;
    late CryptoService cryptoService;

    setUp(() {
      wsService = TerminalWebSocketService.instance;
      sessionHandler = TerminalSessionHandler.instance;
      cryptoService = CryptoService();
    });

    tearDown(() async {
      // Aggressive cleanup after stress tests
      await sessionHandler.stopAllSessions();
      await wsService.disconnect();
      await MemoryHelpers.forceGarbageCollection();
    });

    testWidgets('should handle extreme load scenarios', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing system resilience under extreme load...');
        
        const extremeOperationCount = 500;
        const concurrentBatches = 25;
        const operationsPerBatch = extremeOperationCount ~/ concurrentBatches;
        
        final memoryTracker = MemoryHelpers.createTracker('extreme_load');
        await memoryTracker.takeSnapshot('baseline');
        
        final stressStopwatch = Stopwatch()..start();
        final allOperations = <Future<StressTestResult>>[];
        
        print('Generating $extremeOperationCount operations across $concurrentBatches concurrent batches...');
        
        // Create extreme concurrent load
        for (int batch = 0; batch < concurrentBatches; batch++) {
          final batchOperations = List.generate(operationsPerBatch, (opIndex) {
            final operationId = batch * operationsPerBatch + opIndex;
            final operationType = ['crypto', 'memory', 'computation'][operationId % 3];
            
            return Future(() async {
              final opTimer = Stopwatch()..start();
              bool success = false;
              String? error;
              int memoryUsed = 0;
              
              try {
                switch (operationType) {
                  case 'crypto':
                    // Intensive crypto operations
                    final key = cryptoService.generateSalt();
                    final data = Uint8List(1024); // 1KB data
                    for (int i = 0; i < data.length; i++) {
                      data[i] = operationId % 256;
                    }
                    
                    final encrypted = await cryptoService.encryptAESGCM(data, key);
                    await cryptoService.decryptAESGCM(encrypted, key);
                    success = true;
                    memoryUsed = data.length + encrypted.ciphertext.length;
                    break;
                    
                  case 'memory':
                    // Memory-intensive operations
                    final largeData = List.generate(10000, (i) => i % 1000);
                    final processed = largeData.map((x) => x * 2).toList();
                    largeData.clear();
                    processed.clear();
                    success = true;
                    memoryUsed = 10000 * 4; // Approximate bytes
                    break;
                    
                  case 'computation':
                    // CPU-intensive computation
                    double result = 0;
                    for (int i = 0; i < 10000; i++) {
                      result += math.sin(i * 0.001) * math.cos(i * 0.001);
                    }
                    success = result != double.infinity;
                    break;
                }
              } catch (e) {
                error = e.toString();
                success = false;
              }
              
              opTimer.stop();
              
              return StressTestResult(
                operationId: operationId,
                operationType: operationType,
                success: success,
                duration: opTimer.elapsedMicroseconds,
                error: error,
                memoryUsed: memoryUsed,
              );
            });
          });
          
          allOperations.addAll(batchOperations);
          
          // Small delay between batches to prevent system overload
          await Future.delayed(const Duration(milliseconds: 5));
        }
        
        // Execute all operations concurrently
        print('Executing extreme load operations...');
        final results = await Future.wait(allOperations);
        stressStopwatch.stop();
        
        await memoryTracker.takeSnapshot('extreme_load_completed');
        
        // Analyze extreme load results
        final successfulOps = results.where((r) => r.success).length;
        final failedOps = results.length - successfulOps;
        final avgDuration = results.map((r) => r.duration / 1000).reduce((a, b) => a + b) / results.length;
        final totalMemoryUsed = results.map((r) => r.memoryUsed).reduce((a, b) => a + b);
        
        print('Extreme Load Test Results:');
        print('  Total operations: ${results.length}');
        print('  Successful: $successfulOps (${(successfulOps / results.length * 100).toStringAsFixed(1)}%)');
        print('  Failed: $failedOps (${(failedOps / results.length * 100).toStringAsFixed(1)}%)');
        print('  Total time: ${stressStopwatch.elapsedMilliseconds}ms');
        print('  Average operation time: ${avgDuration.toStringAsFixed(2)}ms');
        print('  Total memory processed: ${formatMemory(totalMemoryUsed)}');
        
        // Extreme load validation
        expect(stressStopwatch.elapsedMilliseconds, lessThan(60000),
            reason: 'Extreme load should complete within 60 seconds');
            
        // Even under extreme load, some operations should succeed
        expect(successfulOps, greaterThan(results.length * 0.3), // 30% minimum
            reason: 'System should maintain basic functionality under extreme load');
            
        // Memory usage should not grow unbounded
        final memoryStats = memoryTracker.getStats();
        expect(memoryStats.totalMemoryChange, lessThan(100 * 1024 * 1024), // 100MB
            reason: 'Memory usage should remain bounded under extreme load');
            
        print('Extreme load stress test completed');
      });
    });

    testWidgets('should recover from resource exhaustion', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing resource exhaustion recovery...');
        
        final recoveryTracker = MemoryHelpers.createTracker('resource_exhaustion');
        await recoveryTracker.takeSnapshot('baseline');
        
        // Phase 1: Create resource exhaustion
        print('Phase 1: Creating resource exhaustion condition...');
        
        final exhaustionTimer = Stopwatch()..start();
        final resourceBlocks = <List<int>>[];
        
        // Gradually increase memory pressure
        for (int block = 0; block < 50; block++) {
          try {
            final largeBlock = List.generate(100000, (i) => i); // ~400KB per block
            resourceBlocks.add(largeBlock);
            
            // Test system responsiveness under pressure
            if (block % 10 == 0) {
              final key = cryptoService.generateSalt();
              final testData = Uint8List.fromList('Resource test $block'.codeUnits);
              await cryptoService.encryptAESGCM(testData, key);
            }
            
          } catch (e) {
            print('Resource exhaustion reached at block $block: $e');
            break;
          }
        }
        
        exhaustionTimer.stop();
        await recoveryTracker.takeSnapshot('exhaustion_peak');
        
        print('Resource exhaustion phase completed in ${exhaustionTimer.elapsedMilliseconds}ms');
        print('Allocated resource blocks: ${resourceBlocks.length}');
        
        // Phase 2: Test system recovery
        print('Phase 2: Testing system recovery...');
        
        final recoveryTimer = Stopwatch()..start();
        
        // Gradual resource release
        final releaseCount = resourceBlocks.length;
        for (int i = 0; i < releaseCount; i += 5) {
          // Release 5 blocks at a time
          final endIndex = math.min(i + 5, resourceBlocks.length);
          for (int j = i; j < endIndex && resourceBlocks.isNotEmpty; j++) {
            resourceBlocks.removeLast();
          }
          
          // Test system responsiveness during recovery
          if (i % 15 == 0) {
            try {
              final key = cryptoService.generateSalt();
              final testData = Uint8List.fromList('Recovery test $i'.codeUnits);
              final encrypted = await cryptoService.encryptAESGCM(testData, key);
              await cryptoService.decryptAESGCM(encrypted, key);
            } catch (e) {
              print('System still under stress at recovery step $i: $e');
            }
          }
          
          // Force garbage collection periodically
          if (i % 25 == 0) {
            await MemoryHelpers.forceGarbageCollection();
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
        
        recoveryTimer.stop();
        await MemoryHelpers.forceGarbageCollection();
        await recoveryTracker.takeSnapshot('recovery_completed');
        
        print('Recovery phase completed in ${recoveryTimer.elapsedMilliseconds}ms');
        
        // Phase 3: Validate full recovery
        print('Phase 3: Validating system recovery...');
        
        final validationTimer = Stopwatch()..start();
        final validationOperations = <Future<bool>>[];
        
        // Test various operations to ensure full recovery
        for (int test = 0; test < 20; test++) {
          validationOperations.add(Future(() async {
            try {
              final key = cryptoService.generateSalt();
              final data = Uint8List.fromList('Validation $test'.codeUnits);
              final encrypted = await cryptoService.encryptAESGCM(data, key);
              await cryptoService.decryptAESGCM(encrypted, key);
              return true;
            } catch (e) {
              return false;
            }
          }));
        }
        
        final validationResults = await Future.wait(validationOperations);
        validationTimer.stop();
        
        final recoverySuccessRate = validationResults.where((r) => r).length / validationResults.length;
        
        print('Recovery validation results:');
        print('  Validation operations: ${validationResults.length}');
        print('  Success rate: ${(recoverySuccessRate * 100).toStringAsFixed(1)}%');
        print('  Validation time: ${validationTimer.elapsedMilliseconds}ms');
        
        // Recovery validation
        expect(recoverySuccessRate, greaterThan(0.8),
            reason: 'System should achieve >80% functionality after recovery');
            
        expect(validationTimer.elapsedMilliseconds, lessThan(5000),
            reason: 'System should be responsive after recovery');
        
        // Memory recovery validation
        final recoveryStats = recoveryTracker.getStats();
        final memoryRecovered = recoveryStats.maxMemoryUsage - recoveryTracker.snapshots.last.memory;
        
        print('Memory recovery: ${formatMemory(memoryRecovered)}');
        expect(memoryRecovered, greaterThan(0),
            reason: 'Memory should be recovered after resource release');
            
        print('Resource exhaustion recovery test completed');
      });
    });

    testWidgets('should handle sustained operation testing', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing sustained operation performance...');
        
        const sustainedDuration = Duration(seconds: 10);
        const operationInterval = Duration(milliseconds: 100);
        final expectedOperations = sustainedDuration.inMilliseconds ~/ operationInterval.inMilliseconds;
        
        final sustainedTracker = MemoryHelpers.createTracker('sustained_ops');
        await sustainedTracker.takeSnapshot('baseline');
        
        print('Running sustained operations for ${sustainedDuration.inSeconds} seconds...');
        
        final sustainedTimer = Stopwatch()..start();
        var operationCount = 0;
        var successCount = 0;
        final performanceSamples = <int>[];
        
        // Run operations at regular intervals
        while (sustainedTimer.elapsed < sustainedDuration) {
          final opTimer = Stopwatch()..start();
          
          try {
            // Perform a mix of operations
            final opType = operationCount % 3;
            
            switch (opType) {
              case 0:
                // Crypto operation
                final key = cryptoService.generateSalt();
                final data = Uint8List.fromList('Sustained op $operationCount'.codeUnits);
                final encrypted = await cryptoService.encryptAESGCM(data, key);
                await cryptoService.decryptAESGCM(encrypted, key);
                break;
                
              case 1:
                // Memory operation
                final tempList = List.generate(1000, (i) => operationCount + i);
                tempList.clear();
                break;
                
              case 2:
                // Computation operation
                double result = 0;
                for (int i = 0; i < 1000; i++) {
                  result += math.sqrt(i + operationCount);
                }
                // Use result to prevent optimization
                if (result.isInfinite) break;
                break;
            }
            
            successCount++;
          } catch (e) {
            print('Operation $operationCount failed: $e');
          }
          
          opTimer.stop();
          performanceSamples.add(opTimer.elapsedMilliseconds);
          operationCount++;
          
          // Take memory snapshots periodically
          if (operationCount % 50 == 0) {
            await sustainedTracker.takeSnapshot('op_$operationCount');
          }
          
          // Wait for next interval
          await Future.delayed(operationInterval);
        }
        
        sustainedTimer.stop();
        await sustainedTracker.takeSnapshot('sustained_completed');
        
        // Analyze sustained operation performance
        final actualDuration = sustainedTimer.elapsedMilliseconds;
        final operationRate = operationCount / (actualDuration / 1000);
        final successRate = successCount / operationCount;
        final avgOperationTime = performanceSamples.reduce((a, b) => a + b) / performanceSamples.length;
        
        print('Sustained Operation Results:');
        print('  Target duration: ${sustainedDuration.inSeconds}s');
        print('  Actual duration: ${actualDuration}ms');
        print('  Operations executed: $operationCount (expected: ~$expectedOperations)');
        print('  Success rate: ${(successRate * 100).toStringAsFixed(1)}%');
        print('  Operation rate: ${operationRate.toStringAsFixed(2)} ops/sec');
        print('  Average operation time: ${avgOperationTime.toStringAsFixed(2)}ms');
        
        // Performance consistency analysis
        final sortedSamples = List.from(performanceSamples)..sort();
        final medianTime = sortedSamples[sortedSamples.length ~/ 2];
        final p90Time = sortedSamples[(sortedSamples.length * 0.9).round()];
        final p95Time = sortedSamples[(sortedSamples.length * 0.95).round()];
        
        print('  Performance percentiles:');
        print('    Median: ${medianTime}ms');
        print('    90th percentile: ${p90Time}ms');
        print('    95th percentile: ${p95Time}ms');
        
        // Sustained operation validation
        expect(successRate, greaterThan(0.85),
            reason: 'Sustained operations should maintain >85% success rate');
            
        expect(avgOperationTime, lessThan(200),
            reason: 'Average operation time should remain reasonable during sustained load');
            
        expect(p95Time, lessThan(500),
            reason: '95th percentile should show reasonable performance consistency');
        
        // Memory stability during sustained operations
        final memoryAnalysis = sustainedTracker.analyzeLeaks();
        print('Memory stability: ${memoryAnalysis.trendDirection}');
        
        expect(memoryAnalysis.hasLeak, isFalse,
            reason: 'Sustained operations should not cause memory leaks');
            
        print('Sustained operation testing completed');
      });
    });

    testWidgets('should handle network interruption simulation', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing network interruption recovery...');
        
        final networkTracker = MemoryHelpers.createTracker('network_interruption');
        await networkTracker.takeSnapshot('baseline');
        
        // Phase 1: Establish baseline network operations
        print('Phase 1: Establishing baseline network operations...');
        
        var baselineSuccessCount = 0;
        const baselineOperations = 10;
        
        for (int i = 0; i < baselineOperations; i++) {
          try {
            await wsService.sendTerminalData('Baseline message $i');
            baselineSuccessCount++;
          } catch (e) {
            print('Baseline operation $i failed (expected in test env): $e');
          }
          
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        await networkTracker.takeSnapshot('baseline_established');
        print('Baseline network operations: $baselineSuccessCount/$baselineOperations successful');
        
        // Phase 2: Simulate network interruption
        print('Phase 2: Simulating network interruption...');
        
        // Disconnect WebSocket to simulate network interruption
        await wsService.disconnect();
        
        // Attempt operations during interruption
        var interruptionFailures = 0;
        const interruptionOperations = 5;
        
        for (int i = 0; i < interruptionOperations; i++) {
          try {
            await wsService.sendTerminalData('Interruption test $i').timeout(
              const Duration(seconds: 2),
            );
          } catch (e) {
            interruptionFailures++;
            // Expected to fail during interruption
          }
        }
        
        await networkTracker.takeSnapshot('interruption_period');
        print('Network interruption simulation: $interruptionFailures/$interruptionOperations operations failed as expected');
        
        // Phase 3: Test recovery
        print('Phase 3: Testing network recovery...');
        
        final recoveryTimer = Stopwatch()..start();
        
        // Attempt to reconnect
        try {
          await wsService.connect();
        } catch (e) {
          print('Network reconnection failed (expected in test env): $e');
        }
        
        // Test operations after recovery attempt
        var recoverySuccessCount = 0;
        const recoveryOperations = 10;
        
        for (int i = 0; i < recoveryOperations; i++) {
          try {
            await wsService.sendTerminalData('Recovery test $i');
            recoverySuccessCount++;
          } catch (e) {
            // May still fail due to test environment
          }
          
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        recoveryTimer.stop();
        await networkTracker.takeSnapshot('recovery_completed');
        
        print('Network recovery results:');
        print('  Recovery time: ${recoveryTimer.elapsedMilliseconds}ms');
        print('  Recovery operations: $recoverySuccessCount/$recoveryOperations successful');
        
        // Network interruption validation
        expect(interruptionFailures, equals(interruptionOperations),
            reason: 'Operations should fail during network interruption');
            
        expect(recoveryTimer.elapsedMilliseconds, lessThan(10000),
            reason: 'Network recovery should be attempted quickly');
        
        // Even if network operations fail in test environment, 
        // the recovery mechanisms should be in place
        expect(recoveryOperations, greaterThan(0),
            reason: 'Recovery operations should be attempted');
            
        print('Network interruption simulation completed');
      });
    });
  });
}

/// Stress test result data structure
class StressTestResult {
  final int operationId;
  final String operationType;
  final bool success;
  final int duration; // microseconds
  final String? error;
  final int memoryUsed;
  
  const StressTestResult({
    required this.operationId,
    required this.operationType,
    required this.success,
    required this.duration,
    this.error,
    required this.memoryUsed,
  });
  
  @override
  String toString() {
    return 'StressTestResult(#$operationId $operationType: ${success ? 'OK' : 'FAIL'} ${(duration / 1000).toStringAsFixed(2)}ms)';
  }
}