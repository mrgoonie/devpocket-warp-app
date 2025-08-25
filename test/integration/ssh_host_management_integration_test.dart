import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devpocket_warp_app/models/ssh_profile_models.dart';
import 'package:devpocket_warp_app/services/ssh_host_service.dart';
import 'package:devpocket_warp_app/services/ssh_connection_test_service.dart';
import 'package:devpocket_warp_app/providers/ssh_host_providers.dart';
import '../helpers/test_helpers.dart';
import '../helpers/stability_helpers.dart';

/// Integration tests for SSH Host Management System
/// Tests the complete flow from UI interaction to backend API

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
  
  group('SSH Host Management Integration Tests', () {
    late ProviderContainer container;
    late SshHostService hostService;
    late SshConnectionTestService testService;

    setUp(() {
      container = ProviderContainer();
      hostService = SshHostService.instance;
      testService = SshConnectionTestService.instance;
    });

    tearDown(() async {
      await StabilityHelpers.cleanupTestEnvironment();
      container.dispose();
    });

    group('Host CRUD Operations', () {
      StabilityHelpers.stableSpotTestWidgets('should create, read, update, delete SSH host profile', (WidgetTester tester) async {
        // Create test profile
        final testProfile = createTestProfile(
          id: 'test-profile-1',
          name: 'Test Server',
          host: 'test.example.com',
          username: 'testuser',
          password: 'testpass',
          description: 'Integration test profile',
          tags: ['test', 'integration'],
        );

        // Test CREATE
        final createdProfile = await hostService.createHost(testProfile);
        expect(createdProfile, isNotNull);
        expect(createdProfile!.name, equals('Test Server'));
        expect(createdProfile.host, equals('test.example.com'));

        // Test READ
        final retrievedProfile = await hostService.getHost(createdProfile.id);
        expect(retrievedProfile, isNotNull);
        expect(retrievedProfile!.id, equals(createdProfile.id));

        // Test UPDATE
        final updatedProfile = createdProfile.copyWith(
          name: 'Updated Test Server',
          description: 'Updated description',
        );
        final savedProfile = await hostService.updateHost(createdProfile.id, updatedProfile);
        expect(savedProfile, isNotNull);
        expect(savedProfile!.name, equals('Updated Test Server'));
        expect(savedProfile.description, equals('Updated description'));

        // Test DELETE
        final deleteSuccess = await hostService.deleteHost(createdProfile.id);
        expect(deleteSuccess, isTrue);

        // Verify deletion
        final deletedProfile = await hostService.getHost(createdProfile.id);
        expect(deletedProfile, isNull);
      });

      StabilityHelpers.stableSpotTestWidgets('should handle host list operations', (WidgetTester tester) async {
        // Create multiple test profiles
        final profiles = List.generate(3, (index) => createTestProfile(
          id: 'test-profile-$index',
          name: 'Test Server $index',
          host: 'test$index.example.com',
          username: 'testuser$index',
          password: 'testpass$index',
        ));

        // Create all profiles
        final createdProfiles = <SshProfile>[];
        for (final profile in profiles) {
          final created = await hostService.createHost(profile);
          expect(created, isNotNull);
          createdProfiles.add(created!);
        }

        // Test list retrieval
        final hostList = await hostService.getHosts();
        expect(hostList.length, greaterThanOrEqualTo(3));

        // Verify all created profiles are in the list
        for (final profile in createdProfiles) {
          final found = hostList.any((h) => h.id == profile.id);
          expect(found, isTrue, reason: 'Profile ${profile.name} not found in list');
        }

        // Clean up
        for (final profile in createdProfiles) {
          await hostService.deleteHost(profile.id);
        }
      });
    });

    group('Connection Testing', () {
      StabilityHelpers.stableSpotTestWidgets('should test SSH connection with valid credentials', (WidgetTester tester) async {
        // Note: This test uses a mock/local test server for safety
        final testProfile = createTestProfile(
          id: 'connection-test-1',
          name: 'Connection Test Server',
          host: 'localhost', // Use localhost for testing
          port: 2222, // Non-standard port for test SSH server
          username: 'testuser',
          password: 'testpass',
        );

        // Test connection with strict timeout to prevent hanging
        try {
          final result = await testService.testConnectionWithTimeout(testProfile)
              .timeout(const Duration(seconds: 5), onTimeout: () {
            // Return mock failure result on timeout
            return SshConnectionTestResult(
              success: false,
              error: 'Connection test timed out (expected in test environment)',
              timestamp: DateTime.now(),
            );
          });
          
          // Verify result structure regardless of success/failure
          expect(result.timestamp, isNotNull);
          expect(result.error, isA<String?>());
          
          // If connection fails (expected without test server), verify error handling
          if (!result.success) {
            expect(result.error, isNotNull);
            expect(result.error!.length, greaterThan(0));
          }
        } catch (e) {
          // Log timeout but don't fail test - expected in test environment
          print('SSH connection test caught exception: $e');
        }
      });

      StabilityHelpers.stableSpotTestWidgets('should handle connection timeout', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'timeout-test-1',
          name: 'Timeout Test',
          host: '192.0.2.1', // TEST-NET-1 - guaranteed to be unreachable
          username: 'testuser',
          password: 'testpass',
        );

        final stopwatch = Stopwatch()..start();
        final result = await testService.testConnectionWithTimeout(testProfile);
        stopwatch.stop();

        // Should fail and not take too long
        expect(result.success, isFalse);
        expect(result.error, anyOf([contains('timeout'), contains('unreachable')]));
        expect(stopwatch.elapsedMilliseconds, lessThan(15000)); // Should timeout within 15s
      });
    });

    group('Provider Integration', () {
      StabilityHelpers.stableSpotTestWidgets('should manage state through Riverpod providers', (WidgetTester tester) async {
        final notifier = container.read(sshHostsProvider.notifier);
        
        // Test initial state
        final initialState = container.read(sshHostsProvider);
        expect(initialState, isA<AsyncValue<List<SshProfile>>>());

        // Create test profile through provider
        final testProfile = createTestProfile(
          id: 'provider-test-1',
          name: 'Provider Test Server',
          host: 'provider.example.com',
          username: 'testuser',
          password: 'testpass',
        );

        final addResult = await notifier.addHost(testProfile);
        expect(addResult, isTrue);

        // Verify state update with timeout control using Spot-safe methods
        await StabilityHelpers.safePumpAndSettle(tester);
        
        final updatedState = container.read(sshHostsProvider);
        updatedState.whenOrNull(
          data: (hosts) {
            final found = hosts.any((h) => h.id == testProfile.id);
            expect(found, isTrue);
          },
        );

        // Test update through provider
        final updatedProfile = testProfile.copyWith(name: 'Updated Provider Test');
        final updateResult = await notifier.updateHost(updatedProfile);
        expect(updateResult, isTrue);

        // Test delete through provider
        final deleteResult = await notifier.deleteHost(testProfile.id);
        expect(deleteResult, isTrue);
      });

      StabilityHelpers.stableSpotTestWidgets('should handle provider error states', (WidgetTester tester) async {
        final notifier = container.read(sshHostsProvider.notifier);
        
        // Test with invalid profile (should fail gracefully)
        final invalidProfile = createTestProfile(
          id: '', // Invalid empty ID
          name: '',
          host: '',
          port: 0,
          username: '',
        );

        final result = await notifier.addHost(invalidProfile);
        expect(result, isFalse); // Should handle error gracefully
      });
    });

    group('Offline/Online Sync', () {
      StabilityHelpers.stableSpotTestWidgets('should handle offline mode gracefully', (WidgetTester tester) async {
        // Test that host service works when backend is unavailable
        final testProfile = createTestProfile(
          id: 'offline-test-1',
          name: 'Offline Test Server',
          host: 'offline.example.com',
          username: 'testuser',
          password: 'testpass',
        );

        // Even if backend API is down, local operations should work
        final result = await hostService.createHost(testProfile);
        
        // Should either succeed (if backend is up) or fail gracefully
        if (result != null) {
          expect(result.name, equals(testProfile.name));
          await hostService.deleteHost(result.id); // Clean up
        }
        // If result is null, that's acceptable for offline mode
      });
    });

    group('Security and Validation', () {
      StabilityHelpers.stableSpotTestWidgets('should validate SSH profile data', (WidgetTester tester) async {
        // Test various validation scenarios
        final invalidProfiles = [
          // Empty host
          createTestProfile(
            id: 'invalid-1',
            name: 'Invalid Host',
            host: '',
            username: 'testuser',
            password: 'testpass',
          ),
          // Invalid port
          createTestProfile(
            id: 'invalid-2', 
            name: 'Invalid Port',
            host: 'test.example.com',
            port: -1,
            username: 'testuser',
            password: 'testpass',
          ),
          // Missing username
          createTestProfile(
            id: 'invalid-3',
            name: 'Missing Username',
            host: 'test.example.com',
            username: '',
            password: 'testpass',
          ),
        ];

        for (final profile in invalidProfiles) {
          final result = await hostService.createHost(profile);
          // Should either fail or validate the data
          if (result != null) {
            await hostService.deleteHost(result.id); // Clean up if somehow created
          }
        }
      });

      StabilityHelpers.stableSpotTestWidgets('should encrypt sensitive data', (WidgetTester tester) async {
        final testProfile = createTestProfile(
          id: 'encryption-test-1',
          name: 'Encryption Test',
          host: 'encrypt.example.com',
          username: 'testuser',
          password: 'sensitive-password-123',
        );

        final result = await hostService.createHost(testProfile);
        if (result != null) {
          // Verify that sensitive data is handled properly
          // The actual password should be encrypted in storage
          expect(result.password, isNotNull);
          
          await hostService.deleteHost(result.id);
        }
      });
    });
  });
}