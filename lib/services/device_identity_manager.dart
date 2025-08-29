import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'crypto_service.dart';
import 'secure_storage_models.dart';

/// Manages device identity and encryption keys
class DeviceIdentityManager {
  static const String _deviceKeyPrefix = 'device_key_';
  static const String _deviceIdKey = 'device_id';
  static const String _deviceKeyCreatedKey = 'device_key_created';

  final FlutterSecureStorage _secureStorage;
  final CryptoService _cryptoService;
  final DeviceInfoPlugin _deviceInfo;

  String? _deviceId;
  Uint8List? _deviceKey;

  DeviceIdentityManager({
    required FlutterSecureStorage secureStorage,
    required CryptoService cryptoService,
    DeviceInfoPlugin? deviceInfo,
  }) : _secureStorage = secureStorage,
       _cryptoService = cryptoService,
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  /// Get device ID (lazy loaded)
  String? get deviceId => _deviceId;

  /// Get device key (lazy loaded)
  Uint8List? get deviceKey => _deviceKey;

  /// Initialize device identity and keys
  Future<void> initialize() async {
    await _initializeDeviceIdentity();
    await _initializeDeviceKey();
  }

  /// Initialize device identity
  Future<void> _initializeDeviceIdentity() async {
    try {
      // Try to load existing device ID
      _deviceId = await _secureStorage.read(key: _deviceIdKey);
      
      if (_deviceId == null) {
        // Generate new device ID
        _deviceId = await _generateDeviceId();
        await _secureStorage.write(key: _deviceIdKey, value: _deviceId!);
        debugPrint('✅ Generated new device ID');
      } else {
        debugPrint('✅ Loaded existing device ID');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize device identity: $e');
      throw SecureStorageException('Device identity initialization failed: $e');
    }
  }

  /// Initialize device encryption key
  Future<void> _initializeDeviceKey() async {
    try {
      final deviceKeyString = await _secureStorage.read(
        key: '$_deviceKeyPrefix$_deviceId',
      );
      
      if (deviceKeyString != null) {
        // Load existing key
        _deviceKey = base64.decode(deviceKeyString);
        debugPrint('✅ Loaded existing device key');
      } else {
        // Generate new key
        _deviceKey = await _cryptoService.generateKey();
        await _secureStorage.write(
          key: '$_deviceKeyPrefix$_deviceId',
          value: base64.encode(_deviceKey!),
        );
        
        // Store key creation timestamp
        await _secureStorage.write(
          key: _deviceKeyCreatedKey,
          value: DateTime.now().toIso8601String(),
        );
        
        debugPrint('✅ Generated new device key');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize device key: $e');
      throw SecureStorageException('Device key initialization failed: $e');
    }
  }

  /// Generate unique device identifier
  Future<String> _generateDeviceId() async {
    try {
      String deviceInfo = '';
      
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceInfo = '${androidInfo.model}_${androidInfo.id}_${androidInfo.fingerprint}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceInfo = '${iosInfo.model}_${iosInfo.identifierForVendor}_${iosInfo.systemName}';
      } else {
        // Fallback for other platforms
        deviceInfo = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      // Create hash of device info for consistency
      return _cryptoService.hashString(deviceInfo);
    } catch (e) {
      debugPrint('❌ Failed to generate device ID: $e');
      // Fallback to timestamp-based ID
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Get device security information
  Future<DeviceSecurityInfo> getSecurityInfo() async {
    if (_deviceId == null || _deviceKey == null) {
      throw const SecureStorageException('Device not initialized');
    }

    try {
      final keyCreatedString = await _secureStorage.read(key: _deviceKeyCreatedKey);
      final keyCreatedAt = keyCreatedString != null 
          ? DateTime.parse(keyCreatedString)
          : DateTime.now();

      return DeviceSecurityInfo(
        deviceId: _deviceId!,
        deviceKey: _deviceKey!,
        biometricsAvailable: false, // Will be set by BiometricAuthHandler
        biometricsEnrolled: false, // Will be set by BiometricAuthHandler
        keyCreatedAt: keyCreatedAt,
      );
    } catch (e) {
      debugPrint('❌ Failed to get security info: $e');
      throw SecureStorageException('Failed to get security info: $e');
    }
  }

  /// Rotate device key (for security)
  Future<void> rotateDeviceKey() async {
    try {
      debugPrint('🔄 Rotating device key...');
      
      // Generate new key
      final newKey = await _cryptoService.generateKey();
      
      // Store new key
      await _secureStorage.write(
        key: '$_deviceKeyPrefix$_deviceId',
        value: base64.encode(newKey),
      );
      
      // Update creation timestamp
      await _secureStorage.write(
        key: _deviceKeyCreatedKey,
        value: DateTime.now().toIso8601String(),
      );
      
      _deviceKey = newKey;
      debugPrint('✅ Device key rotated successfully');
    } catch (e) {
      debugPrint('❌ Failed to rotate device key: $e');
      throw SecureStorageException('Device key rotation failed: $e');
    }
  }

  /// Reset device identity (use with caution)
  Future<void> resetDeviceIdentity() async {
    try {
      debugPrint('⚠️ Resetting device identity...');
      
      // Clear stored identity
      if (_deviceId != null) {
        await _secureStorage.delete(key: '$_deviceKeyPrefix$_deviceId');
        await _secureStorage.delete(key: _deviceIdKey);
        await _secureStorage.delete(key: _deviceKeyCreatedKey);
      }
      
      // Reset in-memory values
      _deviceId = null;
      _deviceKey = null;
      
      // Re-initialize
      await initialize();
      
      debugPrint('✅ Device identity reset and re-initialized');
    } catch (e) {
      debugPrint('❌ Failed to reset device identity: $e');
      throw SecureStorageException('Device identity reset failed: $e');
    }
  }

  /// Get device key age
  Future<Duration?> getDeviceKeyAge() async {
    try {
      final keyCreatedString = await _secureStorage.read(key: _deviceKeyCreatedKey);
      if (keyCreatedString == null) return null;
      
      final keyCreatedAt = DateTime.parse(keyCreatedString);
      return DateTime.now().difference(keyCreatedAt);
    } catch (e) {
      debugPrint('❌ Failed to get device key age: $e');
      return null;
    }
  }
}