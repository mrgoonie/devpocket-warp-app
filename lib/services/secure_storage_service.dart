import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';

import 'crypto_service.dart';
import 'secure_storage_models.dart';
import 'device_identity_manager.dart';
import 'biometric_auth_handler.dart';
import 'ssh_key_manager.dart';
import 'api_key_manager.dart';
import 'host_fingerprint_manager.dart';

/// Enhanced secure storage service with modular architecture
/// Provides device keychain integration, biometric protection, and encrypted storage
class SecureStorageService {
  static const String _authTokensKey = 'auth_tokens';
  static const String _lastActiveKey = 'last_active_time';
  static const String _onboardingKey = 'onboarding_completed';

  static SecureStorageService? _instance;
  static SecureStorageService get instance => _instance ??= SecureStorageService();

  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;

  // Component managers
  late final DeviceIdentityManager _deviceIdentity;
  late final BiometricAuthHandler _biometricAuth;
  late final SSHKeyManager _sshKeyManager;
  late final APIKeyManager _apiKeyManager;
  late final HostFingerprintManager _hostFingerprintManager;

  bool _initialized = false;

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
        _cryptoService = cryptoService ?? CryptoService() {
    _initializeComponents(localAuth, deviceInfo);
  }

  void _initializeComponents(LocalAuthentication? localAuth, DeviceInfoPlugin? deviceInfo) {
    _deviceIdentity = DeviceIdentityManager(
      secureStorage: _secureStorage,
      cryptoService: _cryptoService,
      deviceInfo: deviceInfo,
    );

    _biometricAuth = BiometricAuthHandler(
      localAuth: localAuth,
    );

    _sshKeyManager = SSHKeyManager(
      secureStorage: _secureStorage,
      cryptoService: _cryptoService,
      biometricAuth: _biometricAuth,
    );

    _apiKeyManager = APIKeyManager(
      secureStorage: _secureStorage,
      cryptoService: _cryptoService,
      biometricAuth: _biometricAuth,
    );

    _hostFingerprintManager = HostFingerprintManager(
      secureStorage: _secureStorage,
    );
  }

