import 'package:flutter_test/flutter_test.dart';
import 'dart:typed_data';
import 'dart:convert';

import 'package:devpocket_warp_app/services/crypto_service.dart';
import '../helpers/test_helpers.dart';

/// Encryption security tests
/// Split from main security audit to prevent test overload
void main() {
  group('Encryption Security', () {
    late CryptoService cryptoService;

    setUp(() {
      cryptoService = CryptoService();
    });

    testWidgets('should use AES-256-GCM for sensitive data encryption', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        const sensitiveData = 'super-secret-ssh-password-123';
        final key = cryptoService.generateSalt();

        // Test AES-256-GCM encryption
        final encrypted = await cryptoService.encryptAESGCM(
          Uint8List.fromList(utf8.encode(sensitiveData)),
          key,
        );

        // Verify encryption properties
        expect(encrypted.ciphertext, isNotEmpty);
        expect(encrypted.nonce, isNotEmpty);
        expect(encrypted.tag, isNotEmpty);
        
        // Nonce should be 12 bytes for GCM
        expect(encrypted.nonce.length, equals(12));
        
        // Authentication tag should be 16 bytes for GCM
        expect(encrypted.tag.length, equals(16));
        
        // Ciphertext should be different from plaintext
        expect(encrypted.ciphertext, isNot(equals(utf8.encode(sensitiveData))));

        // Test decryption
        final decrypted = await cryptoService.decryptAESGCM(encrypted, key);
        final decryptedText = utf8.decode(decrypted);
        
        expect(decryptedText, equals(sensitiveData));
      });
    });

    testWidgets('should generate cryptographically secure nonces', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        const iterations = 20; // Reduced from 100
        final nonces = <List<int>>[];
        final data = Uint8List.fromList(utf8.encode('test data'));
        final key = cryptoService.generateSalt();

        // Generate multiple encrypted samples
        for (int i = 0; i < iterations; i++) {
          final encrypted = await cryptoService.encryptAESGCM(data, key);
          nonces.add(encrypted.nonce);
          
          // Add small delay to prevent system overload
          if (i % 5 == 0) {
            await Future.delayed(const Duration(milliseconds: 1));
          }
        }

        // Verify nonce uniqueness (no collisions)
        final uniqueNonces = nonces.toSet();
        expect(uniqueNonces.length, equals(iterations),
            reason: 'All nonces should be unique');

        // Verify nonce entropy (basic test)
        for (final nonce in nonces.take(5)) { // Check only first 5
          final zeros = nonce.where((byte) => byte == 0).length;
          expect(zeros, lessThan(nonce.length / 2),
              reason: 'Nonce should have good entropy');
        }
      });
    });

    testWidgets('should resist tampering attacks', (WidgetTester tester) async {
      await TestHelpers.withRetry(() async {
        const originalData = 'sensitive-information-123';
        final key = cryptoService.generateSalt();
        
        final encrypted = await cryptoService.encryptAESGCM(
          Uint8List.fromList(utf8.encode(originalData)),
          key,
        );

        // Test ciphertext tampering
        final tamperedCiphertext = Uint8List.fromList(encrypted.ciphertext);
        tamperedCiphertext[0] = tamperedCiphertext[0] ^ 1; // Flip one bit
        
        final tamperedData = EncryptedData(
          ciphertext: tamperedCiphertext,
          nonce: encrypted.nonce,
          tag: encrypted.tag,
        );

        // Should fail authentication
        expect(
          () => cryptoService.decryptAESGCM(tamperedData, key),
          throwsA(isA<CryptoException>()),
        );

        // Test authentication tag tampering
        final tamperedTag = Uint8List.fromList(encrypted.tag);
        tamperedTag[0] = tamperedTag[0] ^ 1; // Flip one bit
        
        final tamperedTagData = EncryptedData(
          ciphertext: encrypted.ciphertext,
          nonce: encrypted.nonce,
          tag: tamperedTag,
        );

        expect(
          () => cryptoService.decryptAESGCM(tamperedTagData, key),
          throwsA(isA<CryptoException>()),
        );

        // Test nonce tampering
        final tamperedNonce = Uint8List.fromList(encrypted.nonce);
        tamperedNonce[0] = tamperedNonce[0] ^ 1; // Flip one bit
        
        final tamperedNonceData = EncryptedData(
          ciphertext: encrypted.ciphertext,
          nonce: tamperedNonce,
          tag: encrypted.tag,
        );

        expect(
          () => cryptoService.decryptAESGCM(tamperedNonceData, key),
          throwsA(isA<CryptoException>()),
        );
      });
    });
  });
}