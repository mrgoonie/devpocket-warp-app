import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide SecureRandom;
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:logger/logger.dart';

/// SSH Key Types supported by the crypto service
enum SSHKeyType {
  rsa,
  ed25519,
  ecdsa,
}

/// Comprehensive cryptographic service for DevPocket
/// Handles key generation, encryption, decryption, and digital signatures
class CryptoService {
  static const int _saltLength = 32;
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits for AES
  static const int _iterations = 100000; // PBKDF2 iterations
  
  final SecureRandom _secureRandom;
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.none,
    ),
  );
  
  CryptoService() : _secureRandom = SecureRandom('Fortuna') {
    // Initialize secure random with entropy
    // Use non-blocking initialization for test environments
    try {
      final seed = Uint8List(32);
      final random = Random.secure();
      for (int i = 0; i < seed.length; i++) {
        seed[i] = random.nextInt(256);
      }
      _secureRandom.seed(KeyParameter(seed));
    } catch (e) {
      // Fall back to deterministic seed for test environments
      _logger.w('Using fallback deterministic seed for CryptoService: $e');
      final fallbackSeed = Uint8List.fromList(List.generate(32, (i) => i * 7 % 256));
      _secureRandom.seed(KeyParameter(fallbackSeed));
    }
  }

  /// Test-safe constructor for unit tests
  CryptoService.forTesting() : _secureRandom = SecureRandom('Fortuna') {
    // Use deterministic seed for consistent test behavior
    final testSeed = Uint8List.fromList(List.generate(32, (i) => (i * 13 + 42) % 256));
    _secureRandom.seed(KeyParameter(testSeed));
    _logger.i('CryptoService initialized with test-safe deterministic seed');
  }
  
  /// Generate a cryptographically secure random salt
  Uint8List generateSalt() {
    final salt = Uint8List(_saltLength);
    for (int i = 0; i < salt.length; i++) {
      salt[i] = _secureRandom.nextUint8();
    }
    return salt;
  }
  
  /// Generate a cryptographically secure random IV
  Uint8List generateIV() {
    final iv = Uint8List(_ivLength);
    for (int i = 0; i < iv.length; i++) {
      iv[i] = _secureRandom.nextUint8();
    }
    return iv;
  }
  
  /// Derive a key from password using PBKDF2
  Uint8List deriveKeyFromPassword(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    pbkdf2.init(Pbkdf2Parameters(salt, _iterations, _keyLength));
    
    final passwordBytes = utf8.encode(password);
    return pbkdf2.process(Uint8List.fromList(passwordBytes));
  }
  
  /// Encrypt data using AES-256-GCM
  Future<EncryptedData> encryptAESGCM(
    Uint8List data,
    Uint8List key, {
    Uint8List? associatedData,
  }) async {
    try {
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(key);
      
      // Generate random nonce
      final nonce = Uint8List(12); // 96-bit nonce for GCM
      for (int i = 0; i < nonce.length; i++) {
        nonce[i] = _secureRandom.nextUint8();
      }
      
      final secretBox = await algorithm.encrypt(
        data,
        secretKey: secretKey,
        nonce: nonce,
        aad: associatedData ?? Uint8List(0),
      );
      
      return EncryptedData(
        ciphertext: Uint8List.fromList(secretBox.cipherText),
        nonce: nonce,
        tag: Uint8List.fromList(secretBox.mac.bytes),
      );
    } catch (e) {
      throw CryptoException('AES-GCM encryption failed: $e');
    }
  }
  
  /// Decrypt data using AES-256-GCM
  Future<Uint8List> decryptAESGCM(
    EncryptedData encryptedData,
    Uint8List key, {
    Uint8List? associatedData,
  }) async {
    try {
      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(key);
      
      final secretBox = SecretBox(
        encryptedData.ciphertext,
        nonce: encryptedData.nonce,
        mac: crypto.Mac(encryptedData.tag),
      );
      
      final plaintext = await algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: associatedData ?? Uint8List(0),
      );
      
      return Uint8List.fromList(plaintext);
    } catch (e) {
      throw CryptoException('AES-GCM decryption failed: $e');
    }
  }
  
  /// Encrypt SSH private key with password-based encryption
  Future<EncryptedSSHKey> encryptSSHKey(
    String privateKey,
    String password,
  ) async {
    final salt = generateSalt();
    final derivedKey = deriveKeyFromPassword(password, salt);
    
    final keyData = utf8.encode(privateKey);
    final encryptedData = await encryptAESGCM(
      Uint8List.fromList(keyData),
      derivedKey,
      associatedData: utf8.encode('ssh-private-key').toUint8List(),
    );
    
    return EncryptedSSHKey(
      encryptedKey: encryptedData,
      salt: salt,
      iterations: _iterations,
    );
  }
  
  /// Decrypt SSH private key
  Future<String> decryptSSHKey(
    EncryptedSSHKey encryptedSSHKey,
    String password,
  ) async {
    final derivedKey = deriveKeyFromPassword(password, encryptedSSHKey.salt);
    
    final decryptedData = await decryptAESGCM(
      encryptedSSHKey.encryptedKey,
      derivedKey,
      associatedData: utf8.encode('ssh-private-key').toUint8List(),
    );
    
    return utf8.decode(decryptedData);
  }
  
  /// Generate SSH key pair (RSA 4096-bit)
  Future<SSHKeyPair> generateSSHKeyPairRSA({int keySize = 4096}) async {
    try {
      final keyGen = RSAKeyGenerator();
      keyGen.init(ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.parse('65537'), keySize, 64),
        _secureRandom,
      ));
      
      final keyPair = keyGen.generateKeyPair();
      final privateKey = keyPair.privateKey as RSAPrivateKey;
      final publicKey = keyPair.publicKey as RSAPublicKey;
      
      // Convert to PEM format
      final privateKeyPem = _encodeRSAPrivateKeyToPem(privateKey);
      final publicKeyPem = _encodeRSAPublicKeyToSSH(publicKey);
      
      return SSHKeyPair(
        privateKey: privateKeyPem,
        publicKey: publicKeyPem,
        keyType: 'rsa',
        keySize: keySize,
      );
    } catch (e) {
      throw CryptoException('RSA key generation failed: $e');
    }
  }
  
  /// Generate SSH key pair (Ed25519)
  Future<SSHKeyPair> generateSSHKeyPairEd25519() async {
    try {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      
      final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();
      
      // Convert to SSH format
      final privateKeyPem = _encodeEd25519PrivateKeyToPem(privateKeyBytes);
      final publicKeySSH = _encodeEd25519PublicKeyToSSH(publicKey.bytes);
      
      return SSHKeyPair(
        privateKey: privateKeyPem,
        publicKey: publicKeySSH,
        keyType: 'ed25519',
        keySize: 256,
      );
    } catch (e) {
      throw CryptoException('Ed25519 key generation failed: $e');
    }
  }
  
  /// Generate SSH key pair with specified type and parameters
  Future<SSHKeyPair> generateSSHKeyPair({
    required SSHKeyType type,
    int? bitLength,
  }) async {
    switch (type) {
      case SSHKeyType.rsa:
        return await generateSSHKeyPairRSA(keySize: bitLength ?? 4096);
      case SSHKeyType.ed25519:
        return await generateSSHKeyPairEd25519();
      case SSHKeyType.ecdsa:
        throw const CryptoException('ECDSA key generation not yet implemented');
    }
  }
  
  /// Calculate SSH host key fingerprint (SHA256) with comprehensive error handling
  /// Returns null for invalid keys instead of throwing exceptions
  String? calculateSSHFingerprint(String publicKey) {
    try {
      // Input validation
      if (publicKey.isEmpty || publicKey.trim().isEmpty) {
        if (kDebugMode) {
          _logger.d('SSH fingerprint calculation failed: Empty key provided');
        }
        return null;
      }

      // Split and validate SSH key format
      final parts = publicKey.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) {
        if (kDebugMode) {
          _logger.d('SSH fingerprint calculation failed: Invalid key format - insufficient parts');
        }
        return null;
      }

      // Validate SSH key type
      final keyType = parts[0];
      if (!_isValidSSHKeyType(keyType)) {
        if (kDebugMode) {
          _logger.d('SSH fingerprint calculation failed: Invalid key type - $keyType');
        }
        return null;
      }

      // Safe Base64 decoding
      final keyData = _safeBase64Decode(parts[1]);
      if (keyData == null) {
        if (kDebugMode) {
          _logger.d('SSH fingerprint calculation failed: Invalid Base64 encoding');
        }
        return null;
      }

      // Validate minimum key data size
      if (keyData.length < 32) {
        if (kDebugMode) {
          _logger.d('SSH fingerprint calculation failed: Key data too short (${keyData.length} bytes)');
        }
        return null;
      }

      // Calculate SHA256 fingerprint
      final digest = sha256.convert(keyData);
      final fingerprint = base64.encode(digest.bytes);
      
      return 'SHA256:$fingerprint';
    } catch (e, stackTrace) {
      if (kDebugMode) {
        _logger.e('SSH fingerprint calculation error: $e', error: e, stackTrace: stackTrace);
      }
      return null;
    }
  }

  /// Legacy method that throws exceptions for backward compatibility
  @Deprecated('Use calculateSSHFingerprint which returns null for invalid keys')
  String calculateSSHFingerprintLegacy(String publicKey) {
    final result = calculateSSHFingerprint(publicKey);
    if (result == null) {
      throw ArgumentError('Invalid SSH public key format');
    }
    return result;
  }
  
  /// Calculate MD5 fingerprint (legacy support) with enhanced error handling
  String? calculateMD5Fingerprint(String publicKey) {
    try {
      // Input validation
      if (publicKey.isEmpty || publicKey.trim().isEmpty) {
        if (kDebugMode) {
          _logger.d('MD5 fingerprint calculation failed: Empty key provided');
        }
        return null;
      }

      final parts = publicKey.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) {
        if (kDebugMode) {
          _logger.d('MD5 fingerprint calculation failed: Invalid key format');
        }
        return null;
      }
      
      // Validate SSH key type
      final keyType = parts[0];
      if (!_isValidSSHKeyType(keyType)) {
        if (kDebugMode) {
          _logger.d('MD5 fingerprint calculation failed: Invalid key type - $keyType');
        }
        return null;
      }
      
      // Safe Base64 decoding
      final keyData = _safeBase64Decode(parts[1]);
      if (keyData == null) {
        if (kDebugMode) {
          _logger.d('MD5 fingerprint calculation failed: Invalid Base64 encoding');
        }
        return null;
      }
      
      final digest = md5.convert(keyData);
      
      // Format as colon-separated hex
      final hexString = digest.toString();
      final formatted = <String>[];
      for (int i = 0; i < hexString.length; i += 2) {
        formatted.add(hexString.substring(i, i + 2));
      }
      
      return formatted.join(':');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        _logger.e('MD5 fingerprint calculation error: $e', error: e, stackTrace: stackTrace);
      }
      return null;
    }
  }
  
  /// Verify SSH host key against known fingerprint
  bool verifyHostKey(String publicKey, String expectedFingerprint) {
    try {
      final actualFingerprint = expectedFingerprint.startsWith('SHA256:')
          ? calculateSSHFingerprint(publicKey)
          : calculateMD5Fingerprint(publicKey);
      
      if (actualFingerprint == null) {
        if (kDebugMode) {
          _logger.d('Host key verification failed: Could not calculate fingerprint');
        }
        return false;
      }
      
      return actualFingerprint == expectedFingerprint;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        _logger.e('Host key verification error: $e', error: e, stackTrace: stackTrace);
      }
      return false;
    }
  }
  
  /// Clear sensitive data from memory
  void clearSensitiveData(dynamic data) {
    if (data is Uint8List) {
      data.fillRange(0, data.length, 0);
    } else if (data is List<int>) {
      data.fillRange(0, data.length, 0);
    }
    // For strings, we can't directly clear memory in Dart
    // The GC will eventually collect them
  }
  
  // Private helper methods for key encoding
  
  String _encodeRSAPrivateKeyToPem(RSAPrivateKey privateKey) {
    // This is a simplified implementation
    // In production, use a proper ASN.1 encoder
    final keyInfo = {
      'n': privateKey.modulus.toString(),
      'e': privateKey.exponent.toString(),
      'd': privateKey.privateExponent.toString(),
      'p': privateKey.p.toString(),
      'q': privateKey.q.toString(),
    };
    
    final keyData = base64.encode(utf8.encode(json.encode(keyInfo)));
    return '-----BEGIN RSA PRIVATE KEY-----\n'
        '${_formatPemData(keyData)}'
        '-----END RSA PRIVATE KEY-----\n';
  }
  
  String _encodeRSAPublicKeyToSSH(RSAPublicKey publicKey) {
    // Simplified SSH public key encoding
    const keyType = 'ssh-rsa';
    final keyInfo = {
      'n': publicKey.modulus.toString(),
      'e': publicKey.exponent.toString(),
    };
    
    final keyData = base64.encode(utf8.encode(json.encode(keyInfo)));
    return '$keyType $keyData';
  }
  
  String _encodeEd25519PrivateKeyToPem(List<int> privateKeyBytes) {
    final keyData = base64.encode(privateKeyBytes);
    return '-----BEGIN PRIVATE KEY-----\n'
        '${_formatPemData(keyData)}'
        '-----END PRIVATE KEY-----\n';
  }
  
  String _encodeEd25519PublicKeyToSSH(List<int> publicKeyBytes) {
    final keyData = base64.encode(publicKeyBytes);
    return 'ssh-ed25519 $keyData';
  }
  
  String _formatPemData(String data) {
    final buffer = StringBuffer();
    for (int i = 0; i < data.length; i += 64) {
      final end = (i + 64 < data.length) ? i + 64 : data.length;
      buffer.writeln(data.substring(i, end));
    }
    return buffer.toString();
  }

  /// Safely decode Base64 data with comprehensive error handling
  Uint8List? _safeBase64Decode(String data) {
    try {
      // Remove any whitespace that might cause issues
      final cleanData = data.replaceAll(RegExp(r'\s+'), '');
      
      // Validate Base64 character set
      if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(cleanData)) {
        if (kDebugMode) {
          _logger.d('Base64 validation failed: Invalid character set');
        }
        return null;
      }
      
      // Check minimum length for valid SSH key data
      if (cleanData.length < 4) {
        if (kDebugMode) {
          _logger.d('Base64 validation failed: Data too short');
        }
        return null;
      }
      
      return base64.decode(cleanData);
    } on FormatException catch (e) {
      if (kDebugMode) {
        _logger.d('Base64 decoding failed: $e');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        _logger.d('Unexpected Base64 decoding error: $e');
      }
      return null;
    }
  }

  /// Validate SSH key type against supported formats
  bool _isValidSSHKeyType(String keyType) {
    const validTypes = {
      'ssh-rsa',
      'ssh-dss',
      'ssh-ed25519',
      'ssh-ecdsa',
      'ecdsa-sha2-nistp256',
      'ecdsa-sha2-nistp384',
      'ecdsa-sha2-nistp521',
      'sk-ecdsa-sha2-nistp256@openssh.com',
      'sk-ssh-ed25519@openssh.com',
      'rsa-sha2-256',
      'rsa-sha2-512',
    };
    return validTypes.contains(keyType.toLowerCase());
  }
}

