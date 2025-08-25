import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:devpocket_warp_app/models/ssh_profile_models.dart';

/// Test Data Generation Utilities - Phase 5E.1
/// Optimized test data generation for performance testing
/// 
/// Features:
/// - Efficient SSH key generation for testing
/// - Performance-optimized mock data creation
/// - Lazy loading for large test datasets
/// - Test data caching mechanisms
/// - Realistic data generation patterns

class TestDataGenerator {
  static final math.Random _random = math.Random();
  static final Map<String, List<dynamic>> _cache = {};
  
  /// Generate realistic SSH profiles for testing
  static List<SshProfile> generateSshProfiles(int count, {String prefix = 'test'}) {
    final cacheKey = 'ssh_profiles_${prefix}_$count';
    
    if (_cache.containsKey(cacheKey)) {
      return List<SshProfile>.from(_cache[cacheKey]!);
    }
    
    final now = DateTime.now();
    final profiles = List.generate(count, (index) {
      final id = '${prefix}_ssh_$index';
      final host = 'host$index.example.com';
      final username = '${prefix}user$index';
      
      return SshProfile(
        id: id,
        name: '${prefix.toUpperCase()} SSH Profile $index',
        host: host,
        port: 22 + (index % 10), // Vary ports slightly
        username: username,
        authType: index % 2 == 0 ? SshAuthType.password : SshAuthType.key,
        password: index % 2 == 0 ? '${prefix}pass$index' : null,
        privateKey: index % 2 == 1 ? _generateMockPrivateKey() : null,
        createdAt: now.subtract(Duration(days: index % 30)),
        updatedAt: now.subtract(Duration(hours: index % 24)),
        description: 'Generated test profile for performance testing - $index',
        tags: _generateRandomTags(index),
      );
    });
    
    _cache[cacheKey] = profiles;
    return profiles;
  }
  
  /// Generate test data with specified size
  static Uint8List generateTestData(int sizeBytes, {int? seed}) {
    final random = seed != null ? math.Random(seed) : _random;
    final data = Uint8List(sizeBytes);
    
    for (int i = 0; i < sizeBytes; i++) {
      data[i] = random.nextInt(256);
    }
    
    return data;
  }
  
  /// Generate test strings with specific patterns
  static List<String> generateTestStrings(int count, {
    int minLength = 10,
    int maxLength = 100,
    String pattern = 'performance_test',
  }) {
    return List.generate(count, (index) {
      final length = minLength + _random.nextInt(maxLength - minLength);
      final buffer = StringBuffer('${pattern}_$index');
      
      // Fill to desired length
      while (buffer.length < length) {
        buffer.write('_${_random.nextInt(1000)}');
      }
      
      return buffer.toString().substring(0, length);
    });
  }
  
