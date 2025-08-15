import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import 'crypto_service.dart';

/// Enhanced secure storage service with multiple encryption layers
/// Provides device keychain integration, biometric protection, and encrypted storage
class SecureStorageService {
  static const String _deviceKeyPrefix = 'device_key_';
  static const String _encryptedDataPrefix = 'encrypted_';
  static const String _metadataPrefix = 'metadata_';
  
  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;
  final LocalAuthentication _localAuth;
  final DeviceInfoPlugin _deviceInfo;
  
  String? _deviceId;
  Uint8List? _deviceKey;
  
  SecureStorageService({
    FlutterSecureStorage? secureStorage,
    CryptoService? cryptoService,
    LocalAuthentication? localAuth,
    DeviceInfoPlugin? deviceInfo,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
            keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
            storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
          ),
          iOptions: IOSOptions(
            accessibility: KeychainAccessibility.first_unlock_this_device,
            accountName: 'DevPocket',
          ),
        ),
        _cryptoService = cryptoService ?? CryptoService(),
        _localAuth = localAuth ?? LocalAuthentication(),
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin();
  
  /// Initialize the secure storage service
  Future<void> initialize() async {
    await _initializeDeviceIdentity();
    await _initializeDeviceKey();
  }
  
  /// Store sensitive data with optional biometric protection
  Future<void> storeSecure({
    required String key,
    required String value,
    bool requireBiometric = false,
    Map<String, dynamic>? metadata,
  }) async {
    if (requireBiometric) {
      final authenticated = await _authenticateWithBiometrics();
      if (!authenticated) {
        throw SecureStorageException('Biometric authentication required');
      }
    }
    
    // Encrypt the value
    final encryptedData = await _encryptValue(value);
    
    // Store encrypted data
    await _secureStorage.write(
      key: '$_encryptedDataPrefix$key',
      value: json.encode(encryptedData.toJson()),
    );
    
    // Store metadata
    final storageMetadata = StorageMetadata(
      createdAt: DateTime.now(),
      requiresBiometric: requireBiometric,
      customMetadata: metadata ?? {},
    );
    
    await _secureStorage.write(
      key: '$_metadataPrefix$key',
      value: json.encode(storageMetadata.toJson()),
    );
  }
  
  /// Retrieve sensitive data with biometric check if required
  Future<String?> getSecure(String key) async {
    // Check metadata first
    final metadataJson = await _secureStorage.read(key: '$_metadataPrefix$key');
    if (metadataJson == null) return null;
    
    final metadata = StorageMetadata.fromJson(json.decode(metadataJson));
    
    // Require biometric authentication if needed
    if (metadata.requiresBiometric) {
      final authenticated = await _authenticateWithBiometrics();
      if (!authenticated) {
        throw SecureStorageException('Biometric authentication required');
      }
    }
    
    // Get encrypted data
    final encryptedJson = await _secureStorage.read(key: '$_encryptedDataPrefix$key');
    if (encryptedJson == null) return null;
    
    final encryptedData = EncryptedData.fromJson(json.decode(encryptedJson));
    
    // Decrypt and return
    return await _decryptValue(encryptedData);
  }
  
  /// Store SSH private key with enhanced security
  Future<void> storeSSHKey({
    required String keyId,
    required String privateKey,
    required String passphrase,
    bool requireBiometric = true,
  }) async {
    // Encrypt SSH key with passphrase
    final encryptedSSHKey = await _cryptoService.encryptSSHKey(
      privateKey,
      passphrase,
    );
    
    await storeSecure(
      key: 'ssh_key_$keyId',
      value: json.encode(encryptedSSHKey.toJson()),
      requireBiometric: requireBiometric,
      metadata: {
        'type': 'ssh_private_key',
        'key_id': keyId,
        'encrypted_with_passphrase': true,
      },
    );
    
    // Clear sensitive data from memory
    _cryptoService.clearSensitiveData(privateKey.codeUnits);
    _cryptoService.clearSensitiveData(passphrase.codeUnits);
  }
  
