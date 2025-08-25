import 'package:flutter_test/flutter_test.dart';

// Try to import just the model classes first
import 'package:devpocket_warp_app/models/ssh_profile_models.dart';

void main() {
  group('Simple Import Test', () {
    test('should import models without hanging', () {
      final profile = SshProfile(
        id: 'test',
        name: 'test',
        host: 'test',
        port: 22,
        username: 'test',
        authType: SshAuthType.password,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      expect(profile.name, equals('test'));
    });
  });
}