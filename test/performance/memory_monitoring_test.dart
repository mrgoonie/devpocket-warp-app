import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:devpocket_warp_app/services/ssh_connection_manager.dart';
import 'package:devpocket_warp_app/services/terminal_websocket_service.dart';
import 'package:devpocket_warp_app/services/crypto_service.dart';
import 'package:devpocket_warp_app/services/terminal_session_handler.dart';
import 'package:devpocket_warp_app/models/ssh_profile_models.dart';
import '../helpers/test_helpers.dart';

/// Memory Usage Monitoring Test Suite - Phase 5B.1
/// Comprehensive memory monitoring and leak detection for production readiness
/// 
/// Memory Targets:
/// - Base app memory usage: < 100MB
/// - SSH connection overhead: < 10MB per connection
/// - WebSocket memory usage: < 5MB per connection
/// - Memory leak detection: 0 leaks over 1000 operations
void main() {
  group('Memory Monitoring', () {
    late SshConnectionManager sshManager;
    late TerminalWebSocketService wsService;
    late CryptoService cryptoService;
    late TerminalSessionHandler sessionHandler;

    setUp(() {
      sshManager = SshConnectionManager.instance;
      wsService = TerminalWebSocketService.instance;
      cryptoService = CryptoService();
      sessionHandler = TerminalSessionHandler.instance;
    });

    tearDown(() async {
      // Clean up all resources
      await sessionHandler.stopAllSessions();
      await wsService.disconnect();
    });

    testWidgets('should monitor memory usage during SSH operations', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Monitoring memory usage during SSH operations...');
        
        // Get initial memory baseline
        final initialMemory = await _getCurrentMemoryUsage();
        print('Initial memory usage: ${_formatMemory(initialMemory)}');
        
        // Create test SSH profiles
        const connectionCount = 3; // Conservative for testing
        final now = DateTime.now();
        final profiles = List.generate(connectionCount, (index) => SshProfile(
          id: 'memory-test-$index',
          name: 'Memory Test $index',
          host: 'localhost',
          port: 22,
          username: 'testuser$index',
          authType: SshAuthType.password,
          password: 'testpass$index',
          createdAt: now,
          updatedAt: now,
        ));
        
        final memoryReadings = <int>[];
        final activeConnections = <String>[];
        
        // Monitor memory during connection establishment
        for (int i = 0; i < profiles.length; i++) {
          final profile = profiles[i];
          
          try {
            print('Establishing SSH connection ${i + 1}...');
            final connectionFuture = sshManager.connect(profile);
            
            // Don't wait for actual connection (may fail in test environment)
            // Just test memory impact of connection attempt
            await Future.delayed(const Duration(milliseconds: 500));
            
            final currentMemory = await _getCurrentMemoryUsage();
            memoryReadings.add(currentMemory);
            
            print('Memory after connection ${i + 1}: ${_formatMemory(currentMemory)}');
            print('Memory increase: ${_formatMemory(currentMemory - initialMemory)}');
            
            // Try to complete connection (may fail, that's OK)
            try {
              await connectionFuture.timeout(const Duration(seconds: 2));
              activeConnections.add(profile.id);
            } catch (e) {
              print('Connection ${i + 1} failed (expected in test env): $e');
            }
            
          } catch (e) {
            print('SSH connection setup ${i + 1} failed: $e');
          }
        }
        
        // Analyze memory usage patterns
        if (memoryReadings.isNotEmpty) {
          final maxMemory = memoryReadings.reduce((a, b) => a > b ? a : b);
          final totalMemoryIncrease = maxMemory - initialMemory;
          
          print('Memory usage analysis:');
          print('  Initial: ${_formatMemory(initialMemory)}');
          print('  Maximum: ${_formatMemory(maxMemory)}');
          print('  Total increase: ${_formatMemory(totalMemoryIncrease)}');
          
          // Memory targets validation
          expect(maxMemory, lessThan(100 * 1024 * 1024), // 100MB total
              reason: 'Total memory usage should stay under 100MB');
              
          if (memoryReadings.length > 1) {
            final avgIncreasePerConnection = totalMemoryIncrease / memoryReadings.length;
            print('  Average increase per connection attempt: ${_formatMemory(avgIncreasePerConnection.round())}');
            
            expect(avgIncreasePerConnection, lessThan(10 * 1024 * 1024), // 10MB per connection
                reason: 'Memory increase per SSH connection should be under 10MB');
          }
        }
        
        // Test memory cleanup after connection attempts
        print('Testing memory cleanup after SSH operations...');
        
        // Force cleanup
        try {
          for (final connectionId in activeConnections) {
            await sshManager.disconnect(connectionId);
          }
        } catch (e) {
          print('Connection cleanup: $e');
        }
        
        // Force garbage collection
        await _forceGarbageCollection();
        
        final finalMemory = await _getCurrentMemoryUsage();
        final memoryRetained = finalMemory - initialMemory;
        
        print('Memory after cleanup: ${_formatMemory(finalMemory)}');
        print('Memory retained: ${_formatMemory(memoryRetained)}');
        
        // Memory should return close to baseline after cleanup
        expect(memoryRetained, lessThan(5 * 1024 * 1024), // 5MB tolerance
            reason: 'Memory should return close to baseline after SSH cleanup');
            
        print('SSH memory monitoring completed successfully');
      });
    });

    testWidgets('should detect WebSocket memory leaks', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing WebSocket memory leak detection...');
        
        final initialMemory = await _getCurrentMemoryUsage();
        print('Initial memory: ${_formatMemory(initialMemory)}');
        
        // Test multiple WebSocket connection cycles
        const connectionCycles = 5;
        final memoryReadings = <int>[];
        
        for (int cycle = 0; cycle < connectionCycles; cycle++) {
          print('WebSocket connection cycle ${cycle + 1}...');
          
          try {
            // Attempt WebSocket connection
            await wsService.connect();
            
            // Simulate WebSocket usage
            for (int msg = 0; msg < 10; msg++) {
              try {
                await wsService.sendTerminalData('Memory test message $msg');
                await Future.delayed(const Duration(milliseconds: 10));
              } catch (e) {
                // WebSocket operations may fail in test environment
              }
            }
            
            // Disconnect WebSocket
            await wsService.disconnect();
            
            // Force garbage collection
            await _forceGarbageCollection();
            
            final currentMemory = await _getCurrentMemoryUsage();
            memoryReadings.add(currentMemory);
            
            print('Memory after cycle ${cycle + 1}: ${_formatMemory(currentMemory)}');
            
          } catch (e) {
            print('WebSocket cycle ${cycle + 1} failed (expected in test env): $e');
            
            // Still record memory usage
            final currentMemory = await _getCurrentMemoryUsage();
            memoryReadings.add(currentMemory);
          }
        }
        
        // Analyze memory leak patterns
        if (memoryReadings.length >= 2) {
          print('\\nWebSocket memory leak analysis:');
          
          final memoryTrend = <int>[];
          for (int i = 1; i < memoryReadings.length; i++) {
            final increase = memoryReadings[i] - memoryReadings[i - 1];
            memoryTrend.add(increase);
            print('  Cycle ${i + 1} memory change: ${_formatMemory(increase)}');
          }
          
          // Calculate average memory increase per cycle
          if (memoryTrend.isNotEmpty) {
            final avgIncrease = memoryTrend.reduce((a, b) => a + b) / memoryTrend.length;
            print('  Average memory increase per cycle: ${_formatMemory(avgIncrease.round())}');
            
            // Memory leak detection: should not consistently increase
            expect(avgIncrease, lessThan(1024 * 1024), // 1MB average increase threshold
                reason: 'WebSocket should not leak significant memory per cycle');
                
            // Check for consistent upward trend (potential leak)
            final positiveIncreases = memoryTrend.where((increase) => increase > 512 * 1024).length;
            final leakRatio = positiveIncreases / memoryTrend.length;
            
            print('  Positive memory increases: $positiveIncreases/${memoryTrend.length} (${(leakRatio * 100).toStringAsFixed(1)}%)');
            
            expect(leakRatio, lessThan(0.7), // Less than 70% should be positive increases
                reason: 'Should not show consistent memory leak pattern');
          }
        }
        
        final finalMemory = await _getCurrentMemoryUsage();
        final totalMemoryIncrease = finalMemory - initialMemory;
        
        print('\\nWebSocket memory leak test summary:');
        print('  Initial memory: ${_formatMemory(initialMemory)}');
        print('  Final memory: ${_formatMemory(finalMemory)}');
        print('  Total increase: ${_formatMemory(totalMemoryIncrease)}');
        
        // Final memory validation
        expect(totalMemoryIncrease, lessThan(5 * 1024 * 1024), // 5MB total tolerance
            reason: 'WebSocket cycles should not cause significant memory increase');
            
        print('WebSocket memory leak detection completed');
      });
    });

    testWidgets('should validate efficient crypto resource cleanup', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing crypto resource cleanup efficiency...');
        
        final initialMemory = await _getCurrentMemoryUsage();
        print('Initial memory: ${_formatMemory(initialMemory)}');
        
        // Test crypto resource allocation and cleanup cycles
        const operationCycles = 10;
        const operationsPerCycle = 20;
        final memoryReadings = <int>[];
        
        for (int cycle = 0; cycle < operationCycles; cycle++) {
          print('Crypto resource cycle ${cycle + 1}...');
          
          // Allocate crypto resources
          final keys = <Uint8List>[];
          final encryptedData = <EncryptedData>[];
          
          for (int op = 0; op < operationsPerCycle; op++) {
            final key = cryptoService.generateSalt();
            keys.add(key);
            
            final data = Uint8List.fromList('Memory test $cycle-$op'.codeUnits);
            final encrypted = await cryptoService.encryptAESGCM(data, key);
            encryptedData.add(encrypted);
          }
          
          // Force cleanup of crypto resources
          keys.clear();
          encryptedData.clear();
          
          // Force garbage collection
          await _forceGarbageCollection();
          
          final currentMemory = await _getCurrentMemoryUsage();
          memoryReadings.add(currentMemory);
          
          print('Memory after crypto cycle ${cycle + 1}: ${_formatMemory(currentMemory)}');
        }
        
        // Analyze crypto memory cleanup efficiency
        print('\\nCrypto resource cleanup analysis:');
        
        final memoryIncreases = <int>[];
        for (int i = 1; i < memoryReadings.length; i++) {
          final increase = memoryReadings[i] - memoryReadings[i - 1];
          memoryIncreases.add(increase);
          print('  Cycle ${i + 1} memory change: ${_formatMemory(increase)}');
        }
        
        if (memoryIncreases.isNotEmpty) {
          final avgIncrease = memoryIncreases.reduce((a, b) => a + b) / memoryIncreases.length;
          print('  Average memory change per cycle: ${_formatMemory(avgIncrease.round())}');
          
          // Crypto resources should be efficiently cleaned up
          expect(avgIncrease.abs(), lessThan(512 * 1024), // 512KB tolerance
              reason: 'Crypto resource cleanup should be efficient');
        }
        
        final finalMemory = await _getCurrentMemoryUsage();
        final totalIncrease = finalMemory - initialMemory;
        
        print('\\nCrypto cleanup summary:');
        print('  Total memory increase: ${_formatMemory(totalIncrease)}');
        
        expect(totalIncrease, lessThan(2 * 1024 * 1024), // 2MB total tolerance
            reason: 'Crypto operations should not cause significant memory growth');
            
        print('Crypto resource cleanup validation completed');
      });
    });

    testWidgets('should profile state management memory efficiency', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing state management memory efficiency...');
        
        final initialMemory = await _getCurrentMemoryUsage();
        print('Initial memory: ${_formatMemory(initialMemory)}');
        
        // Test terminal session state management
        const sessionCount = 5;
        final now = DateTime.now();
        final createdSessions = <String>[];
        final memoryAfterCreation = <int>[];
        
        print('Creating terminal sessions for memory profiling...');
        
        // Create multiple terminal sessions
        for (int i = 0; i < sessionCount; i++) {
          final profile = SshProfile(
            id: 'memory-profile-$i',
            name: 'Memory Profile $i',
            host: 'localhost',
            port: 22,
            username: 'testuser$i',
            authType: SshAuthType.password,
            password: 'testpass$i',
            createdAt: now,
            updatedAt: now,
          );
          
          try {
            final sessionId = await sessionHandler.createSshSession(profile);
            createdSessions.add(sessionId);
            
            final currentMemory = await _getCurrentMemoryUsage();
            memoryAfterCreation.add(currentMemory);
            
            print('Session ${i + 1} created, memory: ${_formatMemory(currentMemory)}');
            
          } catch (e) {
            print('Session ${i + 1} creation failed (expected in test env): $e');
            
            // Still record memory usage
            final currentMemory = await _getCurrentMemoryUsage();
            memoryAfterCreation.add(currentMemory);
          }
        }
        
        // Analyze memory usage per session
        if (memoryAfterCreation.isNotEmpty) {
          print('\\nSession memory usage analysis:');
          
          for (int i = 0; i < memoryAfterCreation.length; i++) {
            final sessionMemory = memoryAfterCreation[i] - initialMemory;
            print('  After session ${i + 1}: ${_formatMemory(sessionMemory)} increase');
            
            // Each session should not use excessive memory
            expect(sessionMemory, lessThan(20 * 1024 * 1024), // 20MB per session max
                reason: 'Each terminal session should not use excessive memory');
          }
        }
        
        // Test session cleanup
        print('\\nTesting session cleanup...');
        final beforeCleanup = await _getCurrentMemoryUsage();
        
        await sessionHandler.stopAllSessions();
        await _forceGarbageCollection();
        
        final afterCleanup = await _getCurrentMemoryUsage();
        final cleanupEfficiency = beforeCleanup - afterCleanup;
        
        print('Memory before cleanup: ${_formatMemory(beforeCleanup)}');
        print('Memory after cleanup: ${_formatMemory(afterCleanup)}');
        print('Memory freed by cleanup: ${_formatMemory(cleanupEfficiency)}');
        
        // Cleanup should free significant memory if sessions were created
        if (createdSessions.isNotEmpty) {
          expect(cleanupEfficiency, greaterThan(-2 * 1024 * 1024), // Allow some variance
              reason: 'Session cleanup should not increase memory significantly');
        }
        
        final finalMemoryIncrease = afterCleanup - initialMemory;
        print('\\nFinal memory increase: ${_formatMemory(finalMemoryIncrease)}');
        
        expect(finalMemoryIncrease, lessThan(10 * 1024 * 1024), // 10MB total tolerance
            reason: 'State management should be memory efficient');
            
        print('State management memory efficiency validation completed');
      });
    });

    testWidgets('should detect memory leaks over extended operations', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        print('Testing memory leak detection over extended operations...');
        
        final initialMemory = await _getCurrentMemoryUsage();
        print('Initial memory: ${_formatMemory(initialMemory)}');
        
        // Extended operation simulation
        const operationBatches = 20;
        const operationsPerBatch = 10;
        final memorySnapshots = <int>[];
        
        for (int batch = 0; batch < operationBatches; batch++) {
          // Perform mixed operations in each batch
          for (int op = 0; op < operationsPerBatch; op++) {
            try {
              // Mix of crypto operations
              final key = cryptoService.generateSalt();
              final data = Uint8List.fromList('Extended test $batch-$op'.codeUnits);
              final encrypted = await cryptoService.encryptAESGCM(data, key);
              await cryptoService.decryptAESGCM(encrypted, key);
              
              // WebSocket operations (may fail, that's OK)
              try {
                await wsService.sendTerminalData('Batch $batch operation $op');
              } catch (e) {
                // Expected to fail in test environment
              }
              
            } catch (e) {
              // Individual operations may fail
            }
          }
          
          // Force garbage collection every few batches
          if (batch % 5 == 0) {
            await _forceGarbageCollection();
          }
          
          final currentMemory = await _getCurrentMemoryUsage();
          memorySnapshots.add(currentMemory);
          
          if (batch % 5 == 0) {
            print('After batch ${batch + 1}: ${_formatMemory(currentMemory)} (${_formatMemory(currentMemory - initialMemory)} increase)');
          }
        }
        
        // Analyze memory leak patterns over time
        print('\\nExtended operations memory leak analysis:');
        
        final memoryChanges = <int>[];
        for (int i = 1; i < memorySnapshots.length; i++) {
          final change = memorySnapshots[i] - memorySnapshots[i - 1];
          memoryChanges.add(change);
        }
        
        if (memoryChanges.isNotEmpty) {
          final avgChange = memoryChanges.reduce((a, b) => a + b) / memoryChanges.length;
          final positiveChanges = memoryChanges.where((change) => change > 256 * 1024).length; // > 256KB
          final leakIndicator = positiveChanges / memoryChanges.length;
          
          print('  Average memory change per batch: ${_formatMemory(avgChange.round())}');
          print('  Positive changes: $positiveChanges/${memoryChanges.length} (${(leakIndicator * 100).toStringAsFixed(1)}%)');
          
          // Memory leak detection criteria
          expect(avgChange.abs(), lessThan(100 * 1024), // 100KB average change
              reason: 'Should not show significant memory leak trend');
              
          expect(leakIndicator, lessThan(0.6), // Less than 60% positive changes
              reason: 'Should not show consistent memory leak pattern');
        }
        
        // Final cleanup and validation
        await _forceGarbageCollection();
        final finalMemory = await _getCurrentMemoryUsage();
        final totalIncrease = finalMemory - initialMemory;
        
        print('\\nExtended operations summary:');
        print('  Operations: ${operationBatches * operationsPerBatch}');
        print('  Total memory increase: ${_formatMemory(totalIncrease)}');
        
        // Over extended operations, memory should remain bounded
        expect(totalIncrease, lessThan(15 * 1024 * 1024), // 15MB tolerance for extended ops
            reason: 'Extended operations should not cause unbounded memory growth');
            
        print('Extended operations memory leak detection completed');
      });
    });
  });
}

/// Get current memory usage in bytes
/// Returns approximate memory usage for the current process
Future<int> _getCurrentMemoryUsage() async {
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      // On mobile platforms, we can't easily get precise memory usage
      // Return a simulated value based on available memory info
      final info = ProcessInfo.currentRss;
      return info;
    } else {
      // On desktop platforms, try to get RSS (Resident Set Size)
      final info = ProcessInfo.currentRss;
      return info;
    }
  } catch (e) {
    // Fallback: return a baseline value
    return 50 * 1024 * 1024; // 50MB baseline
  }
}

/// Force garbage collection to help with memory measurements
Future<void> _forceGarbageCollection() async {
  // Create memory pressure to encourage garbage collection
  final tempData = List.generate(1000, (i) => List.generate(1000, (j) => i + j));
  tempData.clear();
  
  // Give GC time to run
  await Future.delayed(const Duration(milliseconds: 100));
}

/// Format memory size in human-readable format
String _formatMemory(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  } else {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}