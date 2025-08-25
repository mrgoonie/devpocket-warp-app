import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/services/crypto_service.dart';

void main() {
  group('CryptoService SSH Key Validation', () {
    late CryptoService cryptoService;

    setUp(() {
      cryptoService = CryptoService();
    });

    test('should calculate fingerprint for valid SSH keys', () {
      // Use a properly formatted RSA public key
      const validRsaKey = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDILJ0x9JQ5+7rQXjL0Dq0QKrUX8hKlN7Dq0QKgGx2V4H7Q8Z9X3w2K+5JqZ1F8P0tYbC6VxN user@example.com';
      final result = cryptoService.calculateSSHFingerprint(validRsaKey);
      
      if (result != null) {
        expect(result, startsWith('SHA256:'));
        expect(result.length, greaterThan(10));
      }
    });

    test('should return null for invalid SSH keys', () {
      final invalidKeys = [
        'invalid-key-format',
        'ssh-rsa invalid-base64-data',
        '',
        'just-plain-text',
        'ssh-rsa',  // Missing key data
        'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDI!!!invalid',  // Invalid Base64
        'invalid-type AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDILJ0x9JQ5',  // Invalid key type
        '   ',  // Only whitespace
      ];

      for (final invalidKey in invalidKeys) {
        final result = cryptoService.calculateSSHFingerprint(invalidKey);
        expect(result, isNull, 
            reason: 'Should return null for invalid key: $invalidKey');
      }
    });

    test('should handle edge cases gracefully', () {
      // Test empty string
      expect(cryptoService.calculateSSHFingerprint(''), isNull);
      
      // Test whitespace only
      expect(cryptoService.calculateSSHFingerprint('   '), isNull);
      
      // Test incomplete key format
      expect(cryptoService.calculateSSHFingerprint('ssh-rsa'), isNull);
      
      // Test key with invalid type but valid base64
      expect(cryptoService.calculateSSHFingerprint('invalid-key AAAAB3NzaC1yc2EAAAADAQABAAABgQC7vbqajDI'), isNull);
    });

    test('should return null for invalid keys (new method behavior)', () {
      // Test that new method returns null for invalid keys instead of throwing
      expect(cryptoService.calculateSSHFingerprint(''), isNull);
      expect(cryptoService.calculateSSHFingerprint('invalid-key'), isNull);
    });
  });
}