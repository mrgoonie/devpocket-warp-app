import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/models/user_model.dart';
import 'package:devpocket_warp_app/models/subscription_models.dart';
import 'package:devpocket_warp_app/models/ssh_profile_models.dart';

void main() {
  group('Model Serialization Tests - Snake Case API Compatibility', () {
    group('User Model', () {
      test('should serialize User to snake_case JSON', () {
        final user = User(
          id: 'test-id',
          username: 'testuser',
          email: 'test@example.com',
          emailVerified: true,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          subscriptionTier: 'pro',
          isInTrial: true,
          twoFactorEnabled: true,
          emailNotifications: true,
          pushNotifications: false,
          firstName: 'Test',
          lastName: 'User',
        );

        final json = user.toJson();

        expect(json['email_verified'], true);
        expect(json['created_at'], isA<String>());
        expect(json['updated_at'], isA<String>());
        expect(json['subscription_tier'], 'pro');
        expect(json['is_in_trial'], true);
        expect(json['two_factor_enabled'], true);
        expect(json['email_notifications'], true);
        expect(json['push_notifications'], false);
        expect(json['first_name'], 'Test');
        expect(json['last_name'], 'User');
      });

      test('should deserialize User from snake_case JSON', () {
        final json = {
          'id': 'test-id',
          'username': 'testuser',
          'email': 'test@example.com',
          'email_verified': true,
          'created_at': '2024-01-01T00:00:00.000Z',
          'updated_at': '2024-01-02T00:00:00.000Z',
          'subscription_tier': 'pro',
          'is_in_trial': true,
          'two_factor_enabled': true,
          'email_notifications': true,
          'push_notifications': false,
          'first_name': 'Test',
          'last_name': 'User',
        };

        final user = User.fromJson(json);

        expect(user.emailVerified, true);
        expect(user.subscriptionTier, 'pro');
        expect(user.isInTrial, true);
        expect(user.twoFactorEnabled, true);
        expect(user.emailNotifications, true);
        expect(user.pushNotifications, false);
        expect(user.firstName, 'Test');
        expect(user.lastName, 'User');
      });

      test('should maintain backwards compatibility with camelCase JSON', () {
        final json = {
          'id': 'test-id',
          'username': 'testuser',
          'email': 'test@example.com',
          'emailVerified': true,
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
          'subscriptionTier': 'pro',
          'isInTrial': true,
          'twoFactorEnabled': true,
          'emailNotifications': true,
          'pushNotifications': false,
          'firstName': 'Test',
          'lastName': 'User',
        };

        final user = User.fromJson(json);

        expect(user.emailVerified, true);
        expect(user.subscriptionTier, 'pro');
        expect(user.isInTrial, true);
        expect(user.twoFactorEnabled, true);
      });
    });

    group('Authentication Models', () {
      test('should deserialize AuthResponse from snake_case JSON', () {
        final json = {
          'user': {
            'id': 'test-id',
            'username': 'testuser',
            'email': 'test@example.com',
            'email_verified': true,
            'created_at': '2024-01-01T00:00:00.000Z',
            'updated_at': '2024-01-02T00:00:00.000Z',
          },
          'access_token': 'access-token-123',
          'refresh_token': 'refresh-token-456',
          'expires_in': 3600,
        };

        final authResponse = AuthResponse.fromJson(json);

        expect(authResponse.accessToken, 'access-token-123');
        expect(authResponse.refreshToken, 'refresh-token-456');
        expect(authResponse.expiresIn, 3600);
        expect(authResponse.user.username, 'testuser');
      });

      test('should serialize AuthResponse to snake_case JSON', () {
        final user = User(
          id: 'test-id',
          username: 'testuser',
          email: 'test@example.com',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final authResponse = AuthResponse(
          user: user,
          accessToken: 'access-token-123',
          refreshToken: 'refresh-token-456',
          expiresIn: 3600,
        );

        final json = authResponse.toJson();

        expect(json['access_token'], 'access-token-123');
        expect(json['refresh_token'], 'refresh-token-456');
        expect(json['expires_in'], 3600);
        expect(json['user'], isA<Map<String, dynamic>>());
      });

      test('should deserialize TokenRefreshResponse from snake_case JSON', () {
        final json = {
          'access_token': 'new-access-token',
          'refresh_token': 'new-refresh-token',
          'expires_in': 3600,
        };

        final response = TokenRefreshResponse.fromJson(json);

        expect(response.accessToken, 'new-access-token');
        expect(response.refreshToken, 'new-refresh-token');
        expect(response.expiresIn, 3600);
      });
    });

    group('Subscription Models', () {
      test('should serialize SubscriptionLimits to snake_case JSON', () {
        final limits = SubscriptionLimits(
          sshConnections: 10,
          aiRequests: 100,
          cloudHistory: true,
          multiDevice: true,
        );

        final json = limits.toJson();

        expect(json['ssh_connections'], 10);
        expect(json['ai_requests'], 100);
        expect(json['cloud_history'], true);
        expect(json['multi_device'], true);
      });

      test('should deserialize SubscriptionLimits from snake_case JSON', () {
        final json = {
          'ssh_connections': 10,
          'ai_requests': 100,
          'cloud_history': true,
          'multi_device': true,
        };

        final limits = SubscriptionLimits.fromJson(json);

        expect(limits.sshConnections, 10);
        expect(limits.aiRequests, 100);
        expect(limits.cloudHistory, true);
        expect(limits.multiDevice, true);
      });

      test('should maintain backwards compatibility with camelCase in SubscriptionLimits', () {
        final json = {
          'sshConnections': 10,
          'aiRequests': 100,
          'cloudHistory': true,
          'multiDevice': true,
        };

        final limits = SubscriptionLimits.fromJson(json);

        expect(limits.sshConnections, 10);
        expect(limits.aiRequests, 100);
        expect(limits.cloudHistory, true);
        expect(limits.multiDevice, true);
      });

      test('should serialize SubscriptionStatus to snake_case JSON', () {
        final status = SubscriptionStatus(
          isActive: true,
          tier: SubscriptionTier.pro,
          expiresAt: DateTime(2024, 12, 31),
          limits: SubscriptionLimits(
            sshConnections: -1,
            aiRequests: -1,
            cloudHistory: true,
            multiDevice: true,
          ),
        );

        final json = status.toJson();

        expect(json['is_active'], true);
        expect(json['tier'], 'PRO');
        expect(json['expires_at'], isA<String>());
        expect(json['limits'], isA<Map<String, dynamic>>());
      });

      test('should serialize FeatureUsage to snake_case JSON', () {
        final usage = FeatureUsage(
          feature: 'ssh_connections',
          used: 5,
          limit: 10,
          resetDate: DateTime(2024, 2, 1),
        );

        final json = usage.toJson();

        expect(json['feature'], 'ssh_connections');
        expect(json['used'], 5);
        expect(json['limit'], 10);
        expect(json['reset_date'], isA<String>());
      });

      test('should deserialize FeatureUsage from snake_case JSON', () {
        final json = {
          'feature': 'ssh_connections',
          'used': 5,
          'limit': 10,
          'reset_date': '2024-02-01T00:00:00.000Z',
        };

        final usage = FeatureUsage.fromJson(json);

        expect(usage.feature, 'ssh_connections');
        expect(usage.used, 5);
        expect(usage.limit, 10);
        expect(usage.resetDate, isNotNull);
      });
    });

    group('SSH Profile Models', () {
      test('should serialize SshProfile to snake_case JSON', () {
        final profile = SshProfile(
          id: 'profile-123',
          name: 'Test Server',
          host: 'test.example.com',
          username: 'testuser',
          authType: SshAuthType.key,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          lastConnectedAt: DateTime(2024, 1, 3),
          isDefault: true,
        );

        final json = profile.toJson();

        expect(json['id'], 'profile-123');
        expect(json['name'], 'Test Server');
        expect(json['host'], 'test.example.com');
        expect(json['username'], 'testuser');
        expect(json['auth_type'], 'key');
        expect(json['created_at'], isA<String>());
        expect(json['updated_at'], isA<String>());
        expect(json['last_connected_at'], isA<String>());
        expect(json['is_default'], true);
      });

      test('should serialize SshProfile toApiJson to snake_case', () {
        final profile = SshProfile(
          id: 'profile-123',
          name: 'Test Server',
          host: 'test.example.com',
          username: 'testuser',
          authType: SshAuthType.key,
          privateKey: 'private-key-content',
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
        );

        final json = profile.toApiJson();

        expect(json['name'], 'Test Server');
        expect(json['host'], 'test.example.com');
        expect(json['username'], 'testuser');
        expect(json['auth_type'], 'key');
        expect(json['private_key'], 'private-key-content');
        expect(json.containsKey('id'), false); // API JSON excludes client fields
        expect(json.containsKey('created_at'), false);
      });

      test('should deserialize SshProfile from snake_case JSON', () {
        final json = {
          'id': 'profile-123',
          'name': 'Test Server',
          'host': 'test.example.com',
          'port': 22,
          'username': 'testuser',
          'auth_type': 'key',
          'private_key': 'private-key-content',
          'created_at': '2024-01-01T00:00:00.000Z',
          'updated_at': '2024-01-02T00:00:00.000Z',
          'last_connected_at': '2024-01-03T00:00:00.000Z',
          'is_default': true,
          'status': 'active',
          'tags': ['production'],
        };

        final profile = SshProfile.fromJson(json);

        expect(profile.id, 'profile-123');
        expect(profile.name, 'Test Server');
        expect(profile.host, 'test.example.com');
        expect(profile.authType, SshAuthType.key);
        expect(profile.privateKey, 'private-key-content');
        expect(profile.isDefault, true);
        expect(profile.tags, ['production']);
      });

      test('should maintain backwards compatibility with camelCase in SshProfile', () {
        final json = {
          'id': 'profile-123',
          'name': 'Test Server',
          'host': 'test.example.com',
          'port': 22,
          'username': 'testuser',
          'authType': 'key',
          'privateKey': 'private-key-content',
          'createdAt': '2024-01-01T00:00:00.000Z',
          'updatedAt': '2024-01-02T00:00:00.000Z',
          'lastConnectedAt': '2024-01-03T00:00:00.000Z',
          'isDefault': true,
          'status': 'active',
          'tags': ['production'],
        };

        final profile = SshProfile.fromJson(json);

        expect(profile.authType, SshAuthType.key);
        expect(profile.privateKey, 'private-key-content');
        expect(profile.isDefault, true);
      });

      test('should serialize TerminalSession to snake_case JSON', () {
        final session = TerminalSession(
          id: 'session-123',
          type: 'ssh',
          sshProfileId: 'profile-123',
          status: 'active',
          createdAt: DateTime(2024, 1, 1),
          lastActivity: DateTime(2024, 1, 2),
        );

        final json = session.toJson();

        expect(json['id'], 'session-123');
        expect(json['type'], 'ssh');
        expect(json['ssh_profile_id'], 'profile-123');
        expect(json['status'], 'active');
        expect(json['created_at'], isA<String>());
        expect(json['last_activity'], isA<String>());
      });

      test('should deserialize TerminalSession from snake_case JSON', () {
        final json = {
          'id': 'session-123',
          'type': 'ssh',
          'ssh_profile_id': 'profile-123',
          'status': 'active',
          'created_at': '2024-01-01T00:00:00.000Z',
          'last_activity': '2024-01-02T00:00:00.000Z',
        };

        final session = TerminalSession.fromJson(json);

        expect(session.id, 'session-123');
        expect(session.type, 'ssh');
        expect(session.sshProfileId, 'profile-123');
        expect(session.status, 'active');
      });

      test('should serialize SshKeyValidationResult to snake_case JSON', () {
        final result = SshKeyValidationResult(
          isValid: true,
          keyType: 'ed25519',
          keySize: 256,
          fingerprint: 'SHA256:fingerprint',
        );

        final json = result.toJson();

        expect(json['is_valid'], true);
        expect(json['key_type'], 'ed25519');
        expect(json['key_size'], 256);
        expect(json['fingerprint'], 'SHA256:fingerprint');
      });

      test('should serialize TerminalStats to snake_case JSON', () {
        final stats = TerminalStats(
          totalSessions: 10,
          activeSessions: 2,
          totalCommands: 150,
          totalUsageTime: Duration(hours: 5),
          topCommands: ['ls', 'cd', 'vim'],
          sessionsByType: {'ssh': 8, 'local': 2},
        );

        final json = stats.toJson();

        expect(json['total_sessions'], 10);
        expect(json['active_sessions'], 2);
        expect(json['total_commands'], 150);
        expect(json['total_usage_time'], 18000000); // 5 hours in milliseconds
        expect(json['top_commands'], ['ls', 'cd', 'vim']);
        expect(json['sessions_by_type'], {'ssh': 8, 'local': 2});
      });

      test('should deserialize TerminalStats from snake_case JSON', () {
        final json = {
          'total_sessions': 10,
          'active_sessions': 2,
          'total_commands': 150,
          'total_usage_time': 18000000, // 5 hours in milliseconds
          'top_commands': ['ls', 'cd', 'vim'],
          'sessions_by_type': {'ssh': 8, 'local': 2},
        };

        final stats = TerminalStats.fromJson(json);

        expect(stats.totalSessions, 10);
        expect(stats.activeSessions, 2);
        expect(stats.totalCommands, 150);
        expect(stats.totalUsageTime, Duration(hours: 5));
        expect(stats.topCommands, ['ls', 'cd', 'vim']);
        expect(stats.sessionsByType, {'ssh': 8, 'local': 2});
      });
    });

    group('Round-trip Serialization Tests', () {
      test('User model should maintain data integrity through serialize/deserialize cycle', () {
        final originalUser = User(
          id: 'test-id',
          username: 'testuser',
          email: 'test@example.com',
          emailVerified: true,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          subscriptionTier: 'pro',
          isInTrial: true,
          firstName: 'Test',
          lastName: 'User',
        );

        final json = originalUser.toJson();
        final deserializedUser = User.fromJson(json);

        expect(deserializedUser.id, originalUser.id);
        expect(deserializedUser.username, originalUser.username);
        expect(deserializedUser.email, originalUser.email);
        expect(deserializedUser.emailVerified, originalUser.emailVerified);
        expect(deserializedUser.subscriptionTier, originalUser.subscriptionTier);
        expect(deserializedUser.isInTrial, originalUser.isInTrial);
        expect(deserializedUser.firstName, originalUser.firstName);
        expect(deserializedUser.lastName, originalUser.lastName);
      });

      test('SshProfile model should maintain data integrity through serialize/deserialize cycle', () {
        final originalProfile = SshProfile(
          id: 'profile-123',
          name: 'Test Server',
          host: 'test.example.com',
          username: 'testuser',
          authType: SshAuthType.key,
          createdAt: DateTime(2024, 1, 1),
          updatedAt: DateTime(2024, 1, 2),
          isDefault: true,
        );

        final json = originalProfile.toJson();
        final deserializedProfile = SshProfile.fromJson(json);

        expect(deserializedProfile.id, originalProfile.id);
        expect(deserializedProfile.name, originalProfile.name);
        expect(deserializedProfile.host, originalProfile.host);
        expect(deserializedProfile.username, originalProfile.username);
        expect(deserializedProfile.authType, originalProfile.authType);
        expect(deserializedProfile.isDefault, originalProfile.isDefault);
      });
    });
  });
}