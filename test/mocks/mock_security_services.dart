import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'dart:async';

import 'package:devpocket_warp_app/services/secure_storage_service.dart';
import 'package:devpocket_warp_app/services/ssh_host_service.dart';
import 'package:devpocket_warp_app/services/auth_service.dart';
import 'package:devpocket_warp_app/services/biometric_service.dart';
import 'package:devpocket_warp_app/models/ssh_profile_models.dart';

/// Mock services for security tests to prevent hanging on real service calls
/// These mocks provide fast, predictable responses without external dependencies

@GenerateMocks([
  SecureStorageService,
  SshHostService,
  AuthService,
  BiometricService,
])
class MockSecurityServices {}

/// Test-safe secure storage mock that doesn't hang on I/O operations
class TestSafeSecureStorageService extends Mock implements SecureStorageService {
  final Map<String, String> _storage = {};
  
  @override
  Future<String?> read(String key) async {
    // Simulate small delay but prevent hanging
    await Future.delayed(const Duration(milliseconds: 10));
    return _storage[key];
  }
  
  @override
  Future<void> write({required String key, required String value}) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _storage[key] = value;
  }
  
  @override
  Future<void> delete(String key) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _storage.remove(key);
  }
  
  @override
  Future<void> clearAll() async {
    await Future.delayed(const Duration(milliseconds: 10));
    _storage.clear();
  }
}

/// Test-safe SSH host service mock that doesn't make real API calls
class TestSafeSshHostService extends Mock implements SshHostService {
  final List<SshProfile> _profiles = [];
  
  @override
  Future<SshProfile?> createHost(SshProfile profile) async {
    // Simulate API call delay but prevent hanging
    await Future.delayed(const Duration(milliseconds: 50));
    
    // Validate required fields to simulate real validation
    if (profile.name.isEmpty || profile.host.isEmpty || profile.username.isEmpty) {
      return null; // Simulate validation failure
    }
    
    final createdProfile = profile.copyWith(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _profiles.add(createdProfile);
    return createdProfile;
  }
  
  @override
  Future<SshProfile?> getHost(String id) async {
    await Future.delayed(const Duration(milliseconds: 20));
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
  
  @override
  Future<List<SshProfile>> getHosts() async {
    await Future.delayed(const Duration(milliseconds: 30));
    return List.from(_profiles);
  }
  
  @override
  Future<SshProfile?> updateHost(String id, SshProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 40));
    final index = _profiles.indexWhere((p) => p.id == id);
    if (index != -1) {
      final updatedProfile = profile.copyWith(updatedAt: DateTime.now());
      _profiles[index] = updatedProfile;
      return updatedProfile;
    }
    return null;
  }
  
  @override
  Future<bool> deleteHost(String id) async {
    await Future.delayed(const Duration(milliseconds: 30));
    final initialLength = _profiles.length;
    _profiles.removeWhere((p) => p.id == id);
    return _profiles.length < initialLength;
  }
}

/// Test-safe auth service mock that doesn't make real network calls
class TestSafeAuthService extends Mock implements AuthService {
  bool _hasValidSession = false;
  String? _lastUsername;
  final Map<String, int> _attemptCounts = {};
  
  @override
  Future<bool> validateToken(String token) async {
    await Future.delayed(const Duration(milliseconds: 20));
    // Mock token validation - expired tokens return false
    return !token.contains('expired');
  }
  
  @override
  Future<bool> hasValidSession() async {
    await Future.delayed(const Duration(milliseconds: 15));
    return _hasValidSession;
  }
  
  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 25));
    _hasValidSession = false;
    _lastUsername = null;
  }
  
  @override
  Future<AuthResult> login(String username, String password) async {
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Simulate brute force protection after multiple failed attempts
    if (_lastUsername == username && password == 'wrongpassword') {
      // Simulate rate limiting on repeated wrong passwords
      int attemptCount = (_attemptCounts[username] ?? 0) + 1;
      _attemptCounts[username] = attemptCount;
      if (attemptCount > 5) {
        throw Exception('Account temporarily locked due to too many attempts');
      }
    }
    
    // Mock successful login
    if (password != 'wrongpassword') {
      _hasValidSession = true;
      _lastUsername = username;
      _attemptCounts.remove(username); // Reset attempt count on success
      return AuthResult(success: true, token: 'mock_token_${DateTime.now().millisecondsSinceEpoch}');
    }
    
    _lastUsername = username;
    throw Exception('Invalid credentials');
  }
  
  @override
  Future<bool> testConnection() async {
    await Future.delayed(const Duration(milliseconds: 50));
    // Mock connection test - return true to simulate successful connection
    return true;
  }
}

/// Test-safe biometric service mock that doesn't wait for user interaction
class TestSafeBiometricService extends Mock implements BiometricService {
  @override
  Future<bool> isAvailable() async {
    await Future.delayed(const Duration(milliseconds: 10));
    // Return false in test environment to skip biometric tests
    return false;
  }
  
  @override
  Future<BiometricAuthResult> authenticate({
    required String reason,
    BiometricAuthLevel level = BiometricAuthLevel.standard,
    bool allowFallback = true,
    bool stickyAuth = true,
    Duration? customTimeout,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    // In test environment, simulate immediate failure without user interaction
    return BiometricAuthResult.failure(
      error: BiometricAuthError.notAvailable,
      message: 'Biometric authentication not available in test environment',
    );
  }
}

/// Factory for creating test-safe service instances
class TestSafeServiceFactory {
  static TestSafeSecureStorageService createSecureStorageService() {
    return TestSafeSecureStorageService();
  }
  
  static TestSafeSshHostService createSshHostService() {
    return TestSafeSshHostService();
  }
  
  static TestSafeAuthService createAuthService() {
    return TestSafeAuthService();
  }
  
  static TestSafeBiometricService createBiometricService() {
    return TestSafeBiometricService();
  }
}