import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide SecureRandom;
import 'package:cryptography/cryptography.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

/// Comprehensive cryptographic service for DevPocket
/// Handles key generation, encryption, decryption, and digital signatures
class CryptoService {
  static const int _saltLength = 32;
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits for AES
  static const int _iterations = 100000; // PBKDF2 iterations
  
  final SecureRandom _secureRandom;
  
  CryptoService() : _secureRandom = SecureRandom('Fortuna') {
    // Initialize secure random with entropy
    final seed = Uint8List(32);
    final random = Random.secure();
    for (int i = 0; i < seed.length; i++) {
      seed[i] = random.nextInt(256);
    }
    _secureRandom.seed(KeyParameter(seed));
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
  
  /// Calculate SSH host key fingerprint (SHA256)
  String calculateSSHFingerprint(String publicKey) {
    // Remove SSH key prefix and decode base64
    final parts = publicKey.trim().split(' ');
    if (parts.length < 2) {
      throw ArgumentError('Invalid SSH public key format');
    }
    
    final keyData = base64.decode(parts[1]);
    final digest = sha256.convert(keyData);
    
    // Format as SHA256 fingerprint
    final fingerprintBytes = digest.bytes;
    final fingerprint = base64.encode(fingerprintBytes);
    
    return 'SHA256:$fingerprint';
  }
  
  /// Calculate MD5 fingerprint (legacy support)
  String calculateMD5Fingerprint(String publicKey) {
    final parts = publicKey.trim().split(' ');
    if (parts.length < 2) {
      throw ArgumentError('Invalid SSH public key format');
    }
    
    final keyData = base64.decode(parts[1]);
    final digest = md5.convert(keyData);
    
    // Format as colon-separated hex
    final hexString = digest.toString();
    final formatted = <String>[];
    for (int i = 0; i < hexString.length; i += 2) {
      formatted.add(hexString.substring(i, i + 2));
    }
    
    return formatted.join(':');
  }
  
  /// Verify SSH host key against known fingerprint
  bool verifyHostKey(String publicKey, String expectedFingerprint) {
    final actualFingerprint = expectedFingerprint.startsWith('SHA256:')
        ? calculateSSHFingerprint(publicKey)
        : calculateMD5Fingerprint(publicKey);
    
    return actualFingerprint == expectedFingerprint;
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
    final keyType = 'ssh-rsa';
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
    return crypto.calculateSSHFingerprint(publicKey);
  }
}

/// Extension for List<int> to Uint8List conversion
extension ListIntExtension on List<int> {
  Uint8List toUint8List() => Uint8List.fromList(this);
}