  /// Retrieve SSH private key
  Future<String?> getSSHKey(String keyId, String passphrase) async {
    final encryptedKeyJson = await getSecure('ssh_key_$keyId');
    if (encryptedKeyJson == null) return null;
    
    try {
      final encryptedSSHKey = EncryptedSSHKey.fromJson(json.decode(encryptedKeyJson));
      
      final privateKey = await _cryptoService.decryptSSHKey(
        encryptedSSHKey,
        passphrase,
      );
      
      return privateKey;
    } catch (e) {
      throw SecureStorageException('Failed to decrypt SSH key: $e');
    } finally {
      // Clear passphrase from memory
      _cryptoService.clearSensitiveData(passphrase.codeUnits);
    }
  }
  
  /// Store API key with encryption
  Future<void> storeAPIKey({
    required String keyName,
    required String apiKey,
    bool requireBiometric = false,
  }) async {
    await storeSecure(
      key: 'api_key_$keyName',
      value: apiKey,
      requireBiometric: requireBiometric,
      metadata: {
        'type': 'api_key',
        'key_name': keyName,
      },
    );
    
    // Clear API key from memory
    _cryptoService.clearSensitiveData(apiKey.codeUnits);
  }
  
  /// Retrieve API key
  Future<String?> getAPIKey(String keyName) async {
    return await getSecure('api_key_$keyName');
  }
  
  /// Store host fingerprints for SSH host key verification
  Future<void> storeHostFingerprint({
    required String hostname,
    required String fingerprint,
    required String keyType,
  }) async {
    final hostKey = HostKeyFingerprint(
      hostname: hostname,
      fingerprint: fingerprint,
      keyType: keyType,
      firstSeen: DateTime.now(),
      lastVerified: DateTime.now(),
    );
    
    await storeSecure(
      key: 'host_key_$hostname',
      value: json.encode(hostKey.toJson()),
      requireBiometric: false,
      metadata: {
        'type': 'host_fingerprint',
        'hostname': hostname,
      },
    );
  }
  
  /// Retrieve host fingerprint
  Future<HostKeyFingerprint?> getHostFingerprint(String hostname) async {
    final fingerprintJson = await getSecure('host_key_$hostname');
    if (fingerprintJson == null) return null;
    
    return HostKeyFingerprint.fromJson(json.decode(fingerprintJson));
  }
  
  /// Update host fingerprint verification time
  Future<void> updateHostFingerprintVerification(String hostname) async {
    final existingFingerprint = await getHostFingerprint(hostname);
    if (existingFingerprint != null) {
      final updatedFingerprint = existingFingerprint.copyWith(
        lastVerified: DateTime.now(),
      );
      
      await storeSecure(
        key: 'host_key_$hostname',
        value: json.encode(updatedFingerprint.toJson()),
        requireBiometric: false,
      );
    }
  }
  
  /// List all stored keys (for management purposes)
  Future<List<String>> listStoredKeys() async {
    final allKeys = await _secureStorage.readAll();
    
    return allKeys.keys
        .where((key) => key.startsWith(_encryptedDataPrefix))
        .map((key) => key.substring(_encryptedDataPrefix.length))
        .toList();
  }
  
  /// Delete stored key
  Future<void> deleteKey(String key) async {
    await _secureStorage.delete(key: '$_encryptedDataPrefix$key');
    await _secureStorage.delete(key: '$_metadataPrefix$key');
  }
  
  /// Clear all stored data (for logout/reset)
  Future<void> clearAll() async {
    await _secureStorage.deleteAll();
    _deviceKey = null;
  }
  
  /// Check if biometric authentication is available
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      
      return isAvailable && availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  // Private helper methods
  
