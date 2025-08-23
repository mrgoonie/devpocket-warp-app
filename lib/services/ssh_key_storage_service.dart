import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import '../models/ssh_models.dart';
import 'ssh_key_generation_service.dart';

/// SSH Key Storage Service with encryption
class SshKeyStorageService {
  static SshKeyStorageService? _instance;
  static SshKeyStorageService get instance => _instance ??= SshKeyStorageService._();

  SshKeyStorageService._();

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _keyPrefix = 'ssh_key_';
  static const String _metadataPrefix = 'ssh_meta_';
  static const String _keyListKey = 'ssh_key_list';

  /// Store SSH key pair with encryption
  Future<String> storeKeyPair({
    required SshKeyGenerationResult keyResult,
    required String name,
    String? passphrase,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Storing SSH key pair: $name');
      
      final keyId = _generateKeyId();
      final encryptionKey = _generateEncryptionKey();
      
      // Encrypt private key with additional passphrase if provided
      final encryptedPrivateKey = await _encryptPrivateKey(
        keyResult.privateKey,
        encryptionKey,
        passphrase,
      );
      
      // Create key record
      final keyRecord = SshKeyRecord(
        id: keyId,
        name: name,
        keyType: keyResult.keyType,
        publicKey: keyResult.publicKey,
        fingerprint: keyResult.fingerprint,
        createdAt: keyResult.createdAt,
        lastUsed: null,
        hasPassphrase: passphrase != null,
        metadata: metadata ?? {},
      );
      
      // Store encrypted private key
      await _secureStorage.write(
        key: '$_keyPrefix$keyId',
        value: json.encode({
          'privateKey': encryptedPrivateKey,
          'encryptionKey': base64Encode(encryptionKey),
          'salt': base64Encode(_generateSalt()),
        }),
      );
      
      // Store metadata
      await _secureStorage.write(
        key: '$_metadataPrefix$keyId',
        value: json.encode(keyRecord.toJson()),
      );
      
      // Update key list
      await _updateKeyList(keyId);
      
      debugPrint('SSH key pair stored successfully: $keyId');
      return keyId;
      
    } catch (e) {
      debugPrint('Failed to store SSH key pair: $e');
      throw Exception('Key storage failed: $e');
    }
  }

  /// Retrieve SSH key pair
  Future<SshKeyPair?> getKeyPair(String keyId, {String? passphrase}) async {
    try {
      debugPrint('Retrieving SSH key pair: $keyId');
      
      // Get metadata
      final metadataJson = await _secureStorage.read(key: '$_metadataPrefix$keyId');
      if (metadataJson == null) {
        debugPrint('Key metadata not found: $keyId');
        return null;
      }
      
      final keyRecord = SshKeyRecord.fromJson(json.decode(metadataJson));
      
      // Get encrypted private key
      final keyDataJson = await _secureStorage.read(key: '$_keyPrefix$keyId');
      if (keyDataJson == null) {
        debugPrint('Private key data not found: $keyId');
        return null;
      }
      
      final keyData = json.decode(keyDataJson);
      final encryptedPrivateKey = keyData['privateKey'] as String;
      final encryptionKey = base64Decode(keyData['encryptionKey'] as String);
      
      // Decrypt private key
      final privateKey = await _decryptPrivateKey(
        encryptedPrivateKey,
        encryptionKey,
        keyRecord.hasPassphrase ? passphrase : null,
      );
      
      // Update last used timestamp
      await _updateLastUsed(keyId);
      
      return SshKeyPair(
        record: keyRecord,
        privateKey: privateKey,
      );
      
    } catch (e) {
      debugPrint('Failed to retrieve SSH key pair: $e');
      return null;
    }
  }

