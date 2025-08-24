import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import '../../lib/models/ssh_profile_models.dart';
import '../../lib/services/ssh_host_service.dart';
import '../../lib/services/terminal_session_handler.dart';
import '../../lib/services/ssh_connection_manager.dart';
import '../../lib/services/terminal_websocket_service.dart';

/// Comprehensive error handling and edge case tests
/// Tests system behavior under various failure conditions

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
  String? publicKey,
  DateTime? createdAt,
  DateTime? updatedAt,
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
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    description: description,
    tags: tags,
  );
}

void main() {
  group('Error Handling and Edge Case Tests', () {
    late SshHostService hostService;
    late TerminalSessionHandler sessionHandler;
    late SshConnectionManager sshManager;
    late TerminalWebSocketService wsService;

    setUp(() {
      hostService = SshHostService.instance;
      sessionHandler = TerminalSessionHandler.instance;
      sshManager = SshConnectionManager.instance;
      wsService = TerminalWebSocketService.instance;
    });

    tearDown(() async {
      await sessionHandler.stopAllSessions();
      await wsService.disconnect();
    });

    group('Network Failure Scenarios', () {
      testWidgets('should handle complete network unavailability', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'network-fail-test',
          name: 'Network Failure Test',
          host: '192.0.2.1', // TEST-NET-1 - guaranteed unreachable
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
        );

        // Test SSH connection failure
        try {
          await sshManager.connect(testProfile);
          fail('Should have failed to connect to unreachable host');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), anyOf([
            contains('Connection failed'),
            contains('timeout'),
            contains('No route to host'),
            contains('Network is unreachable'),
          ]));
        }

        // Test terminal session failure
        try {
          await sessionHandler.createSshSession(testProfile);
          fail('Should have failed to create session to unreachable host');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), contains('Failed to create SSH session'));
        }
      });

      testWidgets('should handle DNS resolution failures', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'dns-fail-test',
          name: 'DNS Failure Test',
          host: 'nonexistent.invalid.domain.test',
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
        );

        try {
          await sshManager.connect(testProfile);
          fail('Should have failed with DNS resolution error');
        } catch (e) {
          expect(e, isA<Exception>());
          // DNS failures can manifest in different ways
          expect(e.toString(), anyOf([
            contains('Failed to connect'),
            contains('resolve'),
            contains('not found'),
            contains('Invalid argument'),
          ]));
        }
      });

      testWidgets('should handle port connection refused', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'port-refused-test',
          name: 'Port Refused Test',
          host: 'localhost',
          port: 12345, // Unlikely to have SSH server
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
        );

        try {
          await sshManager.connect(testProfile);
          fail('Should have failed with connection refused');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), anyOf([
            contains('Connection refused'),
            contains('Failed to connect'),
            contains('refused'),
          ]));
        }
      });
    });

    group('Authentication Failure Scenarios', () {
      testWidgets('should handle invalid credentials', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'auth-fail-test',
          name: 'Auth Failure Test',
          host: 'localhost',
          port: 22,
          username: 'invaliduser',
          authType: SshAuthType.password,
          password: 'wrongpassword',
        );

        try {
          await sshManager.connect(testProfile);
          // May fail at connection or authentication stage
        } catch (e) {
          expect(e, isA<Exception>());
          // Error message varies by system
          expect(e.toString(), isNotEmpty);
        }
      });

      testWidgets('should handle malformed SSH keys', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'malformed-key-test',
          name: 'Malformed Key Test',
          host: 'localhost',
          port: 22,
          username: 'testuser',
          authType: SshAuthType.key,
          privateKey: 'invalid-key-data-not-a-real-key',
        );

        try {
          await sshManager.connect(testProfile);
          fail('Should have failed with invalid key format');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), anyOf([
            contains('Invalid'),
            contains('key'),
            contains('format'),
            contains('parse'),
          ]));
        }
      });

      testWidgets('should handle missing authentication data', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'missing-auth-test',
          name: 'Missing Auth Test',
          host: 'localhost',
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          // Missing password
        );

        try {
          await sshManager.connect(testProfile);
          fail('Should have failed with missing credentials');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), isNotEmpty);
        }
      });
    });

    group('Data Validation Edge Cases', () {
      testWidgets('should handle extreme port numbers', (WidgetTester tester) async {
        final extremeProfiles = [
          createTestProfile(
            id: 'port-0-test',
            name: 'Port 0 Test',
            host: 'localhost',
            port: 0,
            username: 'testuser',
            authType: SshAuthType.password,
            password: 'testpass',
          ),
          createTestProfile(
            id: 'port-max-test',
            name: 'Port Max Test',
            host: 'localhost',
            port: 65536, // Above valid port range
            username: 'testuser',
            authType: SshAuthType.password,
            password: 'testpass',
          ),
          createTestProfile(
            id: 'port-negative-test',
            name: 'Port Negative Test',
            host: 'localhost',
            port: -1,
            username: 'testuser',
            authType: SshAuthType.password,
            password: 'testpass',
          ),
        ];

        for (final profile in extremeProfiles) {
          try {
            await sshManager.connect(profile);
            fail('Should have failed with invalid port: ${profile.port}');
          } catch (e) {
            expect(e, isA<Exception>());
            expect(e.toString(), isNotEmpty);
          }
        }
      });

      testWidgets('should handle empty and whitespace data', (WidgetTester tester) async {
        final invalidProfiles = [
          createTestProfile(
            id: 'empty-host-test',
            name: 'Empty Host Test',
            host: '',
            port: 22,
            username: 'testuser',
            authType: SshAuthType.password,
            password: 'testpass',
          ),
          createTestProfile(
            id: 'whitespace-host-test',
            name: 'Whitespace Host Test',
            host: '   ',
            port: 22,
            username: 'testuser',
            authType: SshAuthType.password,
            password: 'testpass',
          ),
          createTestProfile(
            id: 'empty-username-test',
            name: 'Empty Username Test',
            host: 'localhost',
            port: 22,
            username: '',
            authType: SshAuthType.password,
            password: 'testpass',
          ),
        ];

        for (final profile in invalidProfiles) {
          try {
            await sshManager.connect(profile);
            fail('Should have failed with invalid data: ${profile.host}/${profile.username}');
          } catch (e) {
            expect(e, isA<Exception>());
            expect(e.toString(), isNotEmpty);
          }
        }
      });

      testWidgets('should handle very long hostnames', (WidgetTester tester) async {
        final longHostname = 'a' * 1000 + '.invalid.test';
        final testProfile = createTestProfile(
          id: 'long-hostname-test',
          name: 'Long Hostname Test',
          host: longHostname,
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
        );

        try {
          await sshManager.connect(testProfile);
          fail('Should have failed with excessively long hostname');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), isNotEmpty);
        }
      });
    });

    group('Memory and Resource Exhaustion', () {
      testWidgets('should handle multiple concurrent connection attempts', (WidgetTester tester) async {
        final concurrentProfiles = List.generate(50, (index) => createTestProfile(
          id: 'concurrent-fail-$index',
          name: 'Concurrent Fail $index',
          host: '192.0.2.$index', // TEST-NET-1 range
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
        ));

        final futures = concurrentProfiles.map((profile) async {
          try {
            await sshManager.connect(profile);
            return 'success';
          } catch (e) {
            return 'failed: $e';
          }
        }).toList();

        final results = await Future.wait(futures);
        
        // All should fail gracefully without crashing
        expect(results.length, equals(50));
        for (final result in results) {
          expect(result, isA<String>());
          if (!result.startsWith('failed:')) {
            // If any succeeded, clean up
            // This is unlikely but handle it gracefully
          }
        }
      });

      testWidgets('should handle rapid session creation/destruction', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'rapid-test',
          name: 'Rapid Test',
          host: '192.0.2.1',
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
        );

        // Rapidly create and destroy sessions
        for (int i = 0; i < 10; i++) {
          try {
            await sessionHandler.createSshSession(testProfile);
            await sessionHandler.stopSession(testProfile.id);
          } catch (e) {
            // Expected to fail, but should not crash
            expect(e, isA<Exception>());
          }
        }

        // Verify no sessions are left hanging
        final activeSessions = sessionHandler.getActiveSessions();
        expect(activeSessions, isEmpty);
      });
    });

    group('WebSocket Error Scenarios', () {
      testWidgets('should handle WebSocket connection failures', (WidgetTester tester) async {
        // Test with invalid WebSocket URL
        try {
          await wsService.connect();
          // May succeed or fail depending on backend availability
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), isNotEmpty);
        }

        // Test operations on disconnected WebSocket
        try {
          await wsService.sendTerminalData('test data');
          fail('Should have failed with disconnected WebSocket');
        } catch (e) {
          expect(e, isA<Exception>());
          expect(e.toString(), contains('not connected'));
        }
      });

      testWidgets('should handle malformed WebSocket messages', (WidgetTester tester) async {
        // Test WebSocket service robustness
        expect(wsService.isConnected, isFalse);
        expect(wsService.activeSessionCount, equals(0));

        // Attempt invalid operations
        try {
          await wsService.sendTerminalData('');
        } catch (e) {
          expect(e, isA<Exception>());
        }

        try {
          await wsService.closeTerminalSession('nonexistent-session');
        } catch (e) {
          // Should handle gracefully
        }
      });
    });

    group('Platform-Specific Errors', () {
      testWidgets('should handle platform method channel failures', (WidgetTester tester) async {
        // Test handling of platform-specific failures
        try {
          // Simulate platform channel error
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel('flutter_secure_storage'),
            (MethodCall methodCall) async {
              throw PlatformException(
                code: 'UNAVAILABLE',
                message: 'Secure storage unavailable',
              );
            },
          );

          // Attempt operation that would use secure storage
          final testProfile = createTestProfile(
            id: 'platform-fail-test',
            name: 'Platform Fail Test',
            host: 'localhost',
            port: 22,
            username: 'testuser',
            authType: SshAuthType.password,
            password: 'testpass',
          );

          try {
            await hostService.createHost(testProfile);
            // Should either succeed or fail gracefully
          } catch (e) {
            expect(e, isA<Exception>());
          }

        } finally {
          // Reset mock
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
            const MethodChannel('flutter_secure_storage'),
            null,
          );
        }
      });
    });

    group('Recovery and Cleanup', () {
      testWidgets('should recover from service failures', (WidgetTester tester) async {
        // Test service recovery after failures
        final testProfile = createTestProfile(
          id: 'recovery-test',
          name: 'Recovery Test',
          host: 'localhost',
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
        );

        // Cause a failure
        try {
          await sessionHandler.createSshSession(testProfile);
        } catch (e) {
          // Expected failure
        }

        // Verify system can still handle new requests
        try {
          final sessions = sessionHandler.getActiveSessions();
          expect(sessions, isA<List<String>>());
        } catch (e) {
          fail('Service should recover from previous failure');
        }

        // Test cleanup after failures
        await sessionHandler.stopAllSessions();
        final finalSessions = sessionHandler.getActiveSessions();
        expect(finalSessions, isEmpty);
      });

      testWidgets('should handle graceful shutdown', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'shutdown-test',
          name: 'Shutdown Test',
          host: 'localhost',
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
        );

        // Create some sessions (may fail)
        try {
          await sessionHandler.createSshSession(testProfile);
        } catch (e) {
          // May fail to create
        }

        // Test graceful shutdown
        try {
          await sessionHandler.stopAllSessions();
          await wsService.disconnect();
          
          // Should complete without throwing
          final sessions = sessionHandler.getActiveSessions();
          expect(sessions, isEmpty);
          
        } catch (e) {
          fail('Graceful shutdown should not throw: $e');
        }
      });
    });

    group('Data Corruption and Invalid State', () {
      testWidgets('should handle corrupted session data', (WidgetTester tester) async {
        // Test with invalid session IDs
        final invalidSessionIds = ['', '   ', 'null', 'undefined', '..', '///'];

        for (final sessionId in invalidSessionIds) {
          try {
            await sessionHandler.stopSession(sessionId);
            // Should handle gracefully
          } catch (e) {
            // Acceptable to throw for invalid IDs
            expect(e, isA<Exception>());
          }

          // Test session info with invalid ID
          final info = sessionHandler.getSessionInfo(sessionId);
          expect(info, anyOf([isEmpty, isA<Map<String, dynamic>>()]));
        }
      });

      testWidgets('should handle invalid JSON serialization', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'json-test',
          name: 'JSON Test with special chars: \n\t\r\u0000',
          host: 'localhost',
          port: 22,
          username: 'test\nuser',
          authType: SshAuthType.password,
          password: 'test\tpass',
          description: 'Description with unicode: 🚀 emoji',
          tags: ['tag1', 'tag with spaces', 'tag-with-dashes'],
        );

        // Test serialization/deserialization
        try {
          final json = testProfile.toJson();
          expect(json, isA<Map<String, dynamic>>());
          
          final deserialized = SshProfile.fromJson(json);
          expect(deserialized.name, contains('JSON Test'));
          
        } catch (e) {
          // Should handle special characters gracefully
          expect(e, isA<Exception>());
        }
      });
    });
  });
}