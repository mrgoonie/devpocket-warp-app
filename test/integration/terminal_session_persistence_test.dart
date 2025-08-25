import 'package:flutter_test/flutter_test.dart';

import 'package:devpocket_warp_app/models/ssh_profile_models.dart';
import '../helpers/test_helpers.dart';
import '../helpers/stability_helpers.dart';
import '../mocks/mock_websocket_service.dart';
import '../mocks/websocket_state_manager.dart';

/// Integration tests for Terminal Session Persistence
/// Tests session lifecycle, state management, concurrency, and cleanup
void main() {
  setUpAll(() {
    TestHelpers.initializeTestEnvironment();
  });

  group('Terminal Session Persistence Tests', () {
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

    group('Session Creation and Management', () {
      testWidgets('should create and track terminal sessions', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session creation and tracking',
          () async {
            final testProfile = SshProfile(
              id: 'session-create-test',
              name: 'Session Create Test',
              host: 'create.example.com',
              port: 22,
              username: 'createuser',
              authType: SshAuthType.password,
              password: 'createpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            // Initially no sessions
            expect(mockWebSocketService.activeSessionCount, equals(0));
            expect(mockWebSocketService.getActiveSessions(), isEmpty);

            // Establish connection
            await mockWebSocketService.connect();
            expect(mockWebSocketService.isConnected, isTrue);

            // Create session
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);
            expect(sessionId, isNotNull);
            expect(sessionId.length, greaterThan(0));

            // Verify session tracking
            expect(mockWebSocketService.activeSessionCount, equals(1));
            expect(mockWebSocketService.getActiveSessions(), contains(sessionId));

            // Verify session info
            final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            expect(sessionInfo['session_id'], equals(sessionId));
            expect(sessionInfo['is_active'], isTrue);
            expect(sessionInfo['profile'], isNotNull);

            // Clean up
            await mockWebSocketService.closeTerminalSession(sessionId);
            expect(mockWebSocketService.activeSessionCount, equals(0));
          },
        );
      });

      testWidgets('should handle multiple concurrent sessions', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Multiple concurrent sessions',
          () async {
            const sessionCount = 5;
            final testProfiles = List.generate(sessionCount, (index) => SshProfile(
              id: 'concurrent-session-$index',
              name: 'Concurrent Session $index',
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
            for (final profile in testProfiles) {
              final sessionId = await mockWebSocketService.createTerminalSession(profile);
              sessionIds.add(sessionId);
              expect(sessionId, isNotNull);
            }

            // Verify all sessions are tracked
            expect(mockWebSocketService.activeSessionCount, equals(sessionCount));
            expect(mockWebSocketService.getActiveSessions().length, equals(sessionCount));

            // Verify each session
            for (final sessionId in sessionIds) {
              expect(mockWebSocketService.getActiveSessions(), contains(sessionId));
              final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
              expect(sessionInfo['is_active'], isTrue);
            }

            // Test operations on each session
            for (int i = 0; i < sessionIds.length; i++) {
              await mockWebSocketService.sendTerminalData(
                'echo "test from session $i"',
                sessionId: sessionIds[i],
              );
            }

            // Clean up all sessions
            for (final sessionId in sessionIds) {
              await mockWebSocketService.closeTerminalSession(sessionId);
            }

            expect(mockWebSocketService.activeSessionCount, equals(0));
          },
        );
      });
    });

    group('Session State Persistence', () {
      testWidgets('should maintain session state across operations', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session state persistence',
          () async {
            final testProfile = SshProfile(
              id: 'state-persist-test',
              name: 'State Persist Test',
              host: 'persist.example.com',
              port: 22,
              username: 'persistuser',
              authType: SshAuthType.password,
              password: 'persistpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Perform various operations and verify state persistence
            final operations = [
              'pwd',
              'ls -la',
              'echo "state test 1"',
              'whoami',
              'date',
              'echo "state test 2"',
            ];

            for (int i = 0; i < operations.length; i++) {
              await mockWebSocketService.sendTerminalData(operations[i], sessionId: sessionId);
              
              // Verify session is still active after each operation
              expect(mockWebSocketService.getActiveSessions(), contains(sessionId));
              
              final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
              expect(sessionInfo['is_active'], isTrue);
              expect(sessionInfo['message_count'], equals(i + 1));
            }

            // Verify complete command history is maintained
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            for (final operation in operations) {
              expect(sessionMessages, contains(operation));
            }

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });

      testWidgets('should handle session state during connection interruption', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session state during interruption',
          () async {
            final testProfile = SshProfile(
              id: 'interruption-test',
              name: 'Interruption Test',
              host: 'interruption.example.com',
              port: 22,
              username: 'interruptuser',
              authType: SshAuthType.password,
              password: 'interruptpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Send some commands before interruption
            await mockWebSocketService.sendTerminalData('echo "before interruption"', sessionId: sessionId);
            final preInterruptMessages = mockWebSocketService.getSessionMessages(sessionId);
            expect(preInterruptMessages, contains('echo "before interruption"'));

            // Simulate network interruption
            await mockWebSocketService.simulateNetworkInterruption(
              duration: const Duration(milliseconds: 300),
            );

            // Verify session state after reconnection
            expect(mockWebSocketService.isConnected, isTrue);
            
            // Session should either be restored or gracefully handled
            final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            if (sessionInfo['is_active'] == true) {
              // If session persisted, verify it's still functional
              await mockWebSocketService.sendTerminalData('echo "after interruption"', sessionId: sessionId);
              final postInterruptMessages = mockWebSocketService.getSessionMessages(sessionId);
              expect(postInterruptMessages, contains('echo "after interruption"'));
            }

            // Clean up (may need to handle the case where session was terminated)
            try {
              await mockWebSocketService.closeTerminalSession(sessionId);
            } catch (e) {
              // Session might have been automatically cleaned up during interruption
              expect(e.toString(), contains('not found'));
            }
          },
        );
      });
    });

    group('Session Lifecycle Management', () {
      testWidgets('should manage complete session lifecycle', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Complete session lifecycle',
          () async {
            final testProfile = SshProfile(
              id: 'lifecycle-test',
              name: 'Lifecycle Test',
              host: 'lifecycle.example.com',
              port: 22,
              username: 'lifecycleuser',
              authType: SshAuthType.password,
              password: 'lifecyclepass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();

            // Phase 1: Session Creation
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);
            expect(sessionId, isNotNull);
            expect(mockWebSocketService.activeSessionCount, equals(1));

            // Phase 2: Active Usage
            final commands = ['pwd', 'ls', 'whoami', 'echo "lifecycle test"'];
            for (final command in commands) {
              await mockWebSocketService.sendTerminalData(command, sessionId: sessionId);
            }

            // Verify session is actively processing commands
            final sessionMessages = mockWebSocketService.getSessionMessages(sessionId);
            expect(sessionMessages.length, equals(commands.length));

            // Phase 3: Session Control Operations
            await mockWebSocketService.sendTerminalControl('clear', sessionId: sessionId);
            await mockWebSocketService.resizeTerminal(100, 30, sessionId: sessionId);

            // Session should still be active after control operations
            final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            expect(sessionInfo['is_active'], isTrue);

            // Phase 4: Session Termination
            await mockWebSocketService.closeTerminalSession(sessionId);
            expect(mockWebSocketService.activeSessionCount, equals(0));
            expect(mockWebSocketService.getActiveSessions(), isEmpty);

            // Verify session cleanup
            final closedSessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            expect(closedSessionInfo['is_active'], isFalse);
          },
        );
      });

      testWidgets('should handle session cleanup on disconnection', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session cleanup on disconnection',
          () async {
            final testProfile = SshProfile(
              id: 'cleanup-test',
              name: 'Cleanup Test',
              host: 'cleanup.example.com',
              port: 22,
              username: 'cleanupuser',
              authType: SshAuthType.password,
              password: 'cleanuppass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();

            // Create multiple sessions
            final sessionIds = <String>[];
            for (int i = 0; i < 3; i++) {
              final profile = testProfile.copyWith(id: 'cleanup-session-$i');
              final sessionId = await mockWebSocketService.createTerminalSession(profile);
              sessionIds.add(sessionId);
            }

            expect(mockWebSocketService.activeSessionCount, equals(3));

            // Disconnect WebSocket (should clean up all sessions)
            await mockWebSocketService.disconnect();
            expect(mockWebSocketService.isConnected, isFalse);
            expect(mockWebSocketService.activeSessionCount, equals(0));

            // Verify all sessions were cleaned up
            for (final sessionId in sessionIds) {
              expect(mockWebSocketService.getActiveSessions(), isNot(contains(sessionId)));
            }
          },
        );
      });
    });

    group('Session Isolation and Security', () {
      testWidgets('should isolate sessions from each other', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session isolation',
          () async {
            final profile1 = SshProfile(
              id: 'isolation-test-1',
              name: 'Isolation Test 1',
              host: 'isolation1.example.com',
              port: 22,
              username: 'user1',
              authType: SshAuthType.password,
              password: 'pass1',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            final profile2 = SshProfile(
              id: 'isolation-test-2',
              name: 'Isolation Test 2',
              host: 'isolation2.example.com',
              port: 22,
              username: 'user2',
              authType: SshAuthType.password,
              password: 'pass2',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();

            // Create two separate sessions
            final sessionId1 = await mockWebSocketService.createTerminalSession(profile1);
            final sessionId2 = await mockWebSocketService.createTerminalSession(profile2);

            // Send different commands to each session
            await mockWebSocketService.sendTerminalData('echo "session1 command"', sessionId: sessionId1);
            await mockWebSocketService.sendTerminalData('echo "session2 command"', sessionId: sessionId2);

            // Verify session isolation
            final session1Messages = mockWebSocketService.getSessionMessages(sessionId1);
            final session2Messages = mockWebSocketService.getSessionMessages(sessionId2);

            expect(session1Messages, contains('echo "session1 command"'));
            expect(session1Messages, isNot(contains('echo "session2 command"')));

            expect(session2Messages, contains('echo "session2 command"'));
            expect(session2Messages, isNot(contains('echo "session1 command"')));

            // Verify session info isolation
            final session1Info = mockWebSocketService.getSessionInfo(sessionId1);
            final session2Info = mockWebSocketService.getSessionInfo(sessionId2);

            expect(session1Info['profile']['username'], equals('user1'));
            expect(session2Info['profile']['username'], equals('user2'));

            // Clean up
            await mockWebSocketService.closeTerminalSession(sessionId1);
            await mockWebSocketService.closeTerminalSession(sessionId2);
          },
        );
      });

      testWidgets('should validate session authentication', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session authentication validation',
          () async {
            final testProfile = SshProfile(
              id: 'auth-test',
              name: 'Auth Test',
              host: 'auth.example.com',
              port: 22,
              username: 'authuser',
              authType: SshAuthType.password,
              password: 'authpass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Verify session was created with correct authentication info
            final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
            final profileInfo = sessionInfo['profile'];

            expect(profileInfo['username'], equals('authuser'));
            expect(profileInfo['host'], equals('auth.example.com'));
            expect(profileInfo['port'], equals(22));

            // Session should be active and authenticated
            expect(sessionInfo['is_active'], isTrue);

            await mockWebSocketService.closeTerminalSession(sessionId);
          },
        );
      });
    });

    group('Session Performance and Resource Management', () {
      testWidgets('should handle session creation performance', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session creation performance',
          () async {
            await mockWebSocketService.connect();

            final stopwatch = Stopwatch()..start();
            final sessionCreationTimes = <Duration>[];

            // Create multiple sessions and measure creation time
            for (int i = 0; i < 10; i++) {
              final profile = SshProfile(
                id: 'perf-test-$i',
                name: 'Performance Test $i',
                host: 'perf$i.example.com',
                port: 22,
                username: 'perfuser$i',
                authType: SshAuthType.password,
                password: 'perfpass$i',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              final startTime = stopwatch.elapsedMilliseconds;
              final sessionId = await mockWebSocketService.createTerminalSession(profile);
              final endTime = stopwatch.elapsedMilliseconds;

              sessionCreationTimes.add(Duration(milliseconds: endTime - startTime));
              expect(sessionId, isNotNull);
            }

            stopwatch.stop();

            // Verify performance metrics
            final averageCreationTime = sessionCreationTimes.fold<int>(
              0,
              (sum, duration) => sum + duration.inMilliseconds,
            ) / sessionCreationTimes.length;

            // Session creation should be reasonably fast (under 500ms each)
            expect(averageCreationTime, lessThan(500));

            // Clean up all sessions
            final activeSessions = mockWebSocketService.getActiveSessions();
            for (final sessionId in activeSessions) {
              await mockWebSocketService.closeTerminalSession(sessionId);
            }
          },
        );
      });

      testWidgets('should manage session memory usage', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session memory management',
          () async {
            await mockWebSocketService.connect();

            // Create sessions with message history
            final sessionIds = <String>[];
            for (int i = 0; i < 5; i++) {
              final profile = SshProfile(
                id: 'memory-test-$i',
                name: 'Memory Test $i',
                host: 'memory$i.example.com',
                port: 22,
                username: 'memoryuser$i',
                authType: SshAuthType.password,
                password: 'memorypass$i',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              final sessionId = await mockWebSocketService.createTerminalSession(profile);
              sessionIds.add(sessionId);

              // Generate message history
              for (int j = 0; j < 20; j++) {
                await mockWebSocketService.sendTerminalData('echo "message $j"', sessionId: sessionId);
              }
            }

            // Verify sessions are tracking messages
            for (final sessionId in sessionIds) {
              final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
              expect(sessionInfo['message_count'], equals(20));
            }

            // Close sessions and verify memory cleanup
            for (final sessionId in sessionIds) {
              await mockWebSocketService.closeTerminalSession(sessionId);
              
              // Messages should be cleared after session close
              final messages = mockWebSocketService.getSessionMessages(sessionId);
              expect(messages, isEmpty);
            }

            expect(mockWebSocketService.activeSessionCount, equals(0));
          },
        );
      });
    });

    group('Session Recovery and Resilience', () {
      testWidgets('should handle session recovery scenarios', (WidgetTester tester) async {
        await StabilityHelpers.runWebSocketTest(
          'Session recovery scenarios',
          () async {
            final testProfile = SshProfile(
              id: 'recovery-test',
              name: 'Recovery Test',
              host: 'recovery.example.com',
              port: 22,
              username: 'recoveryuser',
              authType: SshAuthType.password,
              password: 'recoverypass',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );

            await mockWebSocketService.connect();
            final sessionId = await mockWebSocketService.createTerminalSession(testProfile);

            // Establish session state
            await mockWebSocketService.sendTerminalData('echo "initial state"', sessionId: sessionId);
            
            // Force connection error
            mockWebSocketService.forceConnectionError();
            expect(mockWebSocketService.isConnected, isFalse);

            // Attempt to reconnect and handle session recovery
            await mockWebSocketService.connect();
            expect(mockWebSocketService.isConnected, isTrue);

            // Try to use the session (it may need to be recreated)
            bool sessionStillActive = false;
            try {
              await mockWebSocketService.sendTerminalData('echo "after recovery"', sessionId: sessionId);
              sessionStillActive = true;
            } catch (e) {
              // Session may have been invalidated, which is acceptable
              expect(e.toString(), contains('not found'));
            }

            // If session is still active, verify it works
            if (sessionStillActive) {
              final sessionInfo = mockWebSocketService.getSessionInfo(sessionId);
              expect(sessionInfo['is_active'], isTrue);
              await mockWebSocketService.closeTerminalSession(sessionId);
            }
          },
        );
      });
    });
  });
}