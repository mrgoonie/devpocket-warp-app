import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'screens/main/main_tab_screen_test.dart' as main_tab_tests;
import 'screens/main/responsive_navigation_test.dart' as responsive_tests;
import 'screens/main/navigation_golden_test.dart' as golden_tests;
import 'integration/main_tab_integration_test.dart' as integration_tests;

/// Test suite runner for MainTabScreen comprehensive testing
/// 
/// This file organizes and runs all tests related to the responsive
/// bottom navigation tabs overflow fix implementation.
/// 
/// Test Coverage:
/// - Widget tests for basic functionality
/// - Responsive behavior tests for different screen sizes
/// - Text overflow protection and font scaling
/// - Accessibility compliance tests
/// - Visual regression tests (golden files)
/// - Integration tests for state management
/// - Performance and stress tests
void main() {
  group('MainTabScreen Comprehensive Test Suite', () {
    
    group('Core Widget Tests', () {
      main_tab_tests.main();
    });

    group('Responsive Layout Tests', () {
      responsive_tests.main();
    });

    group('Visual Regression Tests', () {
      golden_tests.main();
    });

    group('Integration & State Tests', () {
      integration_tests.main();
    });
  });
}