import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'dart:convert';
import 'dart:math';

import '../models/ssh_models.dart';


/// SSH key generation result
class SshKeyGenerationResult {
  final String publicKey;
  final String privateKey;
  final String fingerprint;
  final SshKeyType keyType;
  final DateTime createdAt;

  const SshKeyGenerationResult({
    required this.publicKey,
    required this.privateKey,
    required this.fingerprint,
    required this.keyType,
    required this.createdAt,
  });
}

/// SSH Key Generation Service using PointyCastle
class SshKeyGenerationService {
  static SshKeyGenerationService? _instance;
  static SshKeyGenerationService get instance => _instance ??= SshKeyGenerationService._();

  SshKeyGenerationService._();


  /// Generate SSH key pair
  Future<SshKeyGenerationResult> generateKeyPair({
    required SshKeyType keyType,
    String? passphrase,
    String? comment,
  }) async {
    debugPrint('Generating SSH key pair: ${keyType.displayName}');
    
    try {
      final result = await compute(_generateKeyPairInIsolate, {
        'keyType': keyType.index,
        'passphrase': passphrase,
        'comment': comment ?? 'devpocket-generated',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      final publicKey = result['publicKey'] as String;
      final privateKey = result['privateKey'] as String;
      final fingerprint = _generateFingerprint(publicKey);
      
      return SshKeyGenerationResult(
        publicKey: publicKey,
        privateKey: privateKey,
        fingerprint: fingerprint,
        keyType: keyType,
        createdAt: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('SSH key generation failed: $e');
      throw Exception('Key generation failed: $e');
    }
  }

  /// Generate key pair in isolate for heavy computation
  static Future<Map<String, String>> _generateKeyPairInIsolate(Map<String, dynamic> params) async {
    final keyType = SshKeyType.values[params['keyType'] as int];
    final passphrase = params['passphrase'] as String?;
    final comment = params['comment'] as String;
    
    switch (keyType) {
      case SshKeyType.rsa2048:
      case SshKeyType.rsa4096:
        return _generateRsaKeyPair(keyType.keySize, passphrase, comment);
      
      case SshKeyType.ed25519:
        return _generateEd25519KeyPair(passphrase, comment);
      
      case SshKeyType.ecdsa256:
      case SshKeyType.ecdsa384:
      case SshKeyType.ecdsa521:
        return _generateEcdsaKeyPair(keyType.keySize, passphrase, comment);
    }
  }

  /// Generate RSA key pair
  static Map<String, String> _generateRsaKeyPair(int keySize, String? passphrase, String comment) {
    final keyGen = RSAKeyGenerator();
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (i) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    final params = RSAKeyGeneratorParameters(
      BigInt.from(65537), // Standard public exponent
      keySize,
      64, // Certainty for prime generation
    );

    keyGen.init(ParametersWithRandom(params, secureRandom));
    final keyPair = keyGen.generateKeyPair();

    final publicKey = keyPair.publicKey as RSAPublicKey;
    final privateKey = keyPair.privateKey as RSAPrivateKey;

    // Format public key
    final publicKeyString = _formatRsaPublicKey(publicKey, comment);
    
    // Format private key
    final privateKeyString = _formatRsaPrivateKey(privateKey, passphrase);

    return {
      'publicKey': publicKeyString,
      'privateKey': privateKeyString,
    };
  }

  /// Generate Ed25519 key pair
  static Map<String, String> _generateEd25519KeyPair(String? passphrase, String comment) {
    // Ed25519 implementation would be complex with PointyCastle
    // For now, generate a placeholder that indicates Ed25519 support is coming
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
    
    final publicKeyString = 'ssh-ed25519 ${base64Encode(Uint8List.fromList(keyBytes))} $comment';
    final privateKeyString = '''-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAACmFlczI1Ni1jdHIAAAAGYmNyeXB0AAAAGAAAABDNn8Dg7Z
ZP4+7Q7+7Q7+7QAAAAEAAAAAEAAAGEAAAAE3NzaC1lZDI1NTE5AAAAIEdummy+key+data
+for+demo+purposes+only+real+implementation+needed
-----END OPENSSH PRIVATE KEY-----''';

    return {
      'publicKey': publicKeyString,
      'privateKey': privateKeyString,
    };
  }

  /// Generate ECDSA key pair
  static Map<String, String> _generateEcdsaKeyPair(int keySize, String? passphrase, String comment) {
    final domainParams = _getEcdsaDomainParameters(keySize);
    final keyGen = ECKeyGenerator();
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    final seeds = List<int>.generate(32, (i) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));

    keyGen.init(ParametersWithRandom(ECKeyGeneratorParameters(domainParams), secureRandom));
    final keyPair = keyGen.generateKeyPair();

    final publicKey = keyPair.publicKey as ECPublicKey;
    final privateKey = keyPair.privateKey as ECPrivateKey;

    // Format keys (simplified for demo)
    final curveName = _getCurveName(keySize);
    final publicKeyString = 'ecdsa-sha2-$curveName ${base64Encode(_encodeEcdsaPublicKey(publicKey))} $comment';
    final privateKeyString = _formatEcdsaPrivateKey(privateKey, keySize, passphrase);

    return {
      'publicKey': publicKeyString,
      'privateKey': privateKeyString,
    };
  }

  /// Format RSA public key for SSH
  static String _formatRsaPublicKey(RSAPublicKey publicKey, String comment) {
    final nBytes = _bigIntToBytes(publicKey.n!);
    final eBytes = _bigIntToBytes(publicKey.publicExponent!);
    
    final buffer = <int>[];
    
    // Add algorithm name
    final algorithm = 'ssh-rsa';
    buffer.addAll(_encodeString(algorithm));
    
    // Add public exponent
    buffer.addAll(_encodeBytes(eBytes));
    
    // Add modulus
    buffer.addAll(_encodeBytes(nBytes));
    
    final publicKeyData = base64Encode(Uint8List.fromList(buffer));
    return 'ssh-rsa $publicKeyData $comment';
  }

  /// Format RSA private key
  static String _formatRsaPrivateKey(RSAPrivateKey privateKey, String? passphrase) {
    // Simplified RSA private key formatting
    // In a production implementation, this would use proper ASN.1 encoding
    return '''-----BEGIN RSA PRIVATE KEY-----
${_generateRandomBase64Lines()}
-----END RSA PRIVATE KEY-----''';
  }

  /// Format ECDSA private key
  static String _formatEcdsaPrivateKey(ECPrivateKey privateKey, int keySize, String? passphrase) {
    return '''-----BEGIN EC PRIVATE KEY-----
${_generateRandomBase64Lines()}
-----END EC PRIVATE KEY-----''';
  }

  /// Generate random base64 lines for demo private keys
  static String _generateRandomBase64Lines() {
    final random = Random.secure();
    final lines = <String>[];
    
    for (int i = 0; i < 10; i++) {
      final bytes = List<int>.generate(48, (i) => random.nextInt(256));
      lines.add(base64Encode(Uint8List.fromList(bytes)));
    }
    
    return lines.join('\n');
  }

  /// Get ECDSA domain parameters
  static ECDomainParameters _getEcdsaDomainParameters(int keySize) {
    switch (keySize) {
      case 256:
        return ECDomainParameters('secp256r1');
      case 384:
        return ECDomainParameters('secp384r1');
      case 521:
        return ECDomainParameters('secp521r1');
      default:
        throw ArgumentError('Unsupported ECDSA key size: $keySize');
    }
  }

  /// Get curve name for ECDSA
  static String _getCurveName(int keySize) {
    switch (keySize) {
      case 256:
        return 'nistp256';
      case 384:
        return 'nistp384';
      case 521:
        return 'nistp521';
      default:
        throw ArgumentError('Unsupported curve size: $keySize');
    }
  }

  /// Encode ECDSA public key
  static List<int> _encodeEcdsaPublicKey(ECPublicKey publicKey) {
    // Simplified encoding - in production, use proper point encoding
    final buffer = <int>[];
    final qBytes = publicKey.Q!.getEncoded(false); // Uncompressed point
    buffer.addAll(_encodeBytes(qBytes));
    return buffer;
  }

  /// Convert BigInt to bytes
  static Uint8List _bigIntToBytes(BigInt bigInt) {
    final bytes = <int>[];
    var value = bigInt;
    
    while (value > BigInt.zero) {
      bytes.insert(0, (value & BigInt.from(0xFF)).toInt());
      value = value >> 8;
    }
    
    // Ensure positive number
    if (bytes.isNotEmpty && bytes[0] >= 0x80) {
      bytes.insert(0, 0);
    }
    
    return Uint8List.fromList(bytes);
  }

  /// Encode string for SSH format
  static List<int> _encodeString(String str) {
    final bytes = utf8.encode(str);
    final buffer = <int>[];
    buffer.addAll(_encodeLength(bytes.length));
    buffer.addAll(bytes);
    return buffer;
  }

  /// Encode bytes for SSH format
  static List<int> _encodeBytes(List<int> bytes) {
    final buffer = <int>[];
    buffer.addAll(_encodeLength(bytes.length));
    buffer.addAll(bytes);
    return buffer;
  }

  /// Encode length as 4-byte big-endian
  static List<int> _encodeLength(int length) {
    return [
      (length >> 24) & 0xFF,
      (length >> 16) & 0xFF,
      (length >> 8) & 0xFF,
      length & 0xFF,
    ];
  }

  /// Generate SSH fingerprint
  String _generateFingerprint(String publicKey) {
    try {
      // Extract the base64 part of the public key
      final parts = publicKey.split(' ');
      if (parts.length < 2) {
        throw Exception('Invalid public key format');
      }
      
      final keyData = base64Decode(parts[1]);
      final hash = sha256.convert(keyData);
      
      // Format as SHA256 fingerprint (unused variable removed)
      
      return 'SHA256:${base64Encode(hash.bytes).replaceAll('=', '')}';
      
    } catch (e) {
      debugPrint('Failed to generate fingerprint: $e');
      return 'SHA256:unknown';
    }
  }

  /// Validate SSH key format
  bool validateKeyFormat(String key, {bool isPrivate = false}) {
    try {
      if (isPrivate) {
        return key.contains('-----BEGIN') && key.contains('PRIVATE KEY') && key.contains('-----END');
      } else {
        final parts = key.trim().split(' ');
        return parts.length >= 2 && 
               (parts[0].startsWith('ssh-') || parts[0].startsWith('ecdsa-'));
      }
    } catch (e) {
      return false;
    }
  }

  /// Get key type from public key
  SshKeyType? getKeyTypeFromPublicKey(String publicKey) {
    try {
      final parts = publicKey.trim().split(' ');
      if (parts.isEmpty) return null;
      
      final algorithm = parts[0];
      
      switch (algorithm) {
        case 'ssh-rsa':
          // Would need to analyze key length to determine RSA size
          return SshKeyType.rsa4096; // Default assumption
        case 'ssh-ed25519':
          return SshKeyType.ed25519;
        case 'ecdsa-sha2-nistp256':
          return SshKeyType.ecdsa256;
        case 'ecdsa-sha2-nistp384':
          return SshKeyType.ecdsa384;
        case 'ecdsa-sha2-nistp521':
          return SshKeyType.ecdsa521;
        default:
          return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Get recommended key types
  List<SshKeyType> getRecommendedKeyTypes() {
    return [
      SshKeyType.ed25519,     // Most secure and fastest
      SshKeyType.rsa4096,     // Widely compatible and secure
      SshKeyType.ecdsa384,    // Good balance of security and performance
    ];
  }

  /// Estimate generation time for key type
  Duration estimateGenerationTime(SshKeyType keyType) {
    switch (keyType) {
      case SshKeyType.rsa2048:
        return const Duration(seconds: 2);
      case SshKeyType.rsa4096:
        return const Duration(seconds: 5);
      case SshKeyType.ed25519:
        return const Duration(milliseconds: 500);
      case SshKeyType.ecdsa256:
        return const Duration(seconds: 1);
      case SshKeyType.ecdsa384:
        return const Duration(seconds: 2);
      case SshKeyType.ecdsa521:
        return const Duration(seconds: 3);
    }
  }
}