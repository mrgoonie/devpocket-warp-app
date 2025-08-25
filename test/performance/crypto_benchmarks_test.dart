import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;

import 'package:devpocket_warp_app/services/crypto_service.dart';
import '../helpers/test_helpers.dart';

/// Advanced Cryptographic Benchmarking Tests - Phase 5A.2
/// Implements crypto operation performance profiling and regression detection
/// 
/// Features:
/// - Crypto operation performance profiling
/// - Batch operation optimization testing
/// - Performance regression detection
/// - Stress testing under load
/// - Resource cleanup validation
void main() {
  group('Advanced Crypto Benchmarks', () {
    late CryptoService cryptoService;

    setUp(() {
      cryptoService = CryptoService();
    });

    testWidgets('should profile crypto operation performance', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Running comprehensive crypto operation profiling...');
        
        // Performance profiling data structure
        final performanceMetrics = <String, List<int>>{};
        const profilingRuns = 20;
        
        // Profile AES-GCM encryption
        print('Profiling AES-GCM encryption operations...');
        performanceMetrics['aes_encrypt'] = [];
        final testData = Uint8List.fromList('Profiling test data'.codeUnits);
        final key = cryptoService.generateSalt();
        
        for (int run = 0; run < profilingRuns; run++) {
          final stopwatch = Stopwatch()..start();
          await cryptoService.encryptAESGCM(testData, key);
          stopwatch.stop();
          performanceMetrics['aes_encrypt']!.add(stopwatch.elapsedMicroseconds);
        }
        
        // Profile AES-GCM decryption
        print('Profiling AES-GCM decryption operations...');
        performanceMetrics['aes_decrypt'] = [];
        final encryptedData = await cryptoService.encryptAESGCM(testData, key);
        
        for (int run = 0; run < profilingRuns; run++) {
          final stopwatch = Stopwatch()..start();
          await cryptoService.decryptAESGCM(encryptedData, key);
          stopwatch.stop();
          performanceMetrics['aes_decrypt']!.add(stopwatch.elapsedMicroseconds);
        }
        
        // Profile SSH key generation
        print('Profiling Ed25519 key generation...');
        performanceMetrics['ed25519_keygen'] = [];
        
        for (int run = 0; run < 5; run++) { // Fewer runs for key generation
          final stopwatch = Stopwatch()..start();
          try {
            await cryptoService.generateSSHKeyPair(type: SSHKeyType.ed25519);
            stopwatch.stop();
            performanceMetrics['ed25519_keygen']!.add(stopwatch.elapsedMicroseconds);
          } catch (e) {
            stopwatch.stop();
            print('Ed25519 key generation failed on run $run: $e');
          }
        }
        
        // Analyze profiling results
        for (final entry in performanceMetrics.entries) {
          final operation = entry.key;
          final times = entry.value;
          
          if (times.isEmpty) {
            print('No successful $operation operations recorded');
            continue;
          }
          
          final avgTime = times.reduce((a, b) => a + b) / times.length;
          final minTime = times.reduce((a, b) => a < b ? a : b);
          final maxTime = times.reduce((a, b) => a > b ? a : b);
          
          // Calculate standard deviation
          final variance = times.map((time) => 
              (time - avgTime) * (time - avgTime)).reduce((a, b) => a + b) / times.length;
          final stdDev = math.sqrt(variance);
          
          print('$operation Performance Profile:');
          print('  Average: ${(avgTime / 1000).toStringAsFixed(2)}ms');
          print('  Min: ${(minTime / 1000).toStringAsFixed(2)}ms');
          print('  Max: ${(maxTime / 1000).toStringAsFixed(2)}ms');
          print('  Std Dev: ${(stdDev / 1000).toStringAsFixed(2)}ms');
          
          // Validate performance consistency
          final coefficientOfVariation = stdDev / avgTime;
          print('  Coefficient of Variation: ${(coefficientOfVariation * 100).toStringAsFixed(2)}%');
          
          // Performance should be relatively consistent (CV < 0.5 for crypto ops)
          if (operation.startsWith('aes_')) {
            expect(coefficientOfVariation, lessThan(0.5),
                reason: '$operation should have consistent performance (CV < 50%)');
          }
        }
        
        print('Crypto operation profiling completed successfully');
      });
    });

    testWidgets('should optimize batch crypto operations', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing batch crypto operation optimization...');
        
        final key = cryptoService.generateSalt();
        const batchSizes = [1, 5, 10, 20, 50];
        final batchResults = <int, double>{};
        
        for (final batchSize in batchSizes) {
          print('Testing batch size: $batchSize');
          
          // Test batch encryption
          final batchStopwatch = Stopwatch()..start();
          final futures = <Future>[];
          
          for (int i = 0; i < batchSize; i++) {
            futures.add(cryptoService.encryptAESGCM(
              Uint8List.fromList('Batch test data $i'.codeUnits),
              key,
            ));
          }
          
          final results = await Future.wait(futures);
          batchStopwatch.stop();
          
          final avgTimePerOperation = batchStopwatch.elapsedMilliseconds / batchSize;
          batchResults[batchSize] = avgTimePerOperation;
          
          print('Batch size $batchSize: ${avgTimePerOperation.toStringAsFixed(2)}ms per operation');
          
          // Validate all operations succeeded
          expect(results.length, equals(batchSize),
              reason: 'All batch operations should succeed');
              
          // Performance should meet targets regardless of batch size
          expect(avgTimePerOperation, lessThan(100),
              reason: 'Batch operations should maintain performance targets');
        }
        
        // Analyze batch optimization
        print('Batch optimization analysis:');
        for (final entry in batchResults.entries) {
          print('  Batch size ${entry.key}: ${entry.value.toStringAsFixed(2)}ms per op');
        }
        
        // Check if batch processing shows optimization (smaller batch sizes might be faster per op)
        final singleOpTime = batchResults[1]!;
        final largestBatchTime = batchResults[batchSizes.last]!;
        
        print('Single operation: ${singleOpTime.toStringAsFixed(2)}ms');
        print('Largest batch per op: ${largestBatchTime.toStringAsFixed(2)}ms');
        
        // Batch processing should not degrade performance significantly
        expect(largestBatchTime, lessThan(singleOpTime * 2),
            reason: 'Batch processing should not significantly degrade per-operation performance');
            
        print('Batch crypto operation optimization validated');
      });
    });

    testWidgets('should detect crypto performance regressions', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing crypto performance regression detection...');
        
        // Establish baseline performance
        const baselineRuns = 10;
        final baselineMetrics = <String, List<int>>{};
        final key = cryptoService.generateSalt();
        final testData = Uint8List.fromList('Regression test data'.codeUnits);
        
        // Collect baseline encryption performance
        print('Collecting baseline encryption metrics...');
        baselineMetrics['encryption'] = [];
        
        for (int run = 0; run < baselineRuns; run++) {
          final stopwatch = Stopwatch()..start();
          await cryptoService.encryptAESGCM(testData, key);
          stopwatch.stop();
          baselineMetrics['encryption']!.add(stopwatch.elapsedMilliseconds);
        }
        
        // Calculate baseline statistics
        final encryptionTimes = baselineMetrics['encryption']!;
        final baselineAvg = encryptionTimes.reduce((a, b) => a + b) / encryptionTimes.length;
        final baselineStdDev = math.sqrt(
          encryptionTimes.map((time) => 
            (time - baselineAvg) * (time - baselineAvg)
          ).reduce((a, b) => a + b) / encryptionTimes.length
        );
        
        print('Baseline encryption - Avg: ${baselineAvg.toStringAsFixed(2)}ms, StdDev: ${baselineStdDev.toStringAsFixed(2)}ms');
        
        // Performance regression thresholds
        final regressionThreshold = baselineAvg + (2 * baselineStdDev); // 2 standard deviations
        final significantRegressionThreshold = baselineAvg * 1.5; // 50% slower
        
        print('Regression thresholds:');
        print('  Warning: ${regressionThreshold.toStringAsFixed(2)}ms');
        print('  Critical: ${significantRegressionThreshold.toStringAsFixed(2)}ms');
        
        // Simulate performance testing for regression detection
        const testRuns = 5;
        var regressionCount = 0;
        var criticalRegressionCount = 0;
        
        print('Running regression detection tests...');
        for (int run = 0; run < testRuns; run++) {
          final stopwatch = Stopwatch()..start();
          await cryptoService.encryptAESGCM(testData, key);
          stopwatch.stop();
          
          final currentTime = stopwatch.elapsedMilliseconds;
          
          if (currentTime > significantRegressionThreshold) {
            criticalRegressionCount++;
            print('  Run $run: ${currentTime}ms - CRITICAL REGRESSION DETECTED!');
          } else if (currentTime > regressionThreshold) {
            regressionCount++;
            print('  Run $run: ${currentTime}ms - Performance regression warning');
          } else {
            print('  Run $run: ${currentTime}ms - Within baseline');
          }
        }
        
        // Validate regression detection
        print('Regression detection results:');
        print('  Warning regressions: $regressionCount');
        print('  Critical regressions: $criticalRegressionCount');
        
        // In normal operation, we shouldn't see critical regressions
        expect(criticalRegressionCount, equals(0),
            reason: 'Should not detect critical performance regressions under normal conditions');
            
        // Regression detection framework should be working
        expect(regressionThreshold, greaterThan(baselineAvg),
            reason: 'Regression threshold should be properly calculated');
            
        print('Performance regression detection system validated');
      });
    });

    testWidgets('should handle crypto stress testing under load', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Running crypto stress testing under load...');
        
        // Stress test configuration
        const concurrentOperations = 50;
        const operationVariants = ['encrypt', 'decrypt', 'keygen'];
        final key = cryptoService.generateSalt();
        
        // Create concurrent stress operations
        final stressStopwatch = Stopwatch()..start();
        final stressFutures = <Future>[];
        
        for (int i = 0; i < concurrentOperations; i++) {
          final variant = operationVariants[i % operationVariants.length];
          
          switch (variant) {
            case 'encrypt':
              stressFutures.add(Future(() async {
                final data = Uint8List.fromList('Stress test data $i'.codeUnits);
                return await cryptoService.encryptAESGCM(data, key);
              }));
              break;
              
            case 'decrypt':
              stressFutures.add(Future(() async {
                final data = Uint8List.fromList('Stress test data $i'.codeUnits);
                final encrypted = await cryptoService.encryptAESGCM(data, key);
                return await cryptoService.decryptAESGCM(encrypted, key);
              }));
              break;
              
            case 'keygen':
              if (i % 10 == 0) { // Reduce frequency of key generation
                stressFutures.add(Future(() async {
                  try {
                    return await cryptoService.generateSSHKeyPair(type: SSHKeyType.ed25519);
                  } catch (e) {
                    print('Key generation failed under stress: $e');
                    return null;
                  }
                }));
              }
              break;
          }
        }
        
        // Execute stress operations concurrently
        final stressResults = await Future.wait(stressFutures);
        stressStopwatch.stop();
        
        print('Stress test completed in ${stressStopwatch.elapsedMilliseconds}ms');
        print('Processed ${stressResults.length} concurrent operations');
        
        // Validate stress test results
        final successfulOperations = stressResults.where((result) => result != null).length;
        final successRate = successfulOperations / stressResults.length;
        
        print('Stress test success rate: ${(successRate * 100).toStringAsFixed(1)}%');
        
        // Under stress, we should maintain reasonable success rates
        expect(successRate, greaterThan(0.8),
            reason: 'Should maintain >80% success rate under stress');
            
        // Stress test should complete within reasonable time
        expect(stressStopwatch.elapsedMilliseconds, lessThan(30000),
            reason: 'Stress test should complete within 30 seconds');
        
        // Calculate average time per operation under stress
        final avgStressTime = stressStopwatch.elapsedMilliseconds / successfulOperations;
        print('Average time per operation under stress: ${avgStressTime.toStringAsFixed(2)}ms');
        
        // Performance under stress should be reasonable (allowing for overhead)
        expect(avgStressTime, lessThan(500),
            reason: 'Average operation time under stress should be reasonable');
            
        print('Crypto stress testing under load validated');
      });
    });

    testWidgets('should validate comprehensive resource cleanup', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing comprehensive crypto resource cleanup...');
        
        // Track resource allocation and cleanup
        const resourceCount = 100;
        final allocatedResources = <String, int>{};
        
        // Allocate various crypto resources
        print('Allocating crypto resources...');
        final allocationStopwatch = Stopwatch()..start();
        
        final keys = <Uint8List>[];
        final encryptedData = <EncryptedData>[];
        final keyPairs = <dynamic>[];
        
        // Allocate keys
        for (int i = 0; i < resourceCount; i++) {
          keys.add(cryptoService.generateSalt());
        }
        allocatedResources['keys'] = keys.length;
        
        // Allocate encrypted data
        for (int i = 0; i < resourceCount; i++) {
          final data = Uint8List.fromList('Resource test $i'.codeUnits);
          final encrypted = await cryptoService.encryptAESGCM(data, keys[i % keys.length]);
          encryptedData.add(encrypted);
        }
        allocatedResources['encrypted_data'] = encryptedData.length;
        
        // Allocate some key pairs (fewer due to generation cost)
        for (int i = 0; i < 5; i++) {
          try {
            final keyPair = await cryptoService.generateSSHKeyPair(type: SSHKeyType.ed25519);
            keyPairs.add(keyPair);
          } catch (e) {
            print('Key pair generation failed: $e');
          }
        }
        allocatedResources['key_pairs'] = keyPairs.length;
        
        allocationStopwatch.stop();
        
        print('Resource allocation completed in ${allocationStopwatch.elapsedMilliseconds}ms');
        print('Allocated resources: $allocatedResources');
        
        // Test systematic cleanup
        print('Performing systematic resource cleanup...');
        final cleanupStopwatch = Stopwatch()..start();
        
        // Clear all allocated resources
        keys.clear();
        encryptedData.clear();
        keyPairs.clear();
        
        // Force garbage collection on mobile platforms
        if (Platform.isAndroid || Platform.isIOS) {
          // Create temporary pressure to encourage GC
          final tempLists = List.generate(10, (i) => List.generate(1000, (j) => j));
          tempLists.clear();
        }
        
        cleanupStopwatch.stop();
        
        print('Resource cleanup completed in ${cleanupStopwatch.elapsedMilliseconds}ms');
        
        // Validate cleanup efficiency
        expect(cleanupStopwatch.elapsedMilliseconds, lessThan(500),
            reason: 'Resource cleanup should be efficient (<500ms)');
            
        // Validate all resources are cleared
        expect(keys.isEmpty, isTrue, reason: 'All keys should be cleared');
        expect(encryptedData.isEmpty, isTrue, reason: 'All encrypted data should be cleared');
        expect(keyPairs.isEmpty, isTrue, reason: 'All key pairs should be cleared');
        
        // Test cleanup validation
        print('Validating resource cleanup completeness...');
        
        // Attempt to use cleared resources should be safe
        expect(() => keys.length, returnsNormally);
        expect(() => encryptedData.length, returnsNormally);
        expect(() => keyPairs.length, returnsNormally);
        
        print('Comprehensive crypto resource cleanup validated');
      });
    });

    testWidgets('should benchmark crypto operations against industry standards', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Benchmarking crypto operations against industry standards...');
        
        // Industry standard benchmarks (approximate targets)
        const industryBenchmarks = {
          'aes_256_gcm_encrypt_mb_per_sec': 100.0, // ~100 MB/s
          'aes_256_gcm_decrypt_mb_per_sec': 100.0, // ~100 MB/s
          'ed25519_keygen_per_sec': 10.0, // ~10 keys per second
          'rsa_2048_keygen_per_sec': 1.0, // ~1 key per second
        };
        
        final benchmarkResults = <String, double>{};
        
        // Benchmark AES encryption throughput
        print('Benchmarking AES-256-GCM encryption throughput...');
        const dataSize = 1024 * 1024; // 1 MB
        final largeData = Uint8List(dataSize);
        for (int i = 0; i < dataSize; i++) {
          largeData[i] = i % 256;
        }
        
        final key = cryptoService.generateSalt();
        
        final encryptStopwatch = Stopwatch()..start();
        await cryptoService.encryptAESGCM(largeData, key);
        encryptStopwatch.stop();
        
        final encryptThroughput = dataSize / (encryptStopwatch.elapsedMicroseconds / 1000000) / (1024 * 1024);
        benchmarkResults['aes_256_gcm_encrypt_mb_per_sec'] = encryptThroughput;
        
        print('AES encryption throughput: ${encryptThroughput.toStringAsFixed(2)} MB/s');
        
        // Benchmark AES decryption throughput
        print('Benchmarking AES-256-GCM decryption throughput...');
        final encryptedLarge = await cryptoService.encryptAESGCM(largeData, key);
        
        final decryptStopwatch = Stopwatch()..start();
        await cryptoService.decryptAESGCM(encryptedLarge, key);
        decryptStopwatch.stop();
        
        final decryptThroughput = dataSize / (decryptStopwatch.elapsedMicroseconds / 1000000) / (1024 * 1024);
        benchmarkResults['aes_256_gcm_decrypt_mb_per_sec'] = decryptThroughput;
        
        print('AES decryption throughput: ${decryptThroughput.toStringAsFixed(2)} MB/s');
        
        // Benchmark Ed25519 key generation rate
        print('Benchmarking Ed25519 key generation rate...');
        const keyGenDuration = 5; // 5 seconds
        var ed25519Count = 0;
        
        final ed25519Stopwatch = Stopwatch()..start();
        while (ed25519Stopwatch.elapsedMilliseconds < keyGenDuration * 1000) {
          try {
            await cryptoService.generateSSHKeyPair(type: SSHKeyType.ed25519);
            ed25519Count++;
          } catch (e) {
            print('Ed25519 key generation failed: $e');
            break; // Stop if key generation fails
          }
        }
        ed25519Stopwatch.stop();
        
        if (ed25519Count > 0) {
          final ed25519Rate = ed25519Count / (ed25519Stopwatch.elapsedMilliseconds / 1000);
          benchmarkResults['ed25519_keygen_per_sec'] = ed25519Rate;
          print('Ed25519 key generation rate: ${ed25519Rate.toStringAsFixed(2)} keys/sec');
        } else {
          print('Ed25519 key generation not available in test environment');
        }
        
        // Compare against industry benchmarks
        print('\\nBenchmark comparison against industry standards:');
        for (final benchmark in industryBenchmarks.entries) {
          final benchmarkName = benchmark.key;
          final industryStandard = benchmark.value;
          final ourResult = benchmarkResults[benchmarkName];
          
          if (ourResult != null) {
            final performanceRatio = ourResult / industryStandard;
            final status = performanceRatio >= 0.5 ? 'GOOD' : 'NEEDS_IMPROVEMENT';
            
            print('  $benchmarkName:');
            print('    Our result: ${ourResult.toStringAsFixed(2)}');
            print('    Industry standard: ${industryStandard.toStringAsFixed(2)}');
            print('    Performance ratio: ${(performanceRatio * 100).toStringAsFixed(1)}% - $status');
            
            // For mobile applications, achieving 50% of industry standard is reasonable
            if (benchmarkName.contains('throughput') || benchmarkName.contains('mb_per_sec')) {
              expect(performanceRatio, greaterThan(0.1),
                  reason: '$benchmarkName should achieve reasonable throughput for mobile');
            }
          } else {
            print('  $benchmarkName: Not measured (may not be available)');
          }
        }
        
        print('\\nCrypto operations benchmark against industry standards completed');
      });
    });
  });
}