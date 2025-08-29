import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_service.dart';
import 'secure_storage_models.dart';
import 'biometric_auth_handler.dart';

/// Manages SSH private keys with encryption and biometric protection
class SSHKeyManager {
  static const String _sshKeyPrefix = 'ssh_key_';
  static const String _sshMetadataPrefix = 'ssh_meta_';

  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;
  final BiometricAuthHandler _biometricAuth;

  SSHKeyManager({
    required FlutterSecureStorage secureStorage,
    required CryptoService cryptoService,
    required BiometricAuthHandler biometricAuth,
  }) : _secureStorage = secureStorage,
       _cryptoService = cryptoService,
       _biometricAuth = biometricAuth;

  /// Store SSH private key with enhanced security
  Future<void> storeSSHKey({
    required String keyId,
    required String privateKey,
    required String passphrase,
    bool requireBiometric = true,
    String? description,
  }) async {
    try {
      debugPrint('🔐 Storing SSH key: $keyId');

      // Biometric check if required
      if (requireBiometric) {
        final authenticated = await _biometricAuth.authenticateForSSHKey(keyId);
        if (!authenticated) {
          throw const SecureStorageException('Biometric authentication required for SSH key');
        }
      }

      // Encrypt private key with passphrase
      final encryptedKey = await _cryptoService.encryptString(
        privateKey,
        passphrase,
      );

      // Create metadata
      final metadata = StorageMetadata(
        createdAt: DateTime.now(),
        lastAccessed: DateTime.now(),
        version: '1.0',
        description: description ?? 'SSH private key: $keyId',
        requiresBiometric: requireBiometric,
      );

      // Store encrypted key and metadata
      await _secureStorage.write(
        key: '$_sshKeyPrefix$keyId',
        value: base64.encode(encryptedKey),
      );
      
      await _secureStorage.write(
        key: '$_sshMetadataPrefix$keyId',
        value: json.encode(metadata.toJson()),
      );

      debugPrint('✅ SSH key stored successfully: $keyId');
    } catch (e) {
      debugPrint('❌ Failed to store SSH key: $e');
      throw SecureStorageException('Failed to store SSH key: $e');
    }
  }

  /// Retrieve SSH private key
  Future<String?> getSSHKey(String keyId, String passphrase) async {
    try {
      debugPrint('🔓 Retrieving SSH key: $keyId');

      // Get metadata first to check biometric requirement
      final metadataJson = await _secureStorage.read(key: '$_sshMetadataPrefix$keyId');
      if (metadataJson != null) {
        final metadata = StorageMetadata.fromJson(json.decode(metadataJson));
        
        // Biometric check if required
        if (metadata.requiresBiometric) {
          final authenticated = await _biometricAuth.authenticateForSSHKey(keyId);
          if (!authenticated) {
            throw const SecureStorageException('Biometric authentication required');
          }
        }
      }

      // Retrieve encrypted key
      final encryptedKeyBase64 = await _secureStorage.read(key: '$_sshKeyPrefix$keyId');
      if (encryptedKeyBase64 == null) {
        debugPrint('⚠️ SSH key not found: $keyId');
        return null;
      }

      final encryptedKey = base64.decode(encryptedKeyBase64);
      
      // Decrypt with passphrase
      final decryptedKey = await _cryptoService.decryptString(
        encryptedKey,
        passphrase,
      );

      // Update last accessed time
      await _updateSSHKeyAccessTime(keyId);

      debugPrint('✅ SSH key retrieved successfully: $keyId');
      return decryptedKey;
    } catch (e) {
      debugPrint('❌ Failed to retrieve SSH key: $e');
      throw SecureStorageException('Failed to retrieve SSH key: $e');
    }
  }

  /// List stored SSH keys
  Future<List<String>> listSSHKeys() async {
    try {
      final allKeys = await _secureStorage.readAll();
      final sshKeys = <String>[];

      for (final key in allKeys.keys) {
        if (key.startsWith(_sshKeyPrefix)) {
          final keyId = key.substring(_sshKeyPrefix.length);
          sshKeys.add(keyId);
        }
      }

      debugPrint('📋 Found ${sshKeys.length} SSH keys');
      return sshKeys;
    } catch (e) {
      debugPrint('❌ Failed to list SSH keys: $e');
      throw SecureStorageException('Failed to list SSH keys: $e');
    }
  }

  /// Get SSH key metadata
  Future<StorageMetadata?> getSSHKeyMetadata(String keyId) async {
    try {
      final metadataJson = await _secureStorage.read(key: '$_sshMetadataPrefix$keyId');
      if (metadataJson == null) return null;

      return StorageMetadata.fromJson(json.decode(metadataJson));
    } catch (e) {
      debugPrint('❌ Failed to get SSH key metadata: $e');
      return null;
    }
  }

