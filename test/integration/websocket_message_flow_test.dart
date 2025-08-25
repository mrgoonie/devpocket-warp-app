import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';

import 'package:devpocket_warp_app/models/ssh_profile_models.dart';
import '../helpers/test_helpers.dart';
import '../helpers/stability_helpers.dart';
import '../mocks/mock_websocket_service.dart';
import '../mocks/websocket_state_manager.dart';

/// Integration tests for WebSocket Message Flow Validation
/// Tests message transmission, ordering, integrity, and delivery confirmation
void main() {
  setUpAll(() {
    TestHelpers.initializeTestEnvironment();
  });

  group('WebSocket Message Flow Validation Tests', () {
    late MockWebSocketService mockWebSocketService;
    late WebSocketStateManager stateManager;

    setUp(() {
      mockWebSocketService = MockWebSocketServiceFactory.createReliable();
      stateManager = WebSocketStateManagerFactory.createReliable();
    });

    tearDown(() async {
      await mockWebSocketService.disconnect();
      mockWebSocketService.dispose();
      stateManager.dispose();
      await StabilityHelpers.cleanupTestEnvironment();
    });

    group('Basic Message Transmission', () {
      testWidgets('should transmit and receive terminal commands correctly', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Basic command transmission',
          () async {
            // Create test profile
            final testProfile = SshProfile(
              id: 'message-test-1',
              name: 'Message Test Server',
              host: 'test.example.com',
              port: 22,
              username: 'testuser',
              authType: SshAuthType.password,
              password: 'testpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Establish connection
            await mockWebSocketService.connect();
            expect(mockWebSocketService.isConnected, isTrue);

            // Create terminal session
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);
            expect(sessionId, isNotNull);
            expect(sessionId.length, greaterThan(0));

            // Test command transmission
            const testCommand = 'echo "Hello WebSocket"';
            await mockWebSocketService.sendTerminalData(testCommand, sessionId: sessionId);

            // Verify session message history
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            expect(sessionMessages, contains(testCommand));

            // Clean up
            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should handle multiple simultaneous messages', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Simultaneous message handling',
          () async {
            final testProfile = SshProfile(
              id: 'multi-message-test',
              name: 'Multi Message Test',
              host: 'multi.example.com',
              port: 22,
              username: 'multiuser',
              authType: SshAuthType.password,
              password: 'multipass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send multiple messages rapidly
            final testMessages = [
              'ls -la',
              'pwd',
              'whoami',
              'date',
              'echo "test1"',
              'echo "test2"',
              'echo "test3"',
            ];

            final futures = testMessages.map((message) =>
                mockWebSocketService.sendTerminalData(message, sessionId: sessionId)).toList();
            
            await Future.wait(futures);

            // Verify all messages were handled
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            for (final message in testMessages) {
              expect(sessionMessages, contains(message));
            }

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Message Ordering and Integrity', () {
      testWidgets('should maintain message order under load', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Message ordering validation',
          () async {
            final testProfile = SshProfile(
              id: 'order-test',
              name: 'Order Test',
              host: 'order.example.com',
              port: 22,
              username: 'orderuser',
              authType: SshAuthType.password,
              password: 'orderpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send numbered messages to test ordering
            final orderedMessages = <String>[];
            for (int i = 1; i <= 10; i++) {
              final message = 'echo "message_$i"';
              orderedMessages.add(message);
              await mockWebSocketService.sendTerminalData(message, sessionId: sessionId);
              
              // Small delay to ensure ordering
              await Future.delayed(const Duration(milliseconds: 10));
            }

            // Verify message order
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            final actualOrder = sessionMessages.where((msg) => msg.startsWith('echo "message_')).toList();
            
            expect(actualOrder, equals(orderedMessages));

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should preserve message content integrity', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Message content integrity',
          () async {
            final testProfile = SshProfile(
              id: 'integrity-test',
              name: 'Integrity Test',
              host: 'integrity.example.com',
              port: 22,
              username: 'integrityuser',
              authType: SshAuthType.password,
              password: 'integritypass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Test various message types and special characters
            final testMessages = [
              'echo "Hello World"',
              'echo "Special chars: !@#\$%^&*()_+"',
              'echo "Unicode: 🌟✨💫"',
              'echo "Multi\\nline\\ntext"',
              'cat /dev/null',
              'ls -la | grep test',
              'find . -name "*.dart" -type f',
            ];

            for (final message in testMessages) {
              await mockWebSocketService.sendTerminalData(message, sessionId: sessionId);
              
              // Verify message was stored correctly
              final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
              expect(sessionMessages, contains(message));
            }

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Message Delivery and Confirmation', () {
      testWidgets('should confirm message delivery', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Message delivery confirmation',
          () async {
            final testProfile = SshProfile(
              id: 'delivery-test',
              name: 'Delivery Test',
              host: 'delivery.example.com',
              port: 22,
              username: 'deliveryuser',
              authType: SshAuthType.password,
              password: 'deliverypass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Monitor message stream
            final receivedMessages = <Map<String, dynamic>>[];
            late StreamSubscription messageSubscription;
            
            messageSubscription = mockWebSocketService.messages.listen((message) {
              try {
                final decoded = jsonDecode(message);
                if (decoded['type'] == 'terminal_input') {
                  receivedMessages.add(decoded);
                }
              } catch (e) {
                // Ignore non-JSON messages
              }
            });

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send test message
            const testMessage = 'echo "delivery test"';
            await mockWebSocketService.sendTerminalData(testMessage, sessionId: sessionId);

            // Wait for message to be processed
            await Future.delayed(const Duration(milliseconds: 200));

            // Verify delivery confirmation
            expect(receivedMessages, isNotEmpty);
            final deliveredMessage = receivedMessages.firstWhere(
              (msg) => msg['data'] == testMessage && msg['session_id'] == sessionId,
              orElse: () => <String, dynamic>{},
            );
            expect(deliveredMessage, isNotEmpty);
            expect(deliveredMessage['type'], equals('terminal_input'));
            expect(deliveredMessage['data'], equals(testMessage));
            expect(deliveredMessage['session_id'], equals(sessionId));

            await messageSubscription.cancel();
            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should handle message acknowledgment', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Message acknowledgment handling',
          () async {
            final testProfile = SshProfile(
              id: 'ack-test',
              name: 'ACK Test',
              host: 'ack.example.com',
              port: 22,
              username: 'ackuser',
              authType: SshAuthType.password,
              password: 'ackpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Test message with acknowledgment tracking
            const testMessage = 'ls -la';
            final sendTime = DateTime.now();
            
            await mockWebSocketService.sendTerminalData(testMessage, sessionId: sessionId);

            // Verify message was acknowledged within reasonable time
            final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            expect(sessionInfo['is_active'], isTrue);
            expect(sessionInfo['message_count'], greaterThan(0));

            final processingTime = DateTime.now().difference(sendTime);
            expect(processingTime.inMilliseconds, lessThan(1000)); // Should be processed quickly

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Message Flow Control', () {
      testWidgets('should handle backpressure correctly', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Backpressure handling',
          () async {
            final testProfile = SshProfile(
              id: 'backpressure-test',
              name: 'Backpressure Test',
              host: 'backpressure.example.com',
              port: 22,
              username: 'backpressureuser',
              authType: SshAuthType.password,
              password: 'backpressurepass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send many messages rapidly to test backpressure
            final messageBatch = <Future<void>>[];
            for (int i = 0; i < 50; i++) {
              messageBatch.add(
                mockWebSocketService.sendTerminalData('echo "batch_$i"', sessionId: sessionId)
              );
            }

            // All messages should complete without error
            await Future.wait(messageBatch);

            // Verify all messages were handled
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            expect(sessionMessages.length, greaterThanOrEqualTo(50));

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should manage message queuing during reconnection', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Message queuing during reconnection',
          () async {
            final testProfile = SshProfile(
              id: 'queue-test',
              name: 'Queue Test',
              host: 'queue.example.com',
              port: 22,
              username: 'queueuser',
              authType: SshAuthType.password,
              password: 'queuepass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send initial message
            await mockWebSocketService.sendTerminalData('echo "before disconnect"', sessionId: sessionId);

            // Simulate network interruption
            await mockWebSocketService.simulateNetworkInterruption(
              duration: const Duration(milliseconds: 500),
            );

            // Try to send message during disconnection (should be queued or handled gracefully)
            bool messageFailed = false;
            try {
              await mockWebSocketService.sendTerminalData('echo "during disconnect"', sessionId: sessionId);
            } catch (e) {
              messageFailed = true;
              expect(e.toString(), contains('not connected'));
            }

            // Either the message should fail or be queued for later delivery
            expect(messageFailed, isTrue);

            // Reconnect and send another message
            await mockWebSocketService.connect();
            await mockWebSocketService.sendTerminalData('echo "after reconnect"', sessionId: sessionId);

            // Verify session still works after reconnection
            final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            expect(sessionInfo['is_active'], isTrue);

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Terminal Control Commands', () {
      testWidgets('should handle terminal control commands', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Terminal control commands',
          () async {
            final testProfile = SshProfile(
              id: 'control-test',
              name: 'Control Test',
              host: 'control.example.com',
              port: 22,
              username: 'controluser',
              authType: SshAuthType.password,
              password: 'controlpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Test various control commands
            final controlCommands = ['clear', 'reset'];
            
            for (final command in controlCommands) {
              await mockWebSocketService.sendTerminalControl(command, sessionId: sessionId);
              
              // Small delay to process command
              await Future.delayed(const Duration(milliseconds: 50));
            }

            // Test terminal resize
            await mockWebSocketService.resizeTerminal(80, 24, sessionId: sessionId);
            await mockWebSocketService.resizeTerminal(120, 40, sessionId: sessionId);

            // Session should still be active after control commands
            expect(mockWebSocketService.getActiveSessions(), contains(sessionId));

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should validate terminal resize operations', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Terminal resize validation',
          () async {
            final testProfile = SshProfile(
              id: 'resize-test',
              name: 'Resize Test',
              host: 'resize.example.com',
              port: 22,
              username: 'resizeuser',
              authType: SshAuthType.password,
              password: 'resizepass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Monitor terminal resize messages
            final resizeMessages = <Map<String, dynamic>>[];
            late StreamSubscription resizeSubscription;
            
            resizeSubscription = mockWebSocketService.messages.listen((message) {
              try {
                final decoded = jsonDecode(message);
                if (decoded['type'] == 'terminal_resize') {
                  resizeMessages.add(decoded);
                }
              } catch (e) {
                // Ignore non-JSON messages
              }
            });

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Test different terminal sizes
            final testSizes = [
              {'cols': 80, 'rows': 24},
              {'cols': 120, 'rows': 40},
              {'cols': 100, 'rows': 30},
            ];

            for (final size in testSizes) {
              await mockWebSocketService.resizeTerminal(
                size['cols']!,
                size['rows']!,
                sessionId: sessionId,
              );
              
              await Future.delayed(const Duration(milliseconds: 50));
            }

            // Verify resize messages were sent
            expect(resizeMessages.length, equals(testSizes.length));
            
            for (int i = 0; i < testSizes.length; i++) {
              final resizeMessage = resizeMessages[i];
              final expectedSize = testSizes[i];
              
              expect(resizeMessage['type'], equals('terminal_resize'));
              expect(resizeMessage['session_id'], equals(sessionId));
              expect(resizeMessage['cols'], equals(expectedSize['cols']));
              expect(resizeMessage['rows'], equals(expectedSize['rows']));
            }

            await resizeSubscription.cancel();
            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Session Message History', () {
      testWidgets('should maintain accurate message history', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Message history maintenance',
          () async {
            final testProfile = SshProfile(
              id: 'history-test',
              name: 'History Test',
              host: 'history.example.com',
              port: 22,
              username: 'historyuser',
              authType: SshAuthType.password,
              password: 'historypass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send series of commands and track them
            final commandHistory = [
              'pwd',
              'ls -la',
              'echo "test1"',
              'whoami',
              'date',
              'echo "test2"',
            ];

            for (final command in commandHistory) {
              await mockWebSocketService.sendTerminalData(command, sessionId: sessionId);
              await Future.delayed(const Duration(milliseconds: 10));
            }

            // Verify complete message history
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            for (final command in commandHistory) {
              expect(sessionMessages, contains(command));
            }

            // Verify message count
            final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            expect(sessionInfo['message_count'], equals(commandHistory.length));

            await mockWebSocketService.closeTerminalSession(sessionId);
            
            // History should be cleared after session close
            final closedSessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            expect(closedSessionMessages, isEmpty);
          },
        );
      });
    });
  });
}