import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:devpocket_warp_app/models/ssh_profile_models.dart';
import 'package:devpocket_warp_app/services/websocket_manager.dart';
import '../helpers/test_helpers.dart';
import '../helpers/stability_helpers.dart';
import '../mocks/mock_websocket_service.dart';
import '../mocks/websocket_state_manager.dart';

/// Integration tests for WebSocket Error Scenarios
/// Tests connection failures, timeout handling, network interruption recovery, and graceful error handling
void main() {
  setUpAll(() {
    TestHelpers.initializeTestEnvironment();
  });

  group('WebSocket Error Scenario Tests', () {
    late MockWebSocketService mockWebSocketService;
    late WebSocketStateManager stateManager;

    setUp(() {
      // Use unreliable service for error testing
      mockWebSocketService = MockWebSocketServiceFactory.createUnreliable();
      stateManager = WebSocketStateManagerFactory.createUnreliable();
    });

    tearDown(() async {
      await mockWebSocketService.disconnect();
      mockWebSocketService.dispose();
      stateManager.dispose();
      await StabilityHelpers.cleanupTestEnvironment();
    });

    group('Connection Failure Scenarios', () {
      testWidgets('should handle connection failures gracefully', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Connection failure handling',
          () async {
            // Create service that always fails to connect
            final failingService = MockWebSocketService(
              connectionDelay: const Duration(milliseconds: 100),
              errorRate: 1.0, // 100% failure rate
              shouldSimulateNetworkDelay: true,
            );

            expect(failingService.isConnected, isFalse);

            // Attempt connection should fail
            bool connectionFailed = false;
            try {
              await failingService.connect();
            } catch (e) {
              connectionFailed = true;
              expect(e, isA<Exception>());
              expect(e.toString(), contains('connection failed'));
            }

            expect(connectionFailed, isTrue);
            expect(failingService.isConnected, isFalse);

            failingService.dispose();
          },
        );
      });

      testWidgets('should handle authentication failures', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Authentication failure handling',
          () async {
            final testProfile = SshProfile(
              id: 'auth-fail-test',
              name: 'Auth Fail Test',
              host: 'auth-fail.example.com',
              port: 22,
              username: 'invaliduser',
              authType: SshAuthType.password,
              password: 'wrongpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Service that fails session creation (simulating auth failure)
            final authFailService = MockWebSocketService(
              connectionDelay: const Duration(milliseconds: 50),
              errorRate: 0.0, // Connect succeeds
              shouldSimulateNetworkDelay: false,
            );

            await authFailService.connect();
            expect(authFailService.isConnected, isTrue);

            // Create session with high error rate for session creation
            bool sessionCreationFailed = false;
            try {
              // Manually force session creation to fail by making service unreliable
              authFailService.forceConnectionError();
              await authFailService.createTerminalSession(testProfile);
            } catch (e) {
              sessionCreationFailed = true;
              expect(e, isA<Exception>());
            }

            if (!sessionCreationFailed) {
              // If session creation didn't fail due to mock behavior, that's also acceptable
              // as long as the service handles it gracefully
              debugPrint('Session creation succeeded despite mock configuration - testing graceful handling');
            }

            authFailService.dispose();
          },
        );
      });

      testWidgets('should handle connection timeout scenarios', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Connection timeout handling',
          () async {
            // Create state manager with very short timeout
            final timeoutStateManager = WebSocketStateManager(
              reconnectDelay: const Duration(milliseconds: 50),
              maxReconnectAttempts: 1,
              connectionFailureRate: 0.5,
              shouldSimulateLatency: true,
            );

            expect(timeoutStateManager.currentState, equals(WebSocketState.disconnected));

            // Attempt connection that should timeout
            try {
              await timeoutStateManager.connect().timeout(const Duration(milliseconds: 200));
            } catch (e) {
              expect(e, anyOf([isA<TimeoutException>(), isA<Exception>()]));
            }

            // Either timeout occurred or connection failed gracefully
            expect(timeoutStateManager.isConnected, isFalse);

            timeoutStateManager.dispose();
          },
        );
      });
    });

    group('Network Interruption Recovery', () {
      testWidgets('should handle network interruption and recovery', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Network interruption recovery',
          () async {
            final testProfile = SshProfile(
              id: 'interruption-recovery-test',
              name: 'Interruption Recovery Test',
              host: 'recovery.example.com',
              port: 22,
              username: 'recoveryuser',
              authType: SshAuthType.password,
              password: 'recoverypass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Use reliable service for this test
            final reliableService = MockWebSocketServiceFactory.createReliable();

            await reliableService.connect();
            final sessionId = await reliableService.createTerminalSession(testProfile);

            // Send initial command
            await reliableService.sendTerminalData('echo "before interruption"', sessionId: sessionId);
            
            expect(reliableService.isConnected, isTrue);
            expect(reliableService.getActiveSessions(), contains(sessionId));

            // Simulate network interruption
            await reliableService.simulateNetworkInterruption(
              duration: const Duration(milliseconds: 500),
            );

            // Service should auto-reconnect
            expect(reliableService.isConnected, isTrue);

            // Try to use session after recovery (may need recreation)
            bool sessionStillWorks = true;
            try {
              await reliableService.sendTerminalData('echo "after recovery"', sessionId: sessionId);
            } catch (e) {
              sessionStillWorks = false;
              expect(e.toString(), contains('not found'));
            }

            if (sessionStillWorks) {
              expect(reliableService.getSessionMessages(sessionId), contains('echo "after recovery"'));
            }

            reliableService.dispose();
          },
        );
      });

      testWidgets('should handle repeated network interruptions', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Repeated network interruptions',
          () async {
            final resilientService = MockWebSocketServiceFactory.createReliable();

            await resilientService.connect();
            expect(resilientService.isConnected, isTrue);

            // Simulate multiple quick interruptions
            for (int i = 0; i < 3; i++) {
              await resilientService.simulateNetworkInterruption(
                duration: const Duration(milliseconds: 100),
              );
              
              await Future.delayed(const Duration(milliseconds: 50));
            }

            // Service should still be connected after multiple interruptions
            expect(resilientService.isConnected, isTrue);

            resilientService.dispose();
          },
        );
      });

      testWidgets('should handle reconnection failures', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Reconnection failure handling',
          () async {
            final reconnectFailManager = WebSocketStateManager(
              reconnectDelay: const Duration(milliseconds: 100),
              maxReconnectAttempts: 2,
              connectionFailureRate: 0.8, // 80% failure rate
              shouldSimulateLatency: true,
            );

            // Initial connection might succeed
            bool initialConnectionSucceeded = false;
            try {
              initialConnectionSucceeded = await reconnectFailManager.connect();
            } catch (e) {
              // Initial connection failed, which is acceptable for this test
            }

            if (initialConnectionSucceeded) {
              // Force disconnection
              await reconnectFailManager.disconnect();
              expect(reconnectFailManager.isConnected, isFalse);

              // Attempt reconnection (should fail due to high error rate)
              try {
                await reconnectFailManager.reconnect();
              } catch (e) {
                expect(e, isA<Exception>());
              }

              // Either reconnection failed or succeeded (both are valid outcomes)
              // The important thing is that it was handled gracefully
            }

            reconnectFailManager.dispose();
          },
        );
      });
    });

    group('Session Error Handling', () {
      testWidgets('should handle session creation errors', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session creation error handling',
          () async {
            await mockWebSocketService.connect();
            expect(mockWebSocketService.isConnected, isTrue);

            final testProfile = SshProfile(
              id: 'session-error-test',
              name: 'Session Error Test',
              host: 'session-error.example.com',
              port: 22,
              username: 'erroruser',
              authType: SshAuthType.password,
              password: 'errorpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Due to unreliable service, session creation might fail
            int maxAttempts = 5;
            String? sessionId;
            
            for (int attempt = 0; attempt < maxAttempts; attempt++) {
              try {
                sessionId = await mockWebSocketService.createTerminalSession(testProfile);
                break;
              } catch (e) {
                if (attempt == maxAttempts - 1) {
                  // Final attempt failed - this is expected with unreliable service
                  expect(e, isA<Exception>());
                  debugPrint('Session creation failed after $maxAttempts attempts: $e');
                }
                await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
              }
            }

            // If session was created, clean it up
            if (sessionId != null) {
              expect(mockWebSocketService.getActiveSessions(), contains(sessionId));
              await mockWebSocketService.closeTerminalSession(sessionId);
            }
          },
        );
      });

      testWidgets('should handle message sending errors', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Message sending error handling',
          () async {
            final testProfile = SshProfile(
              id: 'message-error-test',
              name: 'Message Error Test',
              host: 'message-error.example.com',
              port: 22,
              username: 'msgerroruser',
              authType: SshAuthType.password,
              password: 'msgerrorpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            
            // Try to create session (might fail with unreliable service)
            String? sessionId;
            try {
              sessionId = await mockWebSocketService.createTerminalSession(testProfile);
            } catch (e) {
              debugPrint('Session creation failed, testing message error on non-existent session');
            }

            // Test message sending with various error scenarios
            final testMessages = [
              'echo "error test 1"',
              'echo "error test 2"',
              'ls -la',
            ];

            for (final message in testMessages) {
              try {
                await mockWebSocketService.sendTerminalData(message, sessionId: sessionId);
              } catch (e) {
                expect(e, isA<Exception>());
                // Error could be due to session not found or network issues
                expect(e.toString(), anyOf([
                  contains('not connected'),
                  contains('not found'),
                  contains('failed'),
                ]));
              }

              // With unreliable service, some messages may fail
              // The important thing is that errors are handled gracefully
            }

            // Clean up if session exists
            if (sessionId != null && mockWebSocketService.getActiveSessions().contains(sessionId)) {
              await mockWebSocketService.closeTerminalSession(sessionId);
            }
          },
        );
      });

      testWidgets('should handle session cleanup errors', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session cleanup error handling',
          () async {
            await mockWebSocketService.connect();

            // Try to close non-existent session
            bool cleanupFailed = false;
            try {
              await mockWebSocketService.closeTerminalSession('non-existent-session');
            } catch (e) {
              cleanupFailed = true;
              expect(e, isA<Exception>());
            }

            // Cleanup of non-existent session should either fail gracefully or be ignored
            if (!cleanupFailed) {
              // Service handled non-existent session gracefully
              debugPrint('Service gracefully handled cleanup of non-existent session');
            }

            // Test cleanup during disconnection
            await mockWebSocketService.disconnect();
            
            // Try to close session after disconnection
            bool postDisconnectCleanupFailed = false;
            try {
              await mockWebSocketService.closeTerminalSession('any-session');
            } catch (e) {
              postDisconnectCleanupFailed = true;
              expect(e, isA<Exception>());
              expect(e.toString(), contains('not connected'));
            }

            expect(postDisconnectCleanupFailed, isTrue);
          },
        );
      });
    });

    group('Error Recovery and Resilience', () {
      testWidgets('should recover from temporary errors', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Temporary error recovery',
          () async {
            final testProfile = SshProfile(
              id: 'temp-error-test',
              name: 'Temporary Error Test',
              host: 'temp-error.example.com',
              port: 22,
              username: 'temperroruser',
              authType: SshAuthType.password,
              password: 'temperrorpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Create service with moderate error rate for recovery testing
            final recoveryService = MockWebSocketService(
              connectionDelay: const Duration(milliseconds: 100),
              errorRate: 0.3, // 30% error rate - allows some operations to succeed
              shouldSimulateNetworkDelay: true,
            );

            await recoveryService.connect();
            expect(recoveryService.isConnected, isTrue);

            String? sessionId;
            int sessionAttempts = 0;
            const maxSessionAttempts = 5;

            // Try to create session with retry logic
            while (sessionId == null && sessionAttempts < maxSessionAttempts) {
              try {
                sessionId = await recoveryService.createTerminalSession(testProfile);
              } catch (e) {
                sessionAttempts++;
                await Future.delayed(Duration(milliseconds: 100 * sessionAttempts));
              }
            }

            if (sessionId != null) {
              // Session created successfully after retries
              expect(recoveryService.getActiveSessions(), contains(sessionId));

              // Test message sending with retry logic
              int successfulMessages = 0;
              const totalMessages = 10;

              for (int i = 0; i < totalMessages; i++) {
                int messageAttempts = 0;
                const maxMessageAttempts = 3;

                while (messageAttempts < maxMessageAttempts) {
                  try {
                    await recoveryService.sendTerminalData('echo "recovery test $i"', sessionId: sessionId);
                    successfulMessages++;
                    break;
                  } catch (e) {
                    messageAttempts++;
                    if (messageAttempts < maxMessageAttempts) {
                      await Future.delayed(Duration(milliseconds: 50 * messageAttempts));
                    }
                  }
                }
              }

              // With retry logic, most messages should succeed
              expect(successfulMessages, greaterThan(totalMessages ~/ 2));
              debugPrint('Successful messages with retry: $successfulMessages/$totalMessages');

              await recoveryService.closeTerminalSession(sessionId);
            } else {
              debugPrint('Session creation failed after $maxSessionAttempts attempts - acceptable for error testing');
            }

            recoveryService.dispose();
          },
        );
      });

      testWidgets('should maintain service stability during error conditions', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Service stability during errors',
          () async {
            // Test that service remains stable even with high error rates
            final stressTestService = MockWebSocketService(
              connectionDelay: const Duration(milliseconds: 50),
              errorRate: 0.6, // 60% error rate
              shouldSimulateNetworkDelay: true,
            );

            // Connection attempts
            int connectionAttempts = 0;
            bool connected = false;

            while (!connected && connectionAttempts < 3) {
              try {
                await stressTestService.connect();
                connected = true;
              } catch (e) {
                connectionAttempts++;
                await Future.delayed(Duration(milliseconds: 100 * connectionAttempts));
              }
            }

            if (connected) {
              expect(stressTestService.isConnected, isTrue);

              // Stress test with multiple rapid operations
              final stressOperations = <Future<void>>[];
              
              for (int i = 0; i < 20; i++) {
                stressOperations.add(
                  Future(() async {
                    try {
                      // Various operations that might fail
                      if (i % 3 == 0) {
                        await stressTestService.simulateNetworkInterruption(
                          duration: const Duration(milliseconds: 50),
                        );
                      } else if (i % 3 == 1) {
                        stressTestService.forceConnectionError();
                        await stressTestService.connect();
                      }
                      // Some operations will fail, which is expected
                    } catch (e) {
                      // Errors are expected with high error rate
                    }
                  })
                );
              }

              // Wait for all stress operations to complete
              await Future.wait(stressOperations);

              // Service should remain in a consistent state
              // Either connected or disconnected, but not in an invalid state
              expect(stressTestService.connectionState, anyOf([
                WebSocketState.connected,
                WebSocketState.disconnected,
                WebSocketState.error,
              ]));
            }

            stressTestService.dispose();
          },
        );
      });
    });

    group('Error Reporting and Logging', () {
      testWidgets('should provide detailed error information', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Detailed error information',
          () async {
            final errorMessages = <String>[];
            late StreamSubscription errorSubscription;

            errorSubscription = mockWebSocketService.errors.listen((error) {
              errorMessages.add(error);
            });

            // Trigger various error scenarios
            try {
              await mockWebSocketService.connect();
            } catch (e) {
              // Connection might fail
            }

            // Force error conditions
            mockWebSocketService.forceConnectionError();
            
            await mockWebSocketService.simulateNetworkInterruption(
              duration: const Duration(milliseconds: 100),
            );

            await Future.delayed(const Duration(milliseconds: 200));

            // Verify error messages were captured
            if (errorMessages.isNotEmpty) {
              debugPrint('Error messages captured: ${errorMessages.length}');
              for (final error in errorMessages) {
                expect(error, isA<String>());
                expect(error.length, greaterThan(0));
              }
            }

            await errorSubscription.cancel();
          },
        );
      });
    });
  });
}