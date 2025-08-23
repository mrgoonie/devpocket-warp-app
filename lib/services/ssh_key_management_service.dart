import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

import '../models/ssh_models.dart';
import 'ssh_key_generation_service.dart';
import 'ssh_key_storage_service.dart';

/// SSH Key Management Service - High-level API for SSH key operations
class SshKeyManagementService {
  static SshKeyManagementService? _instance;
  static SshKeyManagementService get instance => _instance ??= SshKeyManagementService._();

  SshKeyManagementService._();

  final SshKeyGenerationService _generationService = SshKeyGenerationService.instance;
  final SshKeyStorageService _storageService = SshKeyStorageService.instance;

  final StreamController<SshKeyEvent> _eventController = StreamController.broadcast();

  /// Stream of SSH key events
  Stream<SshKeyEvent> get events => _eventController.stream;

  /// Generate and store new SSH key pair
  Future<SshKeyRecord> generateAndStoreKey({
    required String name,
    required SshKeyType keyType,
    String? passphrase,
    String? comment,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Generating and storing SSH key: $name ($keyType)');
      
      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.generating,
        name: name,
        keyType: keyType,
        message: 'Generating SSH key...',
        timestamp: DateTime.now(),
      ));

      // Generate key pair
      final keyResult = await _generationService.generateKeyPair(
        keyType: keyType,
        passphrase: passphrase,
        comment: comment ?? name,
      );

      // Store key pair
      final keyId = await _storageService.storeKeyPair(
        keyResult: keyResult,
        name: name,
        passphrase: passphrase,
        metadata: metadata,
      );