  /// Get all stored SSH key records (metadata only)
  Future<List<SshKeyRecord>> getAllKeyRecords() async {
    try {
      final keyListJson = await _secureStorage.read(key: _keyListKey);
      if (keyListJson == null) return [];
      
      final keyIds = List<String>.from(json.decode(keyListJson));
      final keyRecords = <SshKeyRecord>[];
      
      for (final keyId in keyIds) {
        final metadataJson = await _secureStorage.read(key: '$_metadataPrefix$keyId');
        if (metadataJson != null) {
          keyRecords.add(SshKeyRecord.fromJson(json.decode(metadataJson)));
        }
      }
      
      // Sort by creation date (newest first)
      keyRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return keyRecords;
      
    } catch (e) {
      debugPrint('Failed to get SSH key records: $e');
      return [];
    }
  }

  /// Delete SSH key pair
  Future<bool> deleteKeyPair(String keyId) async {
    try {
      debugPrint('Deleting SSH key pair: $keyId');
      
      // Delete private key data
      await _secureStorage.delete(key: '$_keyPrefix$keyId');
      
      // Delete metadata
      await _secureStorage.delete(key: '$_metadataPrefix$keyId');
      
      // Update key list
      await _removeFromKeyList(keyId);
      
      debugPrint('SSH key pair deleted successfully: $keyId');
      return true;
      
    } catch (e) {
      debugPrint('Failed to delete SSH key pair: $e');
      return false;
    }
  }

  /// Update key metadata
  Future<bool> updateKeyMetadata(String keyId, {
    String? name,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final metadataJson = await _secureStorage.read(key: '$_metadataPrefix$keyId');
      if (metadataJson == null) return false;
      
      final keyRecord = SshKeyRecord.fromJson(json.decode(metadataJson));
      final updatedRecord = keyRecord.copyWith(
        name: name ?? keyRecord.name,
        metadata: metadata ?? keyRecord.metadata,
      );
      
      await _secureStorage.write(
        key: '$_metadataPrefix$keyId',
        value: json.encode(updatedRecord.toJson()),
      );
      
      return true;
      
    } catch (e) {
      debugPrint('Failed to update key metadata: $e');
      return false;
    }
  }

  /// Validate key passphrase
  Future<bool> validatePassphrase(String keyId, String passphrase) async {
    try {
      final keyPair = await getKeyPair(keyId, passphrase: passphrase);
      return keyPair != null;
    } catch (e) {
      return false;
    }
  }

  /// Export public key
  Future<String?> exportPublicKey(String keyId) async {
    try {
      final metadataJson = await _secureStorage.read(key: '$_metadataPrefix$keyId');
      if (metadataJson == null) return null;
      
      final keyRecord = SshKeyRecord.fromJson(json.decode(metadataJson));
      return keyRecord.publicKey;
      
    } catch (e) {
      debugPrint('Failed to export public key: $e');
      return null;
    }
  }

  /// Import existing key pair
  Future<String?> importKeyPair({
    required String name,
    required String publicKey,
    required String privateKey,
    String? passphrase,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Importing SSH key pair: $name');
      
      // Validate key format
      final keyGenService = SshKeyGenerationService.instance;
      if (!keyGenService.validateKeyFormat(publicKey, isPrivate: false) ||
          !keyGenService.validateKeyFormat(privateKey, isPrivate: true)) {
        throw Exception('Invalid key format');
      }
      
      // Generate fingerprint
      final fingerprint = _generateFingerprint(publicKey);
      
      // Detect key type
      final keyType = keyGenService.getKeyTypeFromPublicKey(publicKey) ?? 
                     SshKeyType.rsa4096; // Default fallback
      
      // Create generation result for storage
      final keyResult = SshKeyGenerationResult(
        publicKey: publicKey,
        privateKey: privateKey,
        fingerprint: fingerprint,
        keyType: keyType,
        createdAt: DateTime.now(),
      );
      
      return await storeKeyPair(
        keyResult: keyResult,
        name: name,
        passphrase: passphrase,
        metadata: metadata,
      );
      
    } catch (e) {
      debugPrint('Failed to import SSH key pair: $e');
      throw Exception('Key import failed: $e');
    }
  }