  /// Initialize the secure storage service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      debugPrint('🚀 Initializing SecureStorageService...');
      await _deviceIdentity.initialize();
      _initialized = true;
      debugPrint('✅ SecureStorageService initialized successfully');
    } catch (e) {
      debugPrint('❌ SecureStorageService initialization failed: $e');
      throw SecureStorageException('SecureStorageService initialization failed: $e');
    }
  }

  /// Store sensitive data with optional biometric protection
  Future<void> storeSecure({
    required String key,
    required String value,
    bool requireBiometric = false,
    Map<String, dynamic>? metadata,
  }) async {
    await _ensureInitialized();

    try {
      debugPrint('🔐 Storing secure data: $key');

      if (requireBiometric) {
        final authenticated = await _biometricAuth.authenticateForSecureData(key);
        if (!authenticated) {
          throw const SecureStorageException('Biometric authentication required');
        }
      }

      // Encrypt value with device key
      final encryptedData = await _cryptoService.encryptWithDeviceKey(value);

      // Create storage metadata
      final storageMetadata = StorageMetadata(
        createdAt: DateTime.now(),
        lastAccessed: DateTime.now(),
        version: '1.0',
        description: metadata?['description'] ?? 'Secure data: $key',
        requiresBiometric: requireBiometric,
      );

      // Store encrypted data
      await _secureStorage.write(
        key: 'encrypted_$key',
        value: base64.encode(encryptedData),
      );

      // Store metadata
      await _secureStorage.write(
        key: 'metadata_$key',
        value: json.encode(storageMetadata.toJson()),
      );

      debugPrint('✅ Secure data stored successfully: $key');
    } catch (e) {
      debugPrint('❌ Failed to store secure data: $e');
      throw SecureStorageException('Failed to store secure data: $e');
    }
  }

  /// Retrieve sensitive data with biometric check if required
  Future<String?> getSecure(String key) async {
    await _ensureInitialized();

    try {
      debugPrint('🔓 Retrieving secure data: $key');

      // Check metadata for biometric requirement
      final metadataJson = await _secureStorage.read(key: 'metadata_$key');
      if (metadataJson != null) {
        final metadata = StorageMetadata.fromJson(json.decode(metadataJson));
        if (metadata.requiresBiometric) {
          final authenticated = await _biometricAuth.authenticateForSecureData(key);
          if (!authenticated) {
            throw const SecureStorageException('Biometric authentication required');
          }
        }
      }

      // Retrieve encrypted data
      final encryptedDataBase64 = await _secureStorage.read(key: 'encrypted_$key');
      if (encryptedDataBase64 == null) {
        debugPrint('⚠️ Secure data not found: $key');
        return null;
      }

      // Decrypt data
      final encryptedData = base64.decode(encryptedDataBase64);
      final decryptedValue = await _cryptoService.decryptWithDeviceKey(encryptedData);

      debugPrint('✅ Secure data retrieved successfully: $key');
      return decryptedValue;
    } catch (e) {
      debugPrint('❌ Failed to retrieve secure data: $e');
      throw SecureStorageException('Failed to retrieve secure data: $e');
    }
  }

  // SSH Key Management - Delegate to SSHKeyManager
  Future<void> storeSSHKey({
    required String keyId,
    required String privateKey,
    required String passphrase,
    bool requireBiometric = true,
    String? description,
  }) async {
    await _ensureInitialized();
    return _sshKeyManager.storeSSHKey(
      keyId: keyId,
      privateKey: privateKey,
      passphrase: passphrase,
      requireBiometric: requireBiometric,
      description: description,
    );
  }

  Future<String?> getSSHKey(String keyId, String passphrase) async {
    await _ensureInitialized();
    return _sshKeyManager.getSSHKey(keyId, passphrase);
  }

  // API Key Management - Delegate to APIKeyManager
  Future<void> storeAPIKey({
    required String keyName,
    required String apiKey,
    bool requireBiometric = false,
    String? description,
    String? provider,
  }) async {
    await _ensureInitialized();
    return _apiKeyManager.storeAPIKey(
      keyName: keyName,
      apiKey: apiKey,
      requireBiometric: requireBiometric,
      description: description,
      provider: provider,
    );
  }

  Future<String?> getAPIKey(String keyName) async {
    await _ensureInitialized();
    return _apiKeyManager.getAPIKey(keyName);
  }

  // Host Fingerprint Management - Delegate to HostFingerprintManager
  Future<void> storeHostFingerprint({
    required String hostname,
    required String fingerprint,
    required String keyType,
    bool isVerified = false,
  }) async {
    await _ensureInitialized();
    return _hostFingerprintManager.storeHostFingerprint(
      hostname: hostname,
      fingerprint: fingerprint,
      keyType: keyType,
      isVerified: isVerified,
    );
  }

  Future<HostKeyFingerprint?> getHostFingerprint(String hostname) async {
    await _ensureInitialized();
    return _hostFingerprintManager.getHostFingerprint(hostname);
  }

  Future<void> updateHostFingerprintVerification(String hostname) async {
    await _ensureInitialized();
    return _hostFingerprintManager.updateHostFingerprintVerification(hostname);
  }

  // Authentication Token Management
  Future<Map<String, String>?> getAuthTokens() async {
    await _ensureInitialized();

    try {
      final tokensJson = await getSecure(_authTokensKey);
      if (tokensJson == null) return null;

      final tokensMap = json.decode(tokensJson) as Map<String, dynamic>;
      return tokensMap.cast<String, String>();
    } catch (e) {
      debugPrint('❌ Failed to get auth tokens: $e');
      return null;
    }
  }

  Future<void> storeAuthTokens({
    required String accessToken,
    required String refreshToken,
    String? tokenType,
    int? expiresIn,
  }) async {
    await _ensureInitialized();

    try {
      final tokens = {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        if (tokenType != null) 'token_type': tokenType,
        if (expiresIn != null) 'expires_in': expiresIn.toString(),
        'stored_at': DateTime.now().toIso8601String(),
      };

      await storeSecure(
        key: _authTokensKey,
        value: json.encode(tokens),
        requireBiometric: false,
      );

      debugPrint('✅ Auth tokens stored successfully');
    } catch (e) {
      debugPrint('❌ Failed to store auth tokens: $e');
      throw SecureStorageException('Failed to store auth tokens: $e');
    }
  }

  Future<void> clearAuthTokens() async {
    await deleteSecure(_authTokensKey);
  }

  // User Activity Tracking
  Future<DateTime?> getLastActiveTime() async {
    try {
      final timeString = await _secureStorage.read(key: _lastActiveKey);
      if (timeString == null) return null;
      return DateTime.parse(timeString);
    } catch (e) {
      debugPrint('❌ Failed to get last active time: $e');
      return null;
    }
  }

  Future<void> storeLastActiveTime([DateTime? time]) async {
    try {
      final activeTime = time ?? DateTime.now();
      await _secureStorage.write(
        key: _lastActiveKey,
        value: activeTime.toIso8601String(),
      );
    } catch (e) {
      debugPrint('❌ Failed to store last active time: $e');
    }
  }

  // Onboarding State Management
  Future<bool> isOnboardingCompleted() async {
    try {
      final completed = await _secureStorage.read(key: _onboardingKey);
      return completed == 'true';
    } catch (e) {
      debugPrint('❌ Failed to check onboarding status: $e');
      return false;
    }
  }

  Future<void> markOnboardingCompleted() async {
    try {
      await _secureStorage.write(key: _onboardingKey, value: 'true');
      debugPrint('✅ Onboarding marked as completed');
    } catch (e) {
      debugPrint('❌ Failed to mark onboarding completed: $e');
      throw SecureStorageException('Failed to mark onboarding completed: $e');
    }
  }

  Future<void> resetOnboarding() async {
    try {
      await _secureStorage.delete(key: _onboardingKey);
      debugPrint('✅ Onboarding reset');
    } catch (e) {
      debugPrint('❌ Failed to reset onboarding: $e');
    }
  }

  // Basic Storage Operations
  Future<void> store(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  Future<String?> read(String key) async {
    return await _secureStorage.read(key: key);
  }

  Future<Map<String, String>> readAll() async {
    return await _secureStorage.readAll();
  }

  Future<void> delete(String key) async {
    await _secureStorage.delete(key: key);
  }

  Future<void> deleteSecure(String key) async {
    await delete('encrypted_$key');
    await delete('metadata_$key');
  }

  // List Management Operations
  Future<List<String>> listStoredKeys() async {
    await _ensureInitialized();

    try {
      final allKeys = await _secureStorage.readAll();
      return allKeys.keys.toList();
    } catch (e) {
      debugPrint('❌ Failed to list stored keys: $e');
      throw SecureStorageException('Failed to list stored keys: $e');
    }
  }

  // Component Access (for advanced usage)
  DeviceIdentityManager get deviceIdentity => _deviceIdentity;
  BiometricAuthHandler get biometricAuth => _biometricAuth;
  SSHKeyManager get sshKeyManager => _sshKeyManager;
  APIKeyManager get apiKeyManager => _apiKeyManager;
  HostFingerprintManager get hostFingerprintManager => _hostFingerprintManager;

  // Service Status and Statistics
  Future<Map<String, dynamic>> getServiceStatus() async {
    await _ensureInitialized();

    try {
      final deviceSecurity = await _deviceIdentity.getSecurityInfo();
      final biometricStatus = await _biometricAuth.getBiometricStatus();
      final sshStats = await _sshKeyManager.getSSHKeyStatistics();
      final apiStats = await _apiKeyManager.getAPIKeyStatistics();
      final hostStats = await _hostFingerprintManager.getHostFingerprintStatistics();

      return {
        'initialized': _initialized,
        'deviceId': deviceSecurity.deviceId,
        'keyCreatedAt': deviceSecurity.keyCreatedAt.toIso8601String(),
        'biometrics': biometricStatus,
        'sshKeys': sshStats,
        'apiKeys': apiStats,
        'hostFingerprints': hostStats,
      };
    } catch (e) {
      debugPrint('❌ Failed to get service status: $e');
      return {'error': e.toString()};
    }
  }

  // Utility Methods
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Legacy compatibility method
  Future<void> write({required String key, required String value}) async {
    await store(key, value);
  }
}