  /// Generate mock WebSocket messages
  static List<String> generateWebSocketMessages(int count, {String type = 'terminal'}) {
    return List.generate(count, (index) {
      switch (type) {
        case 'terminal':
          return jsonEncode({
            'type': 'terminal_data',
            'sessionId': 'test_session_${index % 5}',
            'data': 'Mock terminal output line $index\\n',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          
        case 'command':
          final commands = ['ls -la', 'pwd', 'whoami', 'ps aux', 'df -h'];
          return jsonEncode({
            'type': 'command',
            'sessionId': 'test_session_${index % 5}',
            'command': commands[index % commands.length],
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          
        default:
          return 'Mock WebSocket message $index';
      }
    });
  }
  
  /// Generate crypto test keys (mock data for performance testing)
  static Map<String, String> generateMockKeyPair({String type = 'ed25519'}) {
    switch (type) {
      case 'ed25519':
        return {
          'privateKey': _generateMockPrivateKey(),
          'publicKey': _generateMockPublicKey(),
          'fingerprint': 'SHA256:${_generateRandomBase64(43)}',
        };
        
      case 'rsa':
        return {
          'privateKey': _generateMockRSAPrivateKey(),
          'publicKey': _generateMockRSAPublicKey(),
          'fingerprint': 'SHA256:${_generateRandomBase64(43)}',
        };
        
      default:
        throw ArgumentError('Unsupported key type: $type');
    }
  }
  
  /// Generate large datasets with lazy loading
  static Iterable<T> generateLazyDataset<T>(int count, T Function(int index) generator) sync* {
    for (int i = 0; i < count; i++) {
      yield generator(i);
    }
  }
  
  /// Generate memory test blocks
  static List<Uint8List> generateMemoryBlocks(int count, int blockSize) {
    return List.generate(count, (index) {
      final block = Uint8List(blockSize);
      // Fill with deterministic pattern for testing
      for (int i = 0; i < blockSize; i++) {
        block[i] = (index + i) % 256;
      }
      return block;
    });
  }
  
  /// Clear cached test data
  static void clearCache() {
    _cache.clear();
  }
  
  /// Get cache statistics
  static Map<String, int> getCacheStats() {
    return _cache.map((key, value) => MapEntry(key, value.length));
  }
  
  // Private helper methods
  static String _generateMockPrivateKey() {
    return '''-----BEGIN OPENSSH PRIVATE KEY-----
${_generateRandomBase64(70)}
${_generateRandomBase64(70)}
${_generateRandomBase64(70)}
-----END OPENSSH PRIVATE KEY-----''';
  }
  
  static String _generateMockPublicKey() {
    return 'ssh-ed25519 ${_generateRandomBase64(68)} test@performance';
  }
  
  static String _generateMockRSAPrivateKey() {
    final lines = List.generate(20, (i) => _generateRandomBase64(64));
    return '''-----BEGIN RSA PRIVATE KEY-----
${lines.join('\\n')}
-----END RSA PRIVATE KEY-----''';
  }
  
  static String _generateMockRSAPublicKey() {
    return 'ssh-rsa ${_generateRandomBase64(372)} test@performance';
  }
  
  static String _generateRandomBase64(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();
    
    for (int i = 0; i < length; i++) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    
    return buffer.toString();
  }
  
  static List<String> _generateRandomTags(int index) {
    final allTags = ['production', 'staging', 'development', 'testing', 'backup', 'database', 'web', 'api'];
    final tagCount = 1 + (index % 3);
    final selectedTags = <String>[];
    
    for (int i = 0; i < tagCount; i++) {
      final tag = allTags[(index + i) % allTags.length];
      if (!selectedTags.contains(tag)) {
        selectedTags.add(tag);
      }
    }
    
    return selectedTags;
  }
}

/// Performance-optimized test data patterns
class PerformanceTestPatterns {
  /// Generate incremental data for consistency testing
  static List<Map<String, dynamic>> generateIncrementalData(int count) {
    return List.generate(count, (index) => {
      'id': index,
      'timestamp': DateTime.now().millisecondsSinceEpoch + index,
      'data': 'incremental_data_$index',
      'size': 100 + (index * 10),
      'checksum': (index * 31) % 65536, // Simple checksum
    });
  }
  
  /// Generate burst data patterns for load testing
  static List<List<T>> generateBurstPattern<T>(List<T> data, int burstSize, int burstCount) {
    final bursts = <List<T>>[];
    final itemsPerBurst = data.length ~/ burstCount;
    
    for (int burst = 0; burst < burstCount; burst++) {
      final startIndex = burst * itemsPerBurst;
      final endIndex = math.min(startIndex + itemsPerBurst, data.length);
      bursts.add(data.sublist(startIndex, endIndex));
    }
    
    return bursts;
  }
  
  /// Generate stress test scenarios
  static Map<String, dynamic> generateStressScenario(String scenarioType) {
    switch (scenarioType) {
      case 'memory_pressure':
        return {
          'type': 'memory_pressure',
          'blocks': 50,
          'block_size': 1024 * 1024, // 1MB blocks
          'duration_ms': 5000,
          'concurrent_ops': 20,
        };
        
      case 'cpu_intensive':
        return {
          'type': 'cpu_intensive',
          'iterations': 100000,
          'concurrent_tasks': 10,
          'duration_ms': 3000,
        };
        
      case 'io_intensive':
        return {
          'type': 'io_intensive',
          'file_count': 100,
          'file_size': 10 * 1024, // 10KB files
          'concurrent_operations': 25,
        };
        
      default:
        return {
          'type': 'unknown',
          'description': 'Unknown stress scenario type: $scenarioType',
        };
    }
  }
}