  /// Get key statistics
  Future<Map<String, dynamic>> getKeyStatistics() async {
    try {
      final keyRecords = await getAllKeyRecords();
      final now = DateTime.now();
      
      final stats = <String, dynamic>{
        'totalKeys': keyRecords.length,
        'keysByType': <String, int>{},
        'recentlyUsed': 0,
        'withPassphrase': 0,
        'oldestKey': null,
        'newestKey': null,
      };
      
      if (keyRecords.isEmpty) return stats;
      
      for (final record in keyRecords) {
        // Count by type
        final typeName = record.keyType.displayName;
        stats['keysByType'][typeName] = (stats['keysByType'][typeName] ?? 0) + 1;
        
        // Count with passphrase
        if (record.hasPassphrase) {
          stats['withPassphrase']++;
        }
        
        // Count recently used (within 30 days)
        if (record.lastUsed != null && 
            now.difference(record.lastUsed!).inDays <= 30) {
          stats['recentlyUsed']++;
        }
        
        // Track oldest and newest
        if (stats['oldestKey'] == null || 
            record.createdAt.isBefore(stats['oldestKey'])) {
          stats['oldestKey'] = record.createdAt.toIso8601String();
        }
        
        if (stats['newestKey'] == null || 
            record.createdAt.isAfter(stats['newestKey'])) {
          stats['newestKey'] = record.createdAt.toIso8601String();
        }
      }
      
      return stats;
      
    } catch (e) {
      debugPrint('Failed to get key statistics: $e');
      return {'totalKeys': 0, 'error': e.toString()};
    }
  }

  /// Cleanup expired or unused keys
  Future<int> cleanupOldKeys({int maxAgeInDays = 365}) async {
    try {
      final keyRecords = await getAllKeyRecords();
      final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeInDays));
      int deletedCount = 0;
      
      for (final record in keyRecords) {
        final shouldDelete = record.lastUsed == null 
            ? record.createdAt.isBefore(cutoffDate)
            : record.lastUsed!.isBefore(cutoffDate);
        
        if (shouldDelete) {
          final deleted = await deleteKeyPair(record.id);
          if (deleted) deletedCount++;
        }
      }
      