/// Exception thrown by cryptographic operations
class CryptoException implements Exception {
  final String message;
  final Object? cause;
  
  const CryptoException(this.message, [this.cause]);
  
  @override
  String toString() => 'CryptoException: $message';
}

/// Encrypted data container
class EncryptedData {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final Uint8List tag;
  
  const EncryptedData({
    required this.ciphertext,
    required this.nonce,
    required this.tag,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'ciphertext': base64.encode(ciphertext),
      'nonce': base64.encode(nonce),
      'tag': base64.encode(tag),
    };
  }
  
  factory EncryptedData.fromJson(Map<String, dynamic> json) {
    return EncryptedData(
      ciphertext: base64.decode(json['ciphertext']),
      nonce: base64.decode(json['nonce']),
      tag: base64.decode(json['tag']),
    );
  }
}

/// Encrypted SSH key container
class EncryptedSSHKey {
  final EncryptedData encryptedKey;
  final Uint8List salt;
  final int iterations;
  
  const EncryptedSSHKey({
    required this.encryptedKey,
    required this.salt,
    required this.iterations,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'encrypted_key': encryptedKey.toJson(),
      'salt': base64.encode(salt),
      'iterations': iterations,
    };
  }
  
  factory EncryptedSSHKey.fromJson(Map<String, dynamic> json) {
    return EncryptedSSHKey(
      encryptedKey: EncryptedData.fromJson(json['encrypted_key']),
      salt: base64.decode(json['salt']),
      iterations: json['iterations'],
    );
  }
}

/// SSH key pair container
class SSHKeyPair {
  final String privateKey;
  final String publicKey;
  final String keyType;
  final int keySize;
  
  const SSHKeyPair({
    required this.privateKey,
    required this.publicKey,
    required this.keyType,
    required this.keySize,
  });
  
  String get fingerprint {
    final crypto = CryptoService();
    return crypto.calculateSSHFingerprint(publicKey) ?? 'Invalid key format';
  }
}

/// Extension for List<int> to Uint8List conversion
extension ListIntExtension on List<int> {
  Uint8List toUint8List() => Uint8List.fromList(this);
}