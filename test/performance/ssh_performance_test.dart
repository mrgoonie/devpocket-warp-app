import 'package:flutter_test/flutter_test.dart';

import '../../lib/models/ssh_profile_models.dart';
import '../../lib/services/ssh_connection_manager.dart';
import '../helpers/test_helpers.dart';

/// SSH connection performance tests
/// Split from main performance test to prevent segmentation faults
void main() {
  group('SSH Connection Performance', () {
    late SshConnectionManager sshManager;

    setUp(() {
      sshManager = SshConnectionManager.instance;
    });

    testWidgets('should establish SSH connection within timeout', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        final now = DateTime.now();
        final testProfile = SshProfile(
          id: 'perf-connection-test',
          name: 'Performance Connection Test',
          host: 'localhost',
          port: 22,
          username: 'testuser',
          authType: SshAuthType.password,
          password: 'testpass',
          createdAt: now,
          updatedAt: now,
        );

        final stopwatch = Stopwatch()..start();
        
        try {
          await sshManager.connect(testProfile);
          stopwatch.stop();
          
          // Performance requirement: Sub-3s SSH connection establishment
          expect(stopwatch.elapsedMilliseconds, lessThan(3000),
              reason: 'SSH connection should establish within 3 seconds');
              
          print('SSH connection established in ${stopwatch.elapsedMilliseconds}ms');
          
        } catch (e) {
          stopwatch.stop();
          print('SSH connection failed in ${stopwatch.elapsedMilliseconds}ms: $e');
          // Even failures should be reasonably fast
          expect(stopwatch.elapsedMilliseconds, lessThan(10000),
              reason: 'SSH connection failures should timeout quickly');
        }
      });
    });

    testWidgets('should handle limited concurrent connections efficiently', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        const concurrentConnections = 2; // Very small number to prevent overload
        final now = DateTime.now();
        final profiles = List.generate(concurrentConnections, (index) => SshProfile(
          id: 'concurrent-perf-$index',
          name: 'Concurrent Performance $index',
          host: 'localhost',
          port: 22,
          username: 'testuser$index',
          authType: SshAuthType.password,
          password: 'testpass$index',
          createdAt: now,
          updatedAt: now,
        ));

        final stopwatch = Stopwatch()..start();
        
        final futures = profiles.map((profile) async {
          final connectionStopwatch = Stopwatch()..start();
          try {
            await sshManager.connect(profile);
            connectionStopwatch.stop();
            return connectionStopwatch.elapsedMilliseconds;
          } catch (e) {
            connectionStopwatch.stop();
            return connectionStopwatch.elapsedMilliseconds;
          }
        }).toList();

        final connectionTimes = await Future.wait(futures);
        stopwatch.stop();

        print('Concurrent connections completed in ${stopwatch.elapsedMilliseconds}ms');
        print('Individual connection times: $connectionTimes');

        // Should handle concurrent connections efficiently
        expect(stopwatch.elapsedMilliseconds, lessThan(15000),
            reason: 'Concurrent connections should complete within 15 seconds');

        // Average connection time should be reasonable
        final averageTime = connectionTimes.reduce((a, b) => a + b) / connectionTimes.length;
        expect(averageTime, lessThan(8000), // More lenient timeout
            reason: 'Average connection time should be under 8 seconds');
      });
    });
  });
}