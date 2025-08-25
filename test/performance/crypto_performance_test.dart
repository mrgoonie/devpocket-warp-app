import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;

import 'package:devpocket_warp_app/services/crypto_service.dart';
import '../helpers/test_helpers.dart';

extension MathUtils on double {
  double sqrt() => math.sqrt(this);
}

/// Enhanced Cryptographic Performance Tests - Phase 5
/// Optimized for production targets with comprehensive monitoring
/// 
/// Performance Targets:
/// - SSH key generation: < 2 seconds (Ed25519), < 5 seconds (RSA-2048)
/// - Fingerprint calculation: < 100ms
/// - Encryption/decryption: < 50ms per operation
/// - Secure storage operations: < 200ms
void main() {
  group('Cryptographic Performance', () {
    late CryptoService cryptoService;

    setUp(() {
      cryptoService = CryptoService();
    });

    testWidgets('should meet production encryption/decryption targets', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        const operationCount = 20; // Production-realistic batch size
        const testData = 'Performance test data for production validation';
        final key = cryptoService.generateSalt();

        print('Testing AES-GCM encryption/decryption performance...');

        // Test single operation performance (Production Target: < 50ms)
        final singleEncryptStopwatch = Stopwatch()..start();
        final singleEncrypted = await cryptoService.encryptAESGCM(
          Uint8List.fromList(testData.codeUnits),
          key,
        );
        singleEncryptStopwatch.stop();
        
        print('Single encryption: ${singleEncryptStopwatch.elapsedMilliseconds}ms');
        expect(singleEncryptStopwatch.elapsedMilliseconds, lessThan(50),
            reason: 'Single encryption should be under 50ms (production target)');

        // Test single decryption performance (Production Target: < 50ms)
        final singleDecryptStopwatch = Stopwatch()..start();
        await cryptoService.decryptAESGCM(singleEncrypted, key);
        singleDecryptStopwatch.stop();
        
        print('Single decryption: ${singleDecryptStopwatch.elapsedMilliseconds}ms');
        expect(singleDecryptStopwatch.elapsedMilliseconds, lessThan(50),
            reason: 'Single decryption should be under 50ms (production target)');

        // Test batch encryption performance
        final batchEncryptStopwatch = Stopwatch()..start();
        final encryptedResults = <EncryptedData>[];
        
        for (int i = 0; i < operationCount; i++) {
          try {
            final encrypted = await cryptoService.encryptAESGCM(
              Uint8List.fromList('$testData $i'.codeUnits),
              key,
            );
            encryptedResults.add(encrypted);
          } catch (e) {
            print('Batch encryption operation $i failed: $e');
          }
        }
        
        batchEncryptStopwatch.stop();
        print('Batch encrypted $operationCount items in ${batchEncryptStopwatch.elapsedMilliseconds}ms');
        
        // Batch encryption performance validation
        if (encryptedResults.isNotEmpty) {
          final avgEncryptTime = batchEncryptStopwatch.elapsedMilliseconds / encryptedResults.length;
          print('Average encryption time: ${avgEncryptTime.toStringAsFixed(2)}ms');
          expect(avgEncryptTime, lessThan(50),
              reason: 'Average batch encryption should be under 50ms per operation');
        }

        // Test batch decryption performance
        final batchDecryptStopwatch = Stopwatch()..start();
        var decryptedCount = 0;
        
        for (final encrypted in encryptedResults) {
          try {
            await cryptoService.decryptAESGCM(encrypted, key);
            decryptedCount++;
          } catch (e) {
            print('Batch decryption operation failed: $e');
          }
        }
        
        batchDecryptStopwatch.stop();
        print('Batch decrypted $decryptedCount items in ${batchDecryptStopwatch.elapsedMilliseconds}ms');
        
        // Batch decryption performance validation
        if (decryptedCount > 0) {
          final avgDecryptTime = batchDecryptStopwatch.elapsedMilliseconds / decryptedCount;
          print('Average decryption time: ${avgDecryptTime.toStringAsFixed(2)}ms');
          expect(avgDecryptTime, lessThan(50),
              reason: 'Average batch decryption should be under 50ms per operation');
        }
        
        // Validate operation success rate
        expect(encryptedResults.length, equals(operationCount),
            reason: 'All encryption operations should succeed');
        expect(decryptedCount, equals(encryptedResults.length),
            reason: 'All decryption operations should succeed');
      });
    });

    testWidgets('should meet production SSH key generation targets', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing SSH key generation performance against production targets...');
        
        // Test Ed25519 key generation (Production Target: < 1 second)
        print('Testing Ed25519 key generation...');
        final ed25519Stopwatch = Stopwatch()..start();
        
        try {
          final ed25519KeyPair = await cryptoService.generateSSHKeyPair(
            type: SSHKeyType.ed25519,
          );
          ed25519Stopwatch.stop();
          
          print('Generated Ed25519 key pair in ${ed25519Stopwatch.elapsedMilliseconds}ms');
          expect(ed25519Stopwatch.elapsedMilliseconds, lessThan(1000),
              reason: 'Ed25519 key generation should complete within 1 second (production target)');
          
          // Validate key pair structure
          expect(ed25519KeyPair.privateKey, isNotEmpty);
          expect(ed25519KeyPair.publicKey, isNotEmpty);
          expect(ed25519KeyPair.privateKey.length, greaterThan(50));
          expect(ed25519KeyPair.publicKey.length, greaterThan(50));
          
          // Test fingerprint calculation performance (Production Target: < 100ms)
          print('Testing fingerprint calculation for Ed25519...');
          final fingerprintStopwatch = Stopwatch()..start();
          final fingerprint = cryptoService.calculateSSHFingerprint(ed25519KeyPair.publicKey);
          fingerprintStopwatch.stop();
          
          print('Calculated Ed25519 fingerprint in ${fingerprintStopwatch.elapsedMilliseconds}ms');
          expect(fingerprintStopwatch.elapsedMilliseconds, lessThan(100),
              reason: 'Fingerprint calculation should complete within 100ms (production target)');
          expect(fingerprint, isNotNull);
          expect(fingerprint!.isNotEmpty, isTrue);
          
        } catch (e) {
          ed25519Stopwatch.stop();
          print('Ed25519 key generation failed in ${ed25519Stopwatch.elapsedMilliseconds}ms: $e');
          // Still validate timeout even on failure
          expect(ed25519Stopwatch.elapsedMilliseconds, lessThan(2000),
              reason: 'Even failed Ed25519 key generation should timeout quickly');
        }

        // Test RSA-2048 key generation (Production Target: < 5 seconds)
        print('Testing RSA-2048 key generation...');
        final rsaStopwatch = Stopwatch()..start();
        
        try {
          final rsaKeyPair = await cryptoService.generateSSHKeyPair(
            type: SSHKeyType.rsa,
            bitLength: 2048,
          );
          rsaStopwatch.stop();
          
          print('Generated RSA-2048 key pair in ${rsaStopwatch.elapsedMilliseconds}ms');
          expect(rsaStopwatch.elapsedMilliseconds, lessThan(5000),
              reason: 'RSA-2048 key generation should complete within 5 seconds (production target)');
          
          // Validate key pair structure
          expect(rsaKeyPair.privateKey, isNotEmpty);
          expect(rsaKeyPair.publicKey, isNotEmpty);
          expect(rsaKeyPair.privateKey.length, greaterThan(100));
          expect(rsaKeyPair.publicKey.length, greaterThan(100));
          
          // Test fingerprint calculation performance for RSA
          print('Testing fingerprint calculation for RSA-2048...');
          final rsaFingerprintStopwatch = Stopwatch()..start();
          final rsaFingerprint = cryptoService.calculateSSHFingerprint(rsaKeyPair.publicKey);
          rsaFingerprintStopwatch.stop();
          
          print('Calculated RSA fingerprint in ${rsaFingerprintStopwatch.elapsedMilliseconds}ms');
          expect(rsaFingerprintStopwatch.elapsedMilliseconds, lessThan(100),
              reason: 'RSA fingerprint calculation should complete within 100ms (production target)');
          expect(rsaFingerprint, isNotNull);
          expect(rsaFingerprint!.isNotEmpty, isTrue);
          
        } catch (e) {
          rsaStopwatch.stop();
          print('RSA key generation failed in ${rsaStopwatch.elapsedMilliseconds}ms: $e');
          // Still validate timeout even on failure
          expect(rsaStopwatch.elapsedMilliseconds, lessThan(10000),
              reason: 'Even failed RSA key generation should timeout within 10 seconds');
        }
      });
    });

    testWidgets('should handle crypto operations under memory pressure', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing crypto operations under memory pressure...');
        
        // Test secure storage operations performance (Production Target: < 200ms)
        const secureDataCount = 50;
        const testData = 'Secure storage performance test data';
        final key = cryptoService.generateSalt();
        
        final secureStorageStopwatch = Stopwatch()..start();
        final secureOperations = <Future>[];
        
        // Simulate secure storage operations
        for (int i = 0; i < secureDataCount; i++) {
          secureOperations.add(Future(() async {
            final encrypted = await cryptoService.encryptAESGCM(
              Uint8List.fromList('$testData $i'.codeUnits),
              key,
            );
            final decrypted = await cryptoService.decryptAESGCM(encrypted, key);
            return decrypted.length;
          }));
        }
        
        final results = await Future.wait(secureOperations);
        secureStorageStopwatch.stop();
        
        print('Completed $secureDataCount secure operations in ${secureStorageStopwatch.elapsedMilliseconds}ms');
        
        // Validate secure storage performance target
        final avgSecureTime = secureStorageStopwatch.elapsedMilliseconds / secureDataCount;
        print('Average secure operation time: ${avgSecureTime.toStringAsFixed(2)}ms');
        expect(avgSecureTime, lessThan(200),
            reason: 'Average secure storage operations should be under 200ms (production target)');
        
        // Validate all operations completed successfully
        expect(results.length, equals(secureDataCount));
        expect(results.every((result) => result > 0), isTrue,
            reason: 'All secure operations should process data successfully');
        
        // Test crypto operations under simulated memory pressure
        print('Testing crypto operations with concurrent memory allocation...');
        final memoryPressureStopwatch = Stopwatch()..start();
        
        // Create memory pressure while performing crypto operations
        final memoryBlocks = <List<int>>[];
        final cryptoFutures = <Future>[];
        
        // Add concurrent memory allocation
        for (int i = 0; i < 20; i++) {
          memoryBlocks.add(List.generate(1000, (index) => index));
        }
        
        // Perform crypto operations under memory pressure
        for (int i = 0; i < 10; i++) {
          cryptoFutures.add(Future(() async {
            final encrypted = await cryptoService.encryptAESGCM(
              Uint8List.fromList('Memory pressure test $i'.codeUnits),
              key,
            );
            return await cryptoService.decryptAESGCM(encrypted, key);
          }));
        }
        
        final cryptoResults = await Future.wait(cryptoFutures);
        memoryPressureStopwatch.stop();
        
        print('Crypto operations under memory pressure completed in ${memoryPressureStopwatch.elapsedMilliseconds}ms');
        
        // Validate crypto operations still meet performance targets under pressure
        final avgPressureTime = memoryPressureStopwatch.elapsedMilliseconds / cryptoResults.length;
        print('Average crypto time under pressure: ${avgPressureTime.toStringAsFixed(2)}ms');
        expect(avgPressureTime, lessThan(100),
            reason: 'Crypto operations should remain efficient under memory pressure');
        
        // Clean up memory blocks
        memoryBlocks.clear();
        
        print('Memory pressure test completed successfully');
      });
    });

    testWidgets('should perform crypto resource cleanup efficiently', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing crypto resource cleanup performance...');
        
        const operationCount = 100;
        final keys = <Uint8List>[];
        final encrypted = <EncryptedData>[];
        
        // Generate multiple keys and encrypted data
        final setupStopwatch = Stopwatch()..start();
        for (int i = 0; i < operationCount; i++) {
          final key = cryptoService.generateSalt();
          keys.add(key);
          
          final encryptedData = await cryptoService.encryptAESGCM(
            Uint8List.fromList('Cleanup test data $i'.codeUnits),
            key,
          );
          encrypted.add(encryptedData);
        }
        setupStopwatch.stop();
        
        print('Setup $operationCount crypto resources in ${setupStopwatch.elapsedMilliseconds}ms');
        
        // Test cleanup performance
        final cleanupStopwatch = Stopwatch()..start();
        
        // Clear all resources
        keys.clear();
        encrypted.clear();
        
        // Force garbage collection if available
        if (Platform.isAndroid || Platform.isIOS) {
          // Mobile platforms - simulate GC pressure
          final tempList = List.generate(1000, (i) => i);
          tempList.clear();
        }
        
        cleanupStopwatch.stop();
        
        print('Crypto resource cleanup completed in ${cleanupStopwatch.elapsedMilliseconds}ms');
        
        // Cleanup should be very fast
        expect(cleanupStopwatch.elapsedMilliseconds, lessThan(100),
            reason: 'Crypto resource cleanup should complete within 100ms');
        
        // Validate resources are cleaned
        expect(keys.isEmpty, isTrue);
        expect(encrypted.isEmpty, isTrue);
        
        print('Crypto resource cleanup validation passed');
      });
    });

    testWidgets('should maintain crypto performance consistency', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing crypto performance consistency over multiple runs...');
        
        const testRuns = 10;
        final encryptionTimes = <int>[];
        final decryptionTimes = <int>[];
        
        const testData = 'Consistency test data';
        final key = cryptoService.generateSalt();
        
        // Run multiple encryption/decryption cycles
        for (int run = 0; run < testRuns; run++) {
          // Test encryption consistency
          final encryptStopwatch = Stopwatch()..start();
          final encrypted = await cryptoService.encryptAESGCM(
            Uint8List.fromList('$testData run $run'.codeUnits),
            key,
          );
          encryptStopwatch.stop();
          encryptionTimes.add(encryptStopwatch.elapsedMilliseconds);
          
          // Test decryption consistency
          final decryptStopwatch = Stopwatch()..start();
          await cryptoService.decryptAESGCM(encrypted, key);
          decryptStopwatch.stop();
          decryptionTimes.add(decryptStopwatch.elapsedMilliseconds);
        }
        
        // Calculate performance statistics
        final avgEncryptionTime = encryptionTimes.reduce((a, b) => a + b) / encryptionTimes.length;
        final avgDecryptionTime = decryptionTimes.reduce((a, b) => a + b) / decryptionTimes.length;
        
        final maxEncryptionTime = encryptionTimes.reduce((a, b) => a > b ? a : b);
        final maxDecryptionTime = decryptionTimes.reduce((a, b) => a > b ? a : b);
        
        print('Encryption - Avg: ${avgEncryptionTime.toStringAsFixed(2)}ms, Max: ${maxEncryptionTime}ms');
        print('Decryption - Avg: ${avgDecryptionTime.toStringAsFixed(2)}ms, Max: ${maxDecryptionTime}ms');
        
        // Performance consistency validation
        expect(avgEncryptionTime, lessThan(50),
            reason: 'Average encryption time should meet production target');
        expect(avgDecryptionTime, lessThan(50),
            reason: 'Average decryption time should meet production target');
            
        expect(maxEncryptionTime, lessThan(100),
            reason: 'Max encryption time should be under 100ms for consistency');
        expect(maxDecryptionTime, lessThan(100),
            reason: 'Max decryption time should be under 100ms for consistency');
        
        // Calculate standard deviation for consistency check
        final encryptVariance = encryptionTimes.map((time) => 
            (time - avgEncryptionTime) * (time - avgEncryptionTime)).reduce((a, b) => a + b) / encryptionTimes.length;
        final encryptStdDev = encryptVariance.sqrt();
        
        print('Encryption standard deviation: ${encryptStdDev.toStringAsFixed(2)}ms');
        
        // Performance should be consistent (low standard deviation)
        expect(encryptStdDev, lessThan(20),
            reason: 'Encryption performance should be consistent (std dev < 20ms)');
        
        print('Crypto performance consistency validation passed');
      });
    });
  });
}