  /// Delete SSH key
  Future<void> deleteSSHKey(String keyId) async {
    try {
      debugPrint('🗑️ Deleting SSH key: $keyId');

      // Check if key exists and requires biometric
      final metadata = await getSSHKeyMetadata(keyId);
      if (metadata?.requiresBiometric == true) {
        final authenticated = await _biometricAuth.authenticateForSSHKey(keyId);
        if (!authenticated) {
          throw const SecureStorageException('Biometric authentication required');
        }
      }

      // Delete key and metadata
      await _secureStorage.delete(key: '$_sshKeyPrefix$keyId');
      await _secureStorage.delete(key: '$_sshMetadataPrefix$keyId');

      debugPrint('✅ SSH key deleted successfully: $keyId');
    } catch (e) {
      debugPrint('❌ Failed to delete SSH key: $e');
      throw SecureStorageException('Failed to delete SSH key: $e');
    }
  }

  /// Check if SSH key exists
  Future<bool> hasSSHKey(String keyId) async {
    try {
      final encryptedKey = await _secureStorage.read(key: '$_sshKeyPrefix$keyId');
      return encryptedKey != null;
    } catch (e) {
      debugPrint('❌ Failed to check SSH key existence: $e');
      return false;
    }
  }

  /// Update SSH key passphrase
  Future<void> updateSSHKeyPassphrase({
    required String keyId,
    required String oldPassphrase,
    required String newPassphrase,
  }) async {
    try {
      debugPrint('🔄 Updating SSH key passphrase: $keyId');

      // Retrieve and decrypt with old passphrase
      final privateKey = await getSSHKey(keyId, oldPassphrase);
      if (privateKey == null) {
        throw const SecureStorageException('SSH key not found or invalid passphrase');
      }

      // Get current metadata
      final metadata = await getSSHKeyMetadata(keyId);
      
      // Re-encrypt with new passphrase
      final encryptedKey = await _cryptoService.encryptString(
        privateKey,
        newPassphrase,
      );

      // Store with updated metadata
      await _secureStorage.write(
        key: '$_sshKeyPrefix$keyId',
        value: base64.encode(encryptedKey),
      );

      if (metadata != null) {
        final updatedMetadata = StorageMetadata(
          createdAt: metadata.createdAt,
          lastAccessed: DateTime.now(),
          version: metadata.version,
          description: metadata.description,
          requiresBiometric: metadata.requiresBiometric,
        );

        await _secureStorage.write(
          key: '$_sshMetadataPrefix$keyId',
          value: json.encode(updatedMetadata.toJson()),
        );
      }

      debugPrint('✅ SSH key passphrase updated successfully: $keyId');
    } catch (e) {
      debugPrint('❌ Failed to update SSH key passphrase: $e');
      throw SecureStorageException('Failed to update SSH key passphrase: $e');
    }
  }

  /// Update SSH key access time
  Future<void> _updateSSHKeyAccessTime(String keyId) async {
    try {
      final metadataJson = await _secureStorage.read(key: '$_sshMetadataPrefix$keyId');
      if (metadataJson != null) {
        final metadata = StorageMetadata.fromJson(json.decode(metadataJson));
        final updatedMetadata = StorageMetadata(
          createdAt: metadata.createdAt,
          lastAccessed: DateTime.now(),
          version: metadata.version,
          description: metadata.description,
          requiresBiometric: metadata.requiresBiometric,
        );

        await _secureStorage.write(
          key: '$_sshMetadataPrefix$keyId',
          value: json.encode(updatedMetadata.toJson()),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to update SSH key access time: $e');
      // Non-critical error, don't throw
    }
  }

  /// Get SSH key statistics
  Future<Map<String, dynamic>> getSSHKeyStatistics() async {
    try {
      final keys = await listSSHKeys();
      int biometricProtected = 0;
      DateTime? oldestKey;
      DateTime? newestKey;

      for (final keyId in keys) {
        final metadata = await getSSHKeyMetadata(keyId);
        if (metadata != null) {
          if (metadata.requiresBiometric) biometricProtected++;
          
          if (oldestKey == null || metadata.createdAt.isBefore(oldestKey)) {
            oldestKey = metadata.createdAt;
          }
          
          if (newestKey == null || metadata.createdAt.isAfter(newestKey)) {
            newestKey = metadata.createdAt;
          }
        }
      }

      return {
        'totalKeys': keys.length,
        'biometricProtected': biometricProtected,
        'oldestKey': oldestKey?.toIso8601String(),
        'newestKey': newestKey?.toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Failed to get SSH key statistics: $e');
      return {'error': e.toString()};
    }
  }
}