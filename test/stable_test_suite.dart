import 'package:flutter_test/flutter_test.dart';

import 'test_config.dart';
import 'helpers/test_helpers.dart';

// Import specific stable test files
import 'integration/ssh_host_management_integration_test.dart' as ssh_host_integration;
import 'integration/ssh_terminal_integration_test.dart' as ssh_terminal_integration;
import 'performance/ssh_performance_test.dart' as ssh_performance;
import 'performance/crypto_performance_test.dart' as crypto_performance;
import 'security/encryption_security_test.dart' as encryption_security;
import 'error_scenarios/error_handling_test.dart' as error_handling;

/// Consolidated stable test suite
/// Runs all tests with stability enhancements to prevent timeouts and crashes
void main() {
  // Initialize test configuration
  TestConfig.initialize();
  
  group('DevPocket Stable Test Suite', () {
    
    setUpAll(() {
      print('Starting DevPocket Stable Test Suite');
      print('CI Environment: ${TestConfig.isCIEnvironment}');
      print('Test Timeouts: Short=${TestConfig.shortTimeout}, Medium=${TestConfig.mediumTimeout}, Long=${TestConfig.longTimeout}');
    });
    
    tearDownAll(() {
      print('DevPocket Stable Test Suite completed');
    });
    
    group('Integration Tests (Stable)', () {
      // Run integration tests with stability enhancements
      ssh_host_integration.main();
      
      // Add delay between test groups to prevent resource conflicts
      setUp(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      
      ssh_terminal_integration.main();
    });
    
    group('Performance Tests (Optimized)', () {
      // Run performance tests with reduced load
      ssh_performance.main();
      
      setUp(() async {
        await Future.delayed(const Duration(milliseconds: 100));
      });
      
      crypto_performance.main();
    });
    
    group('Security Tests (Split)', () {
      // Run security tests in smaller chunks
      encryption_security.main();
    });
    
    group('Error Handling Tests (Enhanced)', () {
      // Run error handling tests with retry logic
      error_handling.main();
    });
  });
  
  // Health check test
  TestStability.stableTestWidgets('Health Check - Test Environment', (tester) async {
    // Simple test to verify test environment is working
    expect(true, isTrue);
    expect(TestConfig.isCIEnvironment, isA<bool>());
    expect(TestHelpers.testTimeout, isA<Duration>());
    
    await TestHelpers.safePump(tester);
    
    print('✓ Test environment health check passed');
  });
}