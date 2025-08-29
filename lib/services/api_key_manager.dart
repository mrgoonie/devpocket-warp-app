import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_service.dart';
import 'secure_storage_models.dart';
import 'biometric_auth_handler.dart';

/// Manages API keys with encryption and optional biometric protection
class APIKeyManager {
  static const String _apiKeyPrefix = 'api_key_';
  static const String _apiMetadataPrefix = 'api_meta_';

  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;
  final BiometricAuthHandler _biometricAuth;

  APIKeyManager({
    required FlutterSecureStorage secureStorage,
    required CryptoService cryptoService,
    required BiometricAuthHandler biometricAuth,
  }) : _secureStorage = secureStorage,
       _cryptoService = cryptoService,
       _biometricAuth = biometricAuth;

  /// Store API key with encryption
  Future<void> storeAPIKey({
    required String keyName,
    required String apiKey,
    bool requireBiometric = false,
    String? description,
    String? provider,
  }) async {
    try {
      debugPrint('🔐 Storing API key: $keyName');

      // Biometric check if required
      if (requireBiometric) {
        final authenticated = await _biometricAuth.authenticateForAPIKey(keyName);
        if (!authenticated) {
          throw const SecureStorageException('Biometric authentication required for API key');
        }
      }

      // Encrypt API key
      final encryptedKey = await _cryptoService.encryptWithDeviceKey(apiKey);

      // Create metadata
      final metadata = StorageMetadata(
        createdAt: DateTime.now(),
        lastAccessed: DateTime.now(),
        version: '1.0',
        description: description ?? 'API key: $keyName',
        requiresBiometric: requireBiometric,
      );

      // Store encrypted key and metadata
      await _secureStorage.write(
        key: '$_apiKeyPrefix$keyName',
        value: base64.encode(encryptedKey),
      );

      final metadataMap = metadata.toJson();
      if (provider != null) {
        metadataMap['provider'] = provider;
      }
      
      await _secureStorage.write(
        key: '$_apiMetadataPrefix$keyName',
        value: json.encode(metadataMap),
      );

      debugPrint('✅ API key stored successfully: $keyName');
    } catch (e) {
      debugPrint('❌ Failed to store API key: $e');
      throw SecureStorageException('Failed to store API key: $e');
    }
  }

  /// Retrieve API key
  Future<String?> getAPIKey(String keyName) async {
    try {
      debugPrint('🔓 Retrieving API key: $keyName');

      // Get metadata first to check biometric requirement
      final metadataJson = await _secureStorage.read(key: '$_apiMetadataPrefix$keyName');
      if (metadataJson != null) {
        final metadataMap = json.decode(metadataJson) as Map<String, dynamic>;
        final metadata = StorageMetadata.fromJson(metadataMap);
        
        // Biometric check if required
        if (metadata.requiresBiometric) {
          final authenticated = await _biometricAuth.authenticateForAPIKey(keyName);
          if (!authenticated) {
            throw const SecureStorageException('Biometric authentication required');
          }
        }
      }

      // Retrieve encrypted key
      final encryptedKeyBase64 = await _secureStorage.read(key: '$_apiKeyPrefix$keyName');
      if (encryptedKeyBase64 == null) {
        debugPrint('⚠️ API key not found: $keyName');
        return null;
      }

      final encryptedKey = base64.decode(encryptedKeyBase64);
      
      // Decrypt API key
      final decryptedKey = await _cryptoService.decryptWithDeviceKey(encryptedKey);

      // Update last accessed time
      await _updateAPIKeyAccessTime(keyName);

      debugPrint('✅ API key retrieved successfully: $keyName');
      return decryptedKey;
    } catch (e) {
      debugPrint('❌ Failed to retrieve API key: $e');
      throw SecureStorageException('Failed to retrieve API key: $e');
    }
  }

  /// List stored API keys
  Future<List<String>> listAPIKeys() async {
    try {
      final allKeys = await _secureStorage.readAll();
      final apiKeys = <String>[];

      for (final key in allKeys.keys) {
        if (key.startsWith(_apiKeyPrefix)) {
          final keyName = key.substring(_apiKeyPrefix.length);
          apiKeys.add(keyName);
        }
      }

      debugPrint('📋 Found ${apiKeys.length} API keys');
      return apiKeys;
    } catch (e) {
      debugPrint('❌ Failed to list API keys: $e');
      throw SecureStorageException('Failed to list API keys: $e');
    }
  }