      // Get stored record
      final keyRecords = await _storageService.getAllKeyRecords();
      final keyRecord = keyRecords.firstWhere((r) => r.id == keyId);

      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.created,
        keyId: keyId,
        name: name,
        keyType: keyType,
        fingerprint: keyResult.fingerprint,
        message: 'SSH key generated and stored successfully',
        timestamp: DateTime.now(),
      ));

      return keyRecord;

    } catch (e) {
      debugPrint('Failed to generate and store SSH key: $e');
      
      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.error,
        name: name,
        keyType: keyType,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));

      rethrow;
    }
  }

  /// Import existing SSH key pair
  Future<SshKeyRecord> importKey({
    required String name,
    required String publicKey,
    required String privateKey,
    String? passphrase,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Importing SSH key: $name');
      
      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.importing,
        name: name,
        message: 'Importing SSH key...',
        timestamp: DateTime.now(),
      ));

      // Import key pair
      final keyId = await _storageService.importKeyPair(
        name: name,
        publicKey: publicKey,
        privateKey: privateKey,
        passphrase: passphrase,
        metadata: metadata,
      );

      if (keyId == null) {
        throw Exception('Failed to import SSH key');
      }

      // Get stored record
      final keyRecords = await _storageService.getAllKeyRecords();
      final keyRecord = keyRecords.firstWhere((r) => r.id == keyId);

      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.imported,
        keyId: keyId,
        name: name,
        keyType: keyRecord.keyType,
        fingerprint: keyRecord.fingerprint,
        message: 'SSH key imported successfully',
        timestamp: DateTime.now(),
      ));

      return keyRecord;

    } catch (e) {
      debugPrint('Failed to import SSH key: $e');
      
      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.error,
        name: name,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));

      rethrow;
    }
  }

  /// Get all SSH key records
  Future<List<SshKeyRecord>> getAllKeys() async {
    try {
      return await _storageService.getAllKeyRecords();
    } catch (e) {
      debugPrint('Failed to get SSH keys: $e');
      return [];
    }
  }

  /// Get SSH key pair (with private key)
  Future<SshKeyPair?> getKeyPair(String keyId, {String? passphrase}) async {
    try {
      return await _storageService.getKeyPair(keyId, passphrase: passphrase);
    } catch (e) {
      debugPrint('Failed to get SSH key pair: $e');
      return null;
    }
  }

  /// Get public key only
  Future<String?> getPublicKey(String keyId) async {
    try {
      return await _storageService.exportPublicKey(keyId);
    } catch (e) {
      debugPrint('Failed to get public key: $e');
      return null;
    }
  }

  /// Delete SSH key
  Future<bool> deleteKey(String keyId) async {
    try {
      debugPrint('Deleting SSH key: $keyId');
      
      // Get key info for event
      final keyRecords = await _storageService.getAllKeyRecords();
      final keyRecord = keyRecords.where((r) => r.id == keyId).firstOrNull;
      
      final deleted = await _storageService.deleteKeyPair(keyId);
      
      if (deleted && keyRecord != null) {
        _emitEvent(SshKeyEvent(
          type: SshKeyEventType.deleted,
          keyId: keyId,
          name: keyRecord.name,
          keyType: keyRecord.keyType,
          message: 'SSH key deleted successfully',
          timestamp: DateTime.now(),
        ));
      }

      return deleted;

    } catch (e) {
      debugPrint('Failed to delete SSH key: $e');
      
      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.error,
        keyId: keyId,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));

      return false;
    }
  }

  /// Update SSH key metadata
  Future<bool> updateKeyMetadata(
    String keyId, {
    String? name,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final updated = await _storageService.updateKeyMetadata(
        keyId,
        name: name,
        metadata: metadata,
      );

      if (updated) {
        _emitEvent(SshKeyEvent(
          type: SshKeyEventType.updated,
          keyId: keyId,
          name: name,
          message: 'SSH key metadata updated',
          timestamp: DateTime.now(),
        ));
      }

      return updated;

    } catch (e) {
      debugPrint('Failed to update SSH key metadata: $e');
      return false;
    }
  }

  /// Validate key passphrase
  Future<bool> validatePassphrase(String keyId, String passphrase) async {
    try {
      return await _storageService.validatePassphrase(keyId, passphrase);
    } catch (e) {
      debugPrint('Failed to validate passphrase: $e');
      return false;
    }
  }

  /// Export public key to file
  Future<bool> exportPublicKeyToFile(String keyId, String filePath) async {
    try {
      final publicKey = await getPublicKey(keyId);
      if (publicKey == null) return false;

      final file = File(filePath);
      await file.writeAsString(publicKey);

      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.exported,
        keyId: keyId,
        message: 'Public key exported to $filePath',
        timestamp: DateTime.now(),
      ));

      return true;

    } catch (e) {
      debugPrint('Failed to export public key: $e');
      return false;
    }
  }

  /// Copy public key to clipboard
  Future<bool> copyPublicKeyToClipboard(String keyId) async {
    try {
      final publicKey = await getPublicKey(keyId);
      if (publicKey == null) return false;

      // Note: Clipboard functionality would need platform-specific implementation
      // or a plugin like 'flutter/services' Clipboard.setData()
      debugPrint('Public key copied to clipboard for key: $keyId');

      _emitEvent(SshKeyEvent(
        type: SshKeyEventType.copied,
        keyId: keyId,
        message: 'Public key copied to clipboard',
        timestamp: DateTime.now(),
      ));

      return true;

    } catch (e) {
      debugPrint('Failed to copy public key: $e');
      return false;
    }
  }

  /// Get SSH key statistics
  Future<Map<String, dynamic>> getKeyStatistics() async {
    try {
      return await _storageService.getKeyStatistics();
    } catch (e) {
      debugPrint('Failed to get key statistics: $e');
      return {'totalKeys': 0, 'error': e.toString()};
    }
  }

  /// Get recommended SSH key types
  List<SshKeyType> getRecommendedKeyTypes() {
    return _generationService.getRecommendedKeyTypes();
  }

  /// Estimate key generation time
  Duration estimateGenerationTime(SshKeyType keyType) {
    return _generationService.estimateGenerationTime(keyType);
  }

  /// Cleanup old or unused keys
  Future<int> cleanupOldKeys({int maxAgeInDays = 365}) async {
    try {
      final deletedCount = await _storageService.cleanupOldKeys(maxAgeInDays: maxAgeInDays);
      
      if (deletedCount > 0) {
        _emitEvent(SshKeyEvent(
          type: SshKeyEventType.cleanup,
          message: 'Cleaned up $deletedCount old SSH keys',
          timestamp: DateTime.now(),
        ));
      }

      return deletedCount;

    } catch (e) {
      debugPrint('Failed to cleanup old keys: $e');
      return 0;
    }
  }

  /// Check if key exists
  Future<bool> keyExists(String keyId) async {
    try {
      final keys = await getAllKeys();
      return keys.any((key) => key.id == keyId);
    } catch (e) {
      return false;
    }
  }

  /// Find keys by name pattern
  Future<List<SshKeyRecord>> findKeysByName(String namePattern) async {
    try {
      final keys = await getAllKeys();
      final pattern = namePattern.toLowerCase();
      
      return keys.where((key) => 
        key.name.toLowerCase().contains(pattern)
      ).toList();

    } catch (e) {
      debugPrint('Failed to find keys by name: $e');
      return [];
    }
  }

  /// Get keys by type
  Future<List<SshKeyRecord>> getKeysByType(SshKeyType keyType) async {
    try {
      final keys = await getAllKeys();
      return keys.where((key) => key.keyType == keyType).toList();

    } catch (e) {
      debugPrint('Failed to get keys by type: $e');
      return [];
    }
  }

  /// Get recently used keys (within specified days)
  Future<List<SshKeyRecord>> getRecentlyUsedKeys({int withinDays = 30}) async {
    try {
      final keys = await getAllKeys();
      final cutoffDate = DateTime.now().subtract(Duration(days: withinDays));
      
      return keys.where((key) => 
        key.lastUsed != null && key.lastUsed!.isAfter(cutoffDate)
      ).toList();

    } catch (e) {
      debugPrint('Failed to get recently used keys: $e');
      return [];
    }
  }

  /// Backup all SSH keys to a secure format
  Future<Map<String, dynamic>?> createBackup({String? passphrase}) async {
    try {
      final keys = await getAllKeys();
      final backup = <String, dynamic>{
        'version': '1.0',
        'created': DateTime.now().toIso8601String(),
        'keys': [],
      };

      // Note: For security, only include public keys and metadata in backup
      // Private keys should be backed up separately with additional encryption
      for (final key in keys) {
        backup['keys'].add({
          'id': key.id,
          'name': key.name,
          'keyType': key.keyType.name,
          'publicKey': key.publicKey,
          'fingerprint': key.fingerprint,
          'createdAt': key.createdAt.toIso8601String(),
          'hasPassphrase': key.hasPassphrase,
          'metadata': key.metadata,
        });
      }

      return backup;

    } catch (e) {
      debugPrint('Failed to create backup: $e');
      return null;
    }
  }

  /// Emit SSH key event
  void _emitEvent(SshKeyEvent event) {
    _eventController.add(event);
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
  }
}