  Future<void> _initializeDeviceIdentity() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'unknown-ios';
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      } else {
        _deviceId = 'unknown-device';
      }
    } catch (e) {
      _deviceId = 'fallback-device-id';
    }
  }
  
  Future<void> _initializeDeviceKey() async {
    final deviceKeyString = await _secureStorage.read(key: '$_deviceKeyPrefix$_deviceId');
    
    if (deviceKeyString != null) {
      _deviceKey = base64.decode(deviceKeyString);
    } else {
      // Generate new device key
      _deviceKey = _cryptoService.generateSalt();
      await _secureStorage.write(
        key: '$_deviceKeyPrefix$_deviceId',
        value: base64.encode(_deviceKey!),
      );
    }
  }
  
  Future<EncryptedData> _encryptValue(String value) async {
    if (_deviceKey == null) {
      throw SecureStorageException('Device key not initialized');
    }
    
    final valueBytes = utf8.encode(value);
    return await _cryptoService.encryptAESGCM(
      Uint8List.fromList(valueBytes),
      _deviceKey!,
      associatedData: utf8.encode(_deviceId!).toUint8List(),
    );
  }
  
  Future<String> _decryptValue(EncryptedData encryptedData) async {
    if (_deviceKey == null) {
      throw SecureStorageException('Device key not initialized');
    }
    
    final decryptedBytes = await _cryptoService.decryptAESGCM(
      encryptedData,
      _deviceKey!,
      associatedData: utf8.encode(_deviceId!).toUint8List(),
    );
    
    return utf8.decode(decryptedBytes);
  }
  
  Future<bool> _authenticateWithBiometrics() async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        throw SecureStorageException('Biometric authentication not available');
      }
      
      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access secure data',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      return false;
    }
  }
}

/// Exception for secure storage operations
class SecureStorageException implements Exception {
  final String message;
  final Object? cause;
  
  const SecureStorageException(this.message, [this.cause]);
  
  @override
  String toString() => 'SecureStorageException: $message';
}

/// Metadata for stored items
class StorageMetadata {
  final DateTime createdAt;
  final bool requiresBiometric;
  final Map<String, dynamic> customMetadata;
  
  const StorageMetadata({
    required this.createdAt,
    required this.requiresBiometric,
    required this.customMetadata,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'created_at': createdAt.toIso8601String(),
      'requires_biometric': requiresBiometric,
      'custom_metadata': customMetadata,
    };
  }
  
  factory StorageMetadata.fromJson(Map<String, dynamic> json) {
    return StorageMetadata(
      createdAt: DateTime.parse(json['created_at']),
      requiresBiometric: json['requires_biometric'],
      customMetadata: Map<String, dynamic>.from(json['custom_metadata']),
    );
  }
}

/// Host key fingerprint for SSH connections
class HostKeyFingerprint {
  final String hostname;
  final String fingerprint;
  final String keyType;
  final DateTime firstSeen;
  final DateTime lastVerified;
  
  const HostKeyFingerprint({
    required this.hostname,
    required this.fingerprint,
    required this.keyType,
    required this.firstSeen,
    required this.lastVerified,
  });
  
  HostKeyFingerprint copyWith({
    String? hostname,
    String? fingerprint,
    String? keyType,
    DateTime? firstSeen,
    DateTime? lastVerified,
  }) {
    return HostKeyFingerprint(
      hostname: hostname ?? this.hostname,
      fingerprint: fingerprint ?? this.fingerprint,
      keyType: keyType ?? this.keyType,
      firstSeen: firstSeen ?? this.firstSeen,
      lastVerified: lastVerified ?? this.lastVerified,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'hostname': hostname,
      'fingerprint': fingerprint,
      'key_type': keyType,
      'first_seen': firstSeen.toIso8601String(),
      'last_verified': lastVerified.toIso8601String(),
    };
  }
  
  factory HostKeyFingerprint.fromJson(Map<String, dynamic> json) {
    return HostKeyFingerprint(
      hostname: json['hostname'],
      fingerprint: json['fingerprint'],
      keyType: json['key_type'],
      firstSeen: DateTime.parse(json['first_seen']),
      lastVerified: DateTime.parse(json['last_verified']),
    );
  }
}