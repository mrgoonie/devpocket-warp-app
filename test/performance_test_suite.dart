import 'package:flutter_test/flutter_test.dart';

import 'performance/crypto_performance_test.dart' as crypto_perf;
import 'performance/crypto_benchmarks_test.dart' as crypto_bench;
import 'performance/memory_monitoring_test.dart' as memory_mon;
import 'performance/load_testing_suite.dart' as load_test;
import 'performance/stress_testing_suite.dart' as stress_test;
import 'performance/performance_benchmarks_test.dart' as perf_bench;

/// Comprehensive Performance Test Suite - Phase 5 Complete
/// Runs all performance tests with proper orchestration and reporting
/// 
/// Test Categories:
/// 1. Crypto Performance - Production target validation
/// 2. Crypto Benchmarks - Advanced profiling and regression detection  
/// 3. Memory Monitoring - Leak detection and usage validation
/// 4. Load Testing - Concurrent operation validation
/// 5. Stress Testing - System resilience under extreme conditions
/// 6. Performance Benchmarks - Existing comprehensive benchmarks
void main() {
  group('DevPocket Performance Test Suite - Phase 5', () {
    setUpAll(() {
      print('=== STARTING DEVPOCKET PHASE 5 PERFORMANCE TEST SUITE ===');
      print('Production Readiness Validation - Complete Performance Testing');
      print('');
    });

    tearDownAll(() {
      print('');
      print('=== DEVPOCKET PHASE 5 PERFORMANCE TEST SUITE COMPLETED ===');
      print('All performance tests executed for production readiness validation');
    });

    group('1. Enhanced Crypto Performance Tests', () {
      crypto_perf.main();
    });

    group('2. Advanced Crypto Benchmarks', () {
      crypto_bench.main();
    });

    group('3. Memory Monitoring & Leak Detection', () {
      memory_mon.main();
    });

    group('4. Load Testing Suite', () {
      load_test.main();
    });

    group('5. Stress Testing Framework', () {
      stress_test.main();
    });

    group('6. Performance Benchmarks (Legacy)', () {
      perf_bench.main();
    });
  });
}