  /// Get API key metadata with provider information
  Future<Map<String, dynamic>?> getAPIKeyMetadata(String keyName) async {
    try {
      final metadataJson = await _secureStorage.read(key: '$_apiMetadataPrefix$keyName');
      if (metadataJson == null) return null;

      return json.decode(metadataJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Failed to get API key metadata: $e');
      return null;
    }
  }

  /// Delete API key
  Future<void> deleteAPIKey(String keyName) async {
    try {
      debugPrint('🗑️ Deleting API key: $keyName');

      // Check if key exists and requires biometric
      final metadataMap = await getAPIKeyMetadata(keyName);
      if (metadataMap != null) {
        final metadata = StorageMetadata.fromJson(metadataMap);
        if (metadata.requiresBiometric) {
          final authenticated = await _biometricAuth.authenticateForAPIKey(keyName);
          if (!authenticated) {
            throw const SecureStorageException('Biometric authentication required');
          }
        }
      }

      // Delete key and metadata
      await _secureStorage.delete(key: '$_apiKeyPrefix$keyName');
      await _secureStorage.delete(key: '$_apiMetadataPrefix$keyName');

      debugPrint('✅ API key deleted successfully: $keyName');
    } catch (e) {
      debugPrint('❌ Failed to delete API key: $e');
      throw SecureStorageException('Failed to delete API key: $e');
    }
  }

  /// Check if API key exists
  Future<bool> hasAPIKey(String keyName) async {
    try {
      final encryptedKey = await _secureStorage.read(key: '$_apiKeyPrefix$keyName');
      return encryptedKey != null;
    } catch (e) {
      debugPrint('❌ Failed to check API key existence: $e');
      return false;
    }
  }

  /// Update API key
  Future<void> updateAPIKey({
    required String keyName,
    required String newApiKey,
    String? description,
    String? provider,
  }) async {
    try {
      debugPrint('🔄 Updating API key: $keyName');

      // Get current metadata
      final currentMetadata = await getAPIKeyMetadata(keyName);
      if (currentMetadata == null) {
        throw const SecureStorageException('API key not found');
      }

      final metadata = StorageMetadata.fromJson(currentMetadata);

      // Biometric check if required
      if (metadata.requiresBiometric) {
        final authenticated = await _biometricAuth.authenticateForAPIKey(keyName);
        if (!authenticated) {
          throw const SecureStorageException('Biometric authentication required');
        }
      }

      // Encrypt new API key
      final encryptedKey = await _cryptoService.encryptWithDeviceKey(newApiKey);

      // Update metadata
      final updatedMetadata = StorageMetadata(
        createdAt: metadata.createdAt,
        lastAccessed: DateTime.now(),
        version: metadata.version,
        description: description ?? metadata.description,
        requiresBiometric: metadata.requiresBiometric,
      );

      // Store updated key and metadata
      await _secureStorage.write(
        key: '$_apiKeyPrefix$keyName',
        value: base64.encode(encryptedKey),
      );

      final metadataMap = updatedMetadata.toJson();
      if (provider != null) {
        metadataMap['provider'] = provider;
      } else if (currentMetadata['provider'] != null) {
        metadataMap['provider'] = currentMetadata['provider'];
      }

      await _secureStorage.write(
        key: '$_apiMetadataPrefix$keyName',
        value: json.encode(metadataMap),
      );

      debugPrint('✅ API key updated successfully: $keyName');
    } catch (e) {
      debugPrint('❌ Failed to update API key: $e');
      throw SecureStorageException('Failed to update API key: $e');
    }
  }

  /// Update API key access time
  Future<void> _updateAPIKeyAccessTime(String keyName) async {
    try {
      final metadataJson = await _secureStorage.read(key: '$_apiMetadataPrefix$keyName');
      if (metadataJson != null) {
        final metadataMap = json.decode(metadataJson) as Map<String, dynamic>;
        final metadata = StorageMetadata.fromJson(metadataMap);
        
        final updatedMetadata = StorageMetadata(
          createdAt: metadata.createdAt,
          lastAccessed: DateTime.now(),
          version: metadata.version,
          description: metadata.description,
          requiresBiometric: metadata.requiresBiometric,
        );

        final updatedMap = updatedMetadata.toJson();
        if (metadataMap['provider'] != null) {
          updatedMap['provider'] = metadataMap['provider'];
        }

        await _secureStorage.write(
          key: '$_apiMetadataPrefix$keyName',
          value: json.encode(updatedMap),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to update API key access time: $e');
      // Non-critical error, don't throw
    }
  }

  /// Get API keys by provider
  Future<List<String>> getAPIKeysByProvider(String provider) async {
    try {
      final allKeys = await listAPIKeys();
      final providerKeys = <String>[];

      for (final keyName in allKeys) {
        final metadata = await getAPIKeyMetadata(keyName);
        if (metadata != null && metadata['provider'] == provider) {
          providerKeys.add(keyName);
        }
      }

      return providerKeys;
    } catch (e) {
      debugPrint('❌ Failed to get API keys by provider: $e');
      return [];
    }
  }

  /// Get API key statistics
  Future<Map<String, dynamic>> getAPIKeyStatistics() async {
    try {
      final keys = await listAPIKeys();
      int biometricProtected = 0;
      final providerCounts = <String, int>{};
      DateTime? oldestKey;
      DateTime? newestKey;

      for (final keyName in keys) {
        final metadataMap = await getAPIKeyMetadata(keyName);
        if (metadataMap != null) {
          final metadata = StorageMetadata.fromJson(metadataMap);
          
          if (metadata.requiresBiometric) biometricProtected++;
          
          final provider = metadataMap['provider'] as String? ?? 'unknown';
          providerCounts[provider] = (providerCounts[provider] ?? 0) + 1;
          
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
        'providerCounts': providerCounts,
        'oldestKey': oldestKey?.toIso8601String(),
        'newestKey': newestKey?.toIso8601String(),
      };
    } catch (e) {
      debugPrint('❌ Failed to get API key statistics: $e');
      return {'error': e.toString()};
    }
  }
}