      debugPrint('Cleaned up $deletedCount old SSH keys');
      return deletedCount;
      
    } catch (e) {
      debugPrint('Failed to cleanup old keys: $e');
      return 0;
    }
  }

  /// Generate unique key ID
  String _generateKeyId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(999999);
    return 'key_${timestamp}_$random';
  }

  /// Generate encryption key
  Uint8List _generateEncryptionKey() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(32, (i) => random.nextInt(256)));
  }

  /// Generate salt for encryption
  Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(16, (i) => random.nextInt(256)));
  }

  /// Encrypt private key with AES-256-GCM
  Future<String> _encryptPrivateKey(
    String privateKey,
    Uint8List encryptionKey,
    String? passphrase,
  ) async {
    try {
      final plaintext = utf8.encode(privateKey);
      final cipher = GCMBlockCipher(AESEngine());
      final iv = _generateSalt(); // 16 bytes IV for GCM
      
      // If passphrase is provided, derive additional key
      Uint8List finalKey = encryptionKey;
      if (passphrase != null) {
        final passphraseBytes = utf8.encode(passphrase);
        final combined = Uint8List(encryptionKey.length + passphraseBytes.length);
        combined.setRange(0, encryptionKey.length, encryptionKey);
        combined.setRange(encryptionKey.length, combined.length, passphraseBytes);
        finalKey = Uint8List.fromList(sha256.convert(combined).bytes);
      }
      
      final params = AEADParameters(
        KeyParameter(finalKey),
        128, // 128-bit authentication tag
        iv,
        Uint8List(0), // No additional authenticated data
      );
      
      cipher.init(true, params);
      
      final encrypted = cipher.process(Uint8List.fromList(plaintext));
      
      // Combine IV + encrypted data + auth tag
      final result = Uint8List(iv.length + encrypted.length);
      result.setRange(0, iv.length, iv);
      result.setRange(iv.length, result.length, encrypted);
      
      return base64Encode(result);
      
    } catch (e) {
      debugPrint('Private key encryption failed: $e');
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt private key
  Future<String> _decryptPrivateKey(
    String encryptedPrivateKey,
    Uint8List encryptionKey,
    String? passphrase,
  ) async {
    try {
      final encryptedData = base64Decode(encryptedPrivateKey);
      final iv = encryptedData.sublist(0, 16);
      final ciphertext = encryptedData.sublist(16);
      
      final cipher = GCMBlockCipher(AESEngine());
      
      // Reconstruct key with passphrase if provided
      Uint8List finalKey = encryptionKey;
      if (passphrase != null) {
        final passphraseBytes = utf8.encode(passphrase);
        final combined = Uint8List(encryptionKey.length + passphraseBytes.length);
        combined.setRange(0, encryptionKey.length, encryptionKey);
        combined.setRange(encryptionKey.length, combined.length, passphraseBytes);
        finalKey = Uint8List.fromList(sha256.convert(combined).bytes);
      }
      
      final params = AEADParameters(
        KeyParameter(finalKey),
        128, // 128-bit authentication tag
        iv,
        Uint8List(0), // No additional authenticated data
      );
      
      cipher.init(false, params);
      
      final decrypted = cipher.process(ciphertext);
      return utf8.decode(decrypted);
      
    } catch (e) {
      debugPrint('Private key decryption failed: $e');
      throw Exception('Decryption failed: $e');
    }
  }

  /// Generate fingerprint from public key
  String _generateFingerprint(String publicKey) {
    try {
      final parts = publicKey.split(' ');
      if (parts.length < 2) {
        throw Exception('Invalid public key format');
      }
      
      final keyData = base64Decode(parts[1]);
      final hash = sha256.convert(keyData);
      
      return 'SHA256:${base64Encode(hash.bytes).replaceAll('=', '')}';
      
    } catch (e) {
      debugPrint('Failed to generate fingerprint: $e');
      return 'SHA256:unknown';
    }
  }

  /// Update key list
  Future<void> _updateKeyList(String keyId) async {
    try {
      final keyListJson = await _secureStorage.read(key: _keyListKey);
      final keyIds = keyListJson != null 
          ? List<String>.from(json.decode(keyListJson))
          : <String>[];
      
      if (!keyIds.contains(keyId)) {
        keyIds.add(keyId);
        await _secureStorage.write(
          key: _keyListKey,
          value: json.encode(keyIds),
        );
      }
    } catch (e) {
      debugPrint('Failed to update key list: $e');
    }
  }

  /// Remove key from list
  Future<void> _removeFromKeyList(String keyId) async {
    try {
      final keyListJson = await _secureStorage.read(key: _keyListKey);
      if (keyListJson != null) {
        final keyIds = List<String>.from(json.decode(keyListJson));
        keyIds.remove(keyId);
        await _secureStorage.write(
          key: _keyListKey,
          value: json.encode(keyIds),
        );
      }
    } catch (e) {
      debugPrint('Failed to remove from key list: $e');
    }
  }

  /// Update last used timestamp
  Future<void> _updateLastUsed(String keyId) async {
    try {
      final metadataJson = await _secureStorage.read(key: '$_metadataPrefix$keyId');
      if (metadataJson != null) {
        final keyRecord = SshKeyRecord.fromJson(json.decode(metadataJson));
        final updatedRecord = keyRecord.copyWith(lastUsed: DateTime.now());
        
        await _secureStorage.write(
          key: '$_metadataPrefix$keyId',
          value: json.encode(updatedRecord.toJson()),
        );
      }
    } catch (e) {
      debugPrint('Failed to update last used: $e');
    }
  }
}