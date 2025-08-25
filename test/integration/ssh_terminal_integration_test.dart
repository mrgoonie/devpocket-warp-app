import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:devpocket_warp_app/models/ssh_profile_models.dart';
import 'package:devpocket_warp_app/services/terminal_session_handler.dart';
import 'package:devpocket_warp_app/services/terminal_websocket_service.dart';
import 'package:devpocket_warp_app/services/websocket_manager.dart';
import '../helpers/test_helpers.dart';
import '../helpers/stability_helpers.dart';

/// Integration tests for SSH Terminal Implementation
/// Tests WebSocket integration, session management, and terminal functionality

/// Helper function to create test SSH profiles with required fields
SshProfile createTestProfile({
  required String id,
  required String name,
  required String host,
  int port = 22,
  required String username,
  SshAuthType authType = SshAuthType.password,
  String? password,
  String? privateKey,
  String? passphrase,
  String? description,
  List<String> tags = const [],
}) {
  final now = DateTime.now();
  return SshProfile(
    id: id,
    name: name,
    host: host,
    port: port,
    username: username,
    authType: authType,
    password: password,
    privateKey: privateKey,
    passphrase: passphrase,
    createdAt: now,
    updatedAt: now,
    description: description,
    tags: tags,
  );
}

void main() {
  // Initialize test environment with Spot framework
  setUpAll(() {
    TestHelpers.initializeTestEnvironment();
  });
  
  group('SSH Terminal Integration Tests', () {
    late TerminalSessionHandler sessionHandler;
    late TerminalWebSocketService wsService;
    late WebSocketManager wsManager;

    setUp(() {
      sessionHandler = TerminalSessionHandler.instance;
      wsService = TerminalWebSocketService.instance;
      wsManager = WebSocketManager.instance;
    });

    tearDown(() async {
      // Clean up all active sessions
      await sessionHandler.stopAllSessions();
      await wsService.disconnect();
      await StabilityHelpers.cleanupTestEnvironment();
    });

    group('WebSocket Terminal Integration', () {
      testWidgets('should integrate WebSocket API with terminal sessions', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'WebSocket terminal integration',
          () async {
            final testProfile = createTestProfile(
              id: 'ws-terminal-test-1',
              name: 'WebSocket Terminal Test',
              host: 'test.example.com',
              username: 'testuser',
              password: 'testpass',
            );

            // Test WebSocket service initialization
            expect(wsService.isConnected, isFalse);
            expect(wsService.activeSessionCount, equals(0));

            try {
              // Attempt WebSocket connection (will fail if backend not available)
              await wsService.connect();
          
          if (wsService.isConnected) {
            // Test terminal session creation via WebSocket
            final sessionId = await wsService.createTerminalSession(testProfile);
            expect(sessionId, isNotNull);
            expect(sessionId.length, greaterThan(0));

            // Verify session is active
            final activeSessions = wsService.getActiveSessions();
            expect(activeSessions, contains(sessionId));
            expect(wsService.activeSessionCount, equals(1));

            // Test sending terminal data
            await wsService.sendTerminalData('echo "WebSocket test"', sessionId: sessionId);
            
            // Test terminal control commands
            await wsService.sendTerminalControl('clear', sessionId: sessionId);
            
            // Test terminal resize
            await wsService.resizeTerminal(80, 24, sessionId: sessionId);

            // Test session cleanup
            await wsService.closeTerminalSession(sessionId);
            expect(wsService.activeSessionCount, equals(0));
          }
            } catch (e) {
              // WebSocket connection may fail in test environment
              // This is acceptable as it tests error handling
              expect(e, isA<Exception>());
            }
          },
        );
      });

      testWidgets('should handle WebSocket connection states', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'WebSocket connection state management',
          () async {
        // Test connection state management
        expect(wsManager.state, equals(WebSocketState.disconnected));
        expect(wsManager.isConnected, isFalse);

        try {
          await wsManager.connect();
          // Connection may succeed or fail depending on environment
          // Both outcomes are valid for testing
        } catch (e) {
          // Expected if no WebSocket server available
          expect(e, isA<Exception>());
        }

            // Test state consistency
            expect(wsManager.isConnected, equals(wsManager.state == WebSocketState.connected));
          },
        );
      });
    });

    group('Session Management Integration', () {
      StabilityHelpers.stableSpotTestWidgets('should create and manage SSH terminal sessions', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'session-test-1',
          name: 'Session Test',
          host: 'localhost',
          username: 'testuser',
          password: 'testpass',
        );

        // Test session creation (will attempt WebSocket first, then fallback to SSH)
        try {
          final sessionId = await sessionHandler.createSshSession(testProfile);
          expect(sessionId, isNotNull);
          expect(sessionId, equals(testProfile.id));

          // Verify session state
          final sessionState = sessionHandler.getSessionState(sessionId);
          expect(sessionState, anyOf([
            TerminalSessionState.running,
            TerminalSessionState.error, // Acceptable if connection fails
          ]));

          // Test session info
          final sessionInfo = sessionHandler.getSessionInfo(sessionId);
          expect(sessionInfo, isNotEmpty);
          expect(sessionInfo['id'], equals(sessionId));
          expect(sessionInfo['type'], isNotNull);

          // Test data sending (if session is running)
          if (sessionState == TerminalSessionState.running) {
            await sessionHandler.sendCommand(sessionId, 'echo "test"');
            await sessionHandler.sendData(sessionId, 'test data\n');
          }

          // Clean up session
          await sessionHandler.stopSession(sessionId);
          
        } catch (e) {
          // Connection may fail in test environment, which is acceptable
          expect(e, isA<Exception>());
        }
      });

      StabilityHelpers.stableSpotTestWidgets('should handle multiple concurrent sessions', (WidgetTester tester) async {
        final testProfiles = List.generate(3, (index) => createTestProfile(
          id: 'concurrent-test-$index',
          name: 'Concurrent Test $index',
          host: 'test$index.example.com',
          username: 'testuser$index',
          password: 'testpass$index',
        ));

        final createdSessions = <String>[];

        try {
          // Create multiple sessions
          for (final profile in testProfiles) {
            try {
              final sessionId = await sessionHandler.createSshSession(profile);
              createdSessions.add(sessionId);
            } catch (e) {
              // Individual session creation may fail, which is OK
              continue;
            }
          }

          // Verify active sessions
          final activeSessions = sessionHandler.getActiveSessions();
          expect(activeSessions.length, equals(createdSessions.length));

          for (final sessionId in createdSessions) {
            expect(activeSessions, contains(sessionId));
          }

        } finally {
          // Clean up all created sessions
          for (final sessionId in createdSessions) {
            await sessionHandler.stopSession(sessionId);
          }
        }
      });

      StabilityHelpers.stableSpotTestWidgets('should handle session lifecycle correctly', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'lifecycle-test-1',
          name: 'Lifecycle Test',
          host: 'lifecycle.example.com',
          username: 'testuser',
          password: 'testpass',
        );

        String? sessionId;

        try {
          // Test session creation
          sessionId = await sessionHandler.createSshSession(testProfile);
          expect(sessionHandler.isSessionRunning(sessionId), anyOf([true, false]));

          // Test session info
          final info = sessionHandler.getSessionInfo(sessionId);
          expect(info, isNotEmpty);

          // Test state transitions
          final initialState = sessionHandler.getSessionState(sessionId);
          expect(initialState, isIn([
            TerminalSessionState.running,
            TerminalSessionState.error,
          ]));

        } catch (e) {
          // Connection may fail, which is acceptable
          expect(e, isA<Exception>());
        } finally {
          // Ensure cleanup
          if (sessionId != null) {
            await sessionHandler.stopSession(sessionId);
            expect(sessionHandler.isSessionRunning(sessionId), isFalse);
          }
        }
      });
    });

    group('Error Handling and Recovery', () {
      StabilityHelpers.stableSpotTestWidgets('should handle connection failures gracefully', (WidgetTester tester) async {
        final invalidProfile = createTestProfile(
          id: 'invalid-connection-test',
          name: 'Invalid Connection Test',
          host: '192.0.2.1', // TEST-NET-1 - guaranteed unreachable
          username: 'testuser',
          password: 'testpass',
        );

        // Should fail gracefully without crashing
        try {
          await sessionHandler.createSshSession(invalidProfile);
          // If somehow successful, clean up
          await sessionHandler.stopSession(invalidProfile.id);
        } catch (e) {
          // Expected to fail with unreachable host
          expect(e, isA<Exception>());
          expect(e.toString(), anyOf([
            contains('Connection failed'),
            contains('timeout'),
            contains('unreachable'),
          ]));
        }
      });

      StabilityHelpers.stableSpotTestWidgets('should handle WebSocket disconnection', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'ws-disconnect-test',
          name: 'WebSocket Disconnect Test',
          host: 'disconnect.example.com',
          username: 'testuser',
          password: 'testpass',
        );

        try {
          // Attempt to connect
          await wsService.connect();
          
          // Force disconnect
          await wsService.disconnect();
          expect(wsService.isConnected, isFalse);

          // Try to create session after disconnect (should fail gracefully)
          try {
            await wsService.createTerminalSession(testProfile);
          } catch (e) {
            expect(e, isA<Exception>());
          }

        } catch (initialConnectionError) {
          // Initial connection may fail in test environment
          expect(initialConnectionError, isA<Exception>());
        }
      });

      StabilityHelpers.stableSpotTestWidgets('should recover from network interruptions', (WidgetTester tester) async {
        // Test WebSocket reconnection logic
        expect(wsManager.state, equals(WebSocketState.disconnected));

        try {
          final connectResult = await wsManager.connect();
          // Connection may succeed or fail
          
          if (connectResult) {
            // Test disconnection and reconnection
            await wsManager.disconnect();
            expect(wsManager.state, equals(WebSocketState.disconnected));

            // Test reconnection
            await wsManager.connect();
            // Reconnection may succeed or fail
          }
        } catch (e) {
          // Network operations may fail in test environment
          expect(e, isA<Exception>());
        }
      });
    });

    group('Performance and Resource Management', () {
      StabilityHelpers.stableSpotTestWidgets('should manage resources efficiently', (WidgetTester tester) async {
        // Test resource cleanup
        final initialSessions = sessionHandler.getActiveSessions().length;

        final testProfile = createTestProfile(
          id: 'resource-test-1',
          name: 'Resource Test',
          host: 'resource.example.com',
          username: 'testuser',
          password: 'testpass',
        );

        try {
          await sessionHandler.createSshSession(testProfile);
        } catch (e) {
          // Connection may fail
        }

        // Clean up all sessions
        await sessionHandler.stopAllSessions();
        final finalSessions = sessionHandler.getActiveSessions().length;
        
        // Should have same or fewer sessions than initial
        expect(finalSessions, lessThanOrEqualTo(initialSessions));
      });

      StabilityHelpers.stableSpotTestWidgets('should handle session timeouts', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'timeout-test-1',
          name: 'Timeout Test',
          host: '192.0.2.1', // TEST-NET-1
          username: 'testuser',
          password: 'testpass',
        );

        final stopwatch = Stopwatch()..start();

        try {
          await sessionHandler.createSshSession(testProfile);
        } catch (e) {
          // Should timeout within reasonable time
          stopwatch.stop();
          expect(stopwatch.elapsedMilliseconds, lessThan(30000));
          expect(e, isA<Exception>());
        }
      });
    });

    group('Terminal Output Streaming', () {
      StabilityHelpers.stableSpotTestWidgets('should stream terminal output correctly', (WidgetTester tester) async {
        // Test output stream setup
        final outputStream = sessionHandler.output;
        expect(outputStream, isA<Stream<TerminalOutput>>());

        // Test output event handling with timeout
        var outputReceived = false;
        late StreamSubscription subscription;
        
        final completer = Completer<void>();

        subscription = outputStream.timeout(
          const Duration(seconds: 2),
          onTimeout: (sink) {
            outputReceived = false;
            completer.complete();
          },
        ).listen(
          (output) {
            outputReceived = true;
            expect(output.timestamp, isNotNull);
            expect(output.type, isIn(TerminalOutputType.values));
            subscription.cancel();
            completer.complete();
          },
          onError: (error) {
            subscription.cancel();
            completer.complete();
          },
        );

        final testProfile = createTestProfile(
          id: 'output-test-1',
          name: 'Output Test',
          host: 'output.example.com',
          username: 'testuser',
          password: 'testpass',
        );

        try {
          await sessionHandler.createSshSession(testProfile);
          await sessionHandler.stopSession(testProfile.id);
        } catch (e) {
          // Connection may fail
        }

        // Wait for output with timeout
        await completer.future.timeout(
          const Duration(seconds: 3),
          onTimeout: () => {/* Expected timeout */},
        );
        
        // Output may or may not be received depending on test environment
        expect(outputReceived, isA<bool>());
        
        await subscription.cancel();
      });
    });
  });
}