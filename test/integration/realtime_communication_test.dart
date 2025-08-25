import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';

import 'package:devpocket_warp_app/models/ssh_profile_models.dart';
import '../helpers/test_helpers.dart';
import '../helpers/stability_helpers.dart';
import '../mocks/mock_websocket_service.dart';
import '../mocks/websocket_state_manager.dart';

/// Integration tests for Real-time Communication Validation
/// Tests bidirectional communication, latency, throughput, and concurrent operations
void main() {
  setUpAll(() {
    TestHelpers.initializeTestEnvironment();
  });

  group('Real-time Communication Validation Tests', () {
    late MockWebSocketService mockWebSocketService;
    late WebSocketStateManager stateManager;

    setUp(() {
      mockWebSocketService = MockWebSocketServiceFactory.createRealistic();
      stateManager = WebSocketStateManagerFactory.createRealistic();
    });

    tearDown(() async {
      await mockWebSocketService.disconnect();
      mockWebSocketService.dispose();
      stateManager.dispose();
      await StabilityHelpers.cleanupTestEnvironment();
    });

    group('Bidirectional Communication', () {
      testWidgets('should handle bidirectional message flow', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Bidirectional message flow',
          () async {
            final testProfile = SshProfile(
              id: 'bidirectional-test',
              name: 'Bidirectional Test',
              host: 'bidirectional.example.com',
              port: 22,
              username: 'bidiruser',
              authType: SshAuthType.password,
              password: 'bidirpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Track all incoming messages
            final incomingMessages = <Map<String, dynamic>>[];
            late StreamSubscription messageSubscription;

            messageSubscription = mockWebSocketService.messages.listen((message) {
              try {
                final decoded = jsonDecode(message);
                incomingMessages.add(decoded);
              } catch (e) {
                // Ignore non-JSON messages
              }
            });

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send client-to-server messages
            final clientMessages = [
              'pwd',
              'ls -la',
              'echo "client message 1"',
              'whoami',
              'echo "client message 2"',
            ];

            for (final message in clientMessages) {
              await mockWebSocketService.sendTerminalData(message, sessionId: sessionId);
              
              // Small delay to allow message processing
              await Future.delayed(const Duration(milliseconds: 50));
            }

            // Verify client messages were sent
            final sentMessages = incomingMessages
                .where((msg) => msg['type'] == 'terminal_input' && msg['session_id'] == sessionId)
                .toList();

            expect(sentMessages.length, equals(clientMessages.length));

            for (int i = 0; i < clientMessages.length; i++) {
              expect(sentMessages[i]['data'], equals(clientMessages[i]));
            }

            // Verify server responses (terminal output) were received
            final serverResponses = incomingMessages
                .where((msg) => msg['type'] == 'terminal_output' && msg['session_id'] == sessionId)
                .toList();

            expect(serverResponses.length, greaterThan(0));

            await messageSubscription.cancel();
            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should maintain message ordering in bidirectional flow', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Bidirectional message ordering',
          () async {
            final testProfile = SshProfile(
              id: 'ordering-test',
              name: 'Ordering Test',
              host: 'ordering.example.com',
              port: 22,
              username: 'orderuser',
              authType: SshAuthType.password,
              password: 'orderpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final messageFlow = <Map<String, dynamic>>[];
            late StreamSubscription flowSubscription;

            flowSubscription = mockWebSocketService.messages.listen((message) {
              try {
                final decoded = jsonDecode(message);
                decoded['received_at'] = DateTime.now().toIso8601String();
                messageFlow.add(decoded);
              } catch (e) {
                // Ignore non-JSON messages
              }
            });

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send interleaved commands with different types
            await mockWebSocketService.sendTerminalData('echo "command 1"', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 30));

            await mockWebSocketService.sendTerminalControl('clear', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 30));

            await mockWebSocketService.sendTerminalData('echo "command 2"', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 30));

            await mockWebSocketService.resizeTerminal(100, 30, sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 30));

            await mockWebSocketService.sendTerminalData('echo "command 3"', sessionId: sessionId);

            // Allow time for all messages to be processed
            await Future.delayed(const Duration(milliseconds: 200));

            // Verify message types were received in correct categories
            final inputMessages = messageFlow.where((msg) => msg['type'] == 'terminal_input').toList();
            final controlMessages = messageFlow.where((msg) => msg['type'] == 'terminal_control').toList();
            final resizeMessages = messageFlow.where((msg) => msg['type'] == 'terminal_resize').toList();

            expect(inputMessages.length, equals(3));
            expect(controlMessages.length, equals(1));
            expect(resizeMessages.length, equals(1));

            // Verify input message ordering
            expect(inputMessages[0]['data'], equals('echo "command 1"'));
            expect(inputMessages[1]['data'], equals('echo "command 2"'));
            expect(inputMessages[2]['data'], equals('echo "command 3"'));

            await flowSubscription.cancel();
            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Real-time Latency and Performance', () {
      testWidgets('should measure message round-trip latency', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Message latency measurement',
          () async {
            final testProfile = SshProfile(
              id: 'latency-test',
              name: 'Latency Test',
              host: 'latency.example.com',
              port: 22,
              username: 'latencyuser',
              authType: SshAuthType.password,
              password: 'latencypass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final latencies = <Duration>[];
            final messageTimestamps = <String, DateTime>{};
            late StreamSubscription latencySubscription;

            latencySubscription = mockWebSocketService.messages.listen((message) {
              try {
                final decoded = jsonDecode(message);
                if (decoded['type'] == 'terminal_output') {
                  final receivedAt = DateTime.now();
                  final data = decoded['data'] as String;
                  
                  // Look for echo responses to calculate round-trip time
                  if (data.contains('latency_test_')) {
                    final messageId = data.split('latency_test_')[1].split('\n')[0];
                    final sentAt = messageTimestamps[messageId];
                    if (sentAt != null) {
                      latencies.add(receivedAt.difference(sentAt));
                    }
                  }
                }
              } catch (e) {
                // Ignore non-JSON messages
              }
            });

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send timestamped echo commands to measure latency
            for (int i = 0; i < 10; i++) {
              final messageId = 'msg_$i';
              final timestamp = DateTime.now();
              messageTimestamps[messageId] = timestamp;
              
              await mockWebSocketService.sendTerminalData(
                'echo "latency_test_$messageId"',
                sessionId: sessionId,
              );
              
              // Small delay between messages
              await Future.delayed(const Duration(milliseconds: 100));
            }

            // Wait for all responses
            await Future.delayed(const Duration(milliseconds: 1000));

            // Analyze latency metrics
            if (latencies.isNotEmpty) {
              final avgLatency = latencies.fold<int>(
                0,
                (sum, latency) => sum + latency.inMilliseconds,
              ) / latencies.length;

              final maxLatency = latencies.map((l) => l.inMilliseconds).reduce((a, b) => a > b ? a : b);
              final minLatency = latencies.map((l) => l.inMilliseconds).reduce((a, b) => a < b ? a : b);

              print('Latency metrics: avg=${avgLatency}ms, min=${minLatency}ms, max=${maxLatency}ms');

              // Verify latency is within reasonable bounds (should be fast for mock service)
              expect(avgLatency, lessThan(1000)); // Less than 1 second average
              expect(maxLatency, lessThan(2000)); // Less than 2 seconds max
            }

            await latencySubscription.cancel();
            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should handle high-frequency message transmission', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'High-frequency message handling',
          () async {
            final testProfile = SshProfile(
              id: 'frequency-test',
              name: 'Frequency Test',
              host: 'frequency.example.com',
              port: 22,
              username: 'frequser',
              authType: SshAuthType.password,
              password: 'freqpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            final startTime = DateTime.now();
            const messageCount = 100;

            // Send high-frequency messages
            final sendFutures = <Future<void>>[];
            for (int i = 0; i < messageCount; i++) {
              sendFutures.add(
                mockWebSocketService.sendTerminalData('echo "msg_$i"', sessionId: sessionId)
              );
            }

            await Future.wait(sendFutures);
            final sendDuration = DateTime.now().difference(startTime);

            // Calculate throughput
            final messagesPerSecond = messageCount / sendDuration.inMilliseconds * 1000;
            print('Message throughput: ${messagesPerSecond.toStringAsFixed(1)} messages/second');

            // Verify all messages were handled
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            expect(sessionMessages.length, equals(messageCount));

            // Verify session is still responsive after high-frequency transmission
            await mockWebSocketService.sendTerminalData('echo "post_burst_test"', sessionId: sessionId);
            expect(sessionMessages, contains('echo "post_burst_test"'));

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Concurrent Operations', () {
      testWidgets('should handle concurrent sessions with real-time communication', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Concurrent sessions real-time communication',
          () async {
            const sessionCount = 3;
            final profiles = List.generate(sessionCount, (index) => SshProfile(
              id: 'concurrent-rt-$index',
              name: 'Concurrent RT $index',
              host: 'concurrent$index.example.com',
              port: 22,
              username: 'user$index',
              authType: SshAuthType.password,
              password: 'pass$index',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ));

            await mockWebSocketService.connect();

            // Create multiple sessions
            final sessionIds = <String>[];
            for (final profile in profiles) {
              final sessionId = await mockWebSocketService.createTerminalSession(profile);
              sessionIds.add(sessionId);
            }

            // Send concurrent messages to all sessions
            final concurrentOperations = <Future<void>>[];
            for (int i = 0; i < sessionIds.length; i++) {
              final sessionId = sessionIds[i];
              
              // Each session sends multiple messages
              for (int j = 0; j < 5; j++) {
                concurrentOperations.add(
                  mockWebSocketService.sendTerminalData(
                    'echo "session_${i}_message_$j"',
                    sessionId: sessionId,
                  )
                );
              }
            }

            // Execute all operations concurrently
            await Future.wait(concurrentOperations);

            // Verify each session received its messages
            for (int i = 0; i < sessionIds.length; i++) {
              final sessionMessages = mockWebSocketService.getSessionMessages(sessionIds[i]);
              
              for (int j = 0; j < 5; j++) {
                expect(sessionMessages, contains('echo "session_${i}_message_$j"'));
              }
              
              // Verify session isolation
              for (int k = 0; k < sessionIds.length; k++) {
                if (k != i) {
                  for (int j = 0; j < 5; j++) {
                    expect(sessionMessages, isNot(contains('echo "session_${k}_message_$j"')));
                  }
                }
              }
            }

            // Clean up all sessions
            for (final sessionId in sessionIds) {
              await mockWebSocketService.closeTerminalSession(sessionId);
            }
          },
        );
      });

      testWidgets('should handle mixed concurrent operations', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Mixed concurrent operations',
          () async {
            final testProfile = SshProfile(
              id: 'mixed-ops-test',
              name: 'Mixed Operations Test',
              host: 'mixed.example.com',
              port: 22,
              username: 'mixeduser',
              authType: SshAuthType.password,
              password: 'mixedpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Execute mixed operations concurrently
            final mixedOperations = <Future<void>>[
              // Data transmission
              mockWebSocketService.sendTerminalData('echo "data 1"', sessionId: sessionId),
              mockWebSocketService.sendTerminalData('echo "data 2"', sessionId: sessionId),
              mockWebSocketService.sendTerminalData('ls -la', sessionId: sessionId),
              
              // Control operations
              mockWebSocketService.sendTerminalControl('clear', sessionId: sessionId),
              
              // Resize operations
              mockWebSocketService.resizeTerminal(80, 24, sessionId: sessionId),
              mockWebSocketService.resizeTerminal(120, 40, sessionId: sessionId),
              
              // More data transmission
              mockWebSocketService.sendTerminalData('pwd', sessionId: sessionId),
              mockWebSocketService.sendTerminalData('whoami', sessionId: sessionId),
            ];

            await Future.wait(mixedOperations);

            // Verify session handled all operation types
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            expect(sessionMessages, contains('echo "data 1"'));
            expect(sessionMessages, contains('echo "data 2"'));
            expect(sessionMessages, contains('ls -la'));
            expect(sessionMessages, contains('pwd'));
            expect(sessionMessages, contains('whoami'));

            // Session should still be active and responsive
            await mockWebSocketService.sendTerminalData('echo "final test"', sessionId: sessionId);
            expect(sessionMessages, contains('echo "final test"'));

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Real-time Event Streaming', () {
      testWidgets('should stream connection events in real-time', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Real-time connection events',
          () async {
            final connectionEvents = <WebSocketConnectionEvent>[];
            late StreamSubscription eventSubscription;

            eventSubscription = mockWebSocketService.connectionEvents.listen((event) {
              connectionEvents.add(event);
            });

            // Test connection lifecycle events
            expect(mockWebSocketService.isConnected, isFalse);

            await mockWebSocketService.connect();
            expect(mockWebSocketService.isConnected, isTrue);

            await Future.delayed(const Duration(milliseconds: 100));

            await mockWebSocketService.disconnect();
            expect(mockWebSocketService.isConnected, isFalse);

            await Future.delayed(const Duration(milliseconds: 100));

            // Verify events were streamed
            expect(connectionEvents, contains(WebSocketConnectionEvent.connecting));
            expect(connectionEvents, contains(WebSocketConnectionEvent.connected));
            expect(connectionEvents, contains(WebSocketConnectionEvent.disconnecting));
            expect(connectionEvents, contains(WebSocketConnectionEvent.disconnected));

            await eventSubscription.cancel();
          },
        );
      });

      testWidgets('should handle real-time error streaming', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Real-time error streaming',
          () async {
            final errorMessages = <String>[];
            late StreamSubscription errorSubscription;

            errorSubscription = mockWebSocketService.errors.listen((error) {
              errorMessages.add(error);
            });

            await mockWebSocketService.connect();

            // Simulate various error conditions
            await mockWebSocketService.simulateNetworkInterruption(
              duration: const Duration(milliseconds: 200),
            );

            mockWebSocketService.forceConnectionError();

            await Future.delayed(const Duration(milliseconds: 300));

            // Verify error messages were streamed
            expect(errorMessages, isNotEmpty);
            expect(errorMessages.any((msg) => msg.contains('interruption') || msg.contains('error')), isTrue);

            await errorSubscription.cancel();
          },
        );
      });
    });

    group('Real-time Terminal Interactions', () {
      testWidgets('should simulate realistic terminal interactions', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Realistic terminal interactions',
          () async {
            final testProfile = SshProfile(
              id: 'realistic-test',
              name: 'Realistic Test',
              host: 'realistic.example.com',
              port: 22,
              username: 'realuser',
              authType: SshAuthType.password,
              password: 'realpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final terminalOutput = <String>[];
            late StreamSubscription outputSubscription;

            outputSubscription = mockWebSocketService.messages.listen((message) {
              try {
                final decoded = jsonDecode(message);
                if (decoded['type'] == 'terminal_output') {
                  terminalOutput.add(decoded['data']);
                }
              } catch (e) {
                // Ignore non-JSON messages
              }
            });

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Simulate realistic terminal workflow
            await mockWebSocketService.sendTerminalData('pwd', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 100));

            await mockWebSocketService.sendTerminalData('ls -la', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 200));

            await mockWebSocketService.sendTerminalData('echo "Hello, World!"', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 100));

            await mockWebSocketService.sendTerminalData('whoami', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 100));

            // Simulate terminal resize during session
            await mockWebSocketService.resizeTerminal(100, 30, sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 50));

            await mockWebSocketService.sendTerminalData('date', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 100));

            // Clear terminal
            await mockWebSocketService.sendTerminalControl('clear', sessionId: sessionId);
            await Future.delayed(const Duration(milliseconds: 50));

            await mockWebSocketService.sendTerminalData('echo "After clear"', sessionId: sessionId);

            // Allow time for all responses
            await Future.delayed(const Duration(milliseconds: 500));

            // Verify terminal output was received
            expect(terminalOutput, isNotEmpty);
            
            // Should contain responses to various commands
            final outputText = terminalOutput.join(' ');
            expect(outputText, contains('user')); // from pwd or whoami
            expect(outputText, contains('Hello, World!')); // from echo
            expect(outputText, contains('After clear')); // from final echo

            await outputSubscription.cancel();
            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should handle interactive command sessions', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Interactive command sessions',
          () async {
            final testProfile = SshProfile(
              id: 'interactive-test',
              name: 'Interactive Test',
              host: 'interactive.example.com',
              port: 22,
              username: 'interactiveuser',
              authType: SshAuthType.password,
              password: 'interactivepass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Simulate interactive command sequence
            const commandSequence = [
              'echo "Starting interactive session"',
              'ls',
              'pwd',
              'echo "Current user:"',
              'whoami',
              'echo "Current time:"',
              'date',
              'echo "Session complete"',
            ];

            for (final command in commandSequence) {
              await mockWebSocketService.sendTerminalData(command, sessionId: sessionId);
              
              // Simulate human typing delay
              await Future.delayed(Duration(milliseconds: 50 + (command.length * 10)));
            }

            // Verify all commands were processed
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            for (final command in commandSequence) {
              expect(sessionMessages, contains(command));
            }

            // Session should remain active throughout the interaction
            final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            expect(sessionInfo['is_active'], isTrue);
            expect(sessionInfo['message_count'], equals(commandSequence.length));

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });
  });
}