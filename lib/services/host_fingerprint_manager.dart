import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_models.dart';

/// Manages SSH host fingerprints for host key verification
class HostFingerprintManager {
  static const String _hostFingerprintPrefix = 'host_fingerprint_';

  final FlutterSecureStorage _secureStorage;

  HostFingerprintManager({
    required FlutterSecureStorage secureStorage,
  }) : _secureStorage = secureStorage;

  /// Store host fingerprint for SSH host key verification
  Future<void> storeHostFingerprint({
    required String hostname,
    required String fingerprint,
    required String keyType,
    bool isVerified = false,
  }) async {
    try {
      debugPrint('🔐 Storing host fingerprint for: $hostname');

      final now = DateTime.now();
      final hostFingerprint = HostKeyFingerprint(
        hostname: hostname,
        fingerprint: fingerprint,
        keyType: keyType,
        firstSeen: now,
        lastVerified: now,
        isVerified: isVerified,
      );

      await _secureStorage.write(
        key: '$_hostFingerprintPrefix$hostname',
        value: json.encode(hostFingerprint.toJson()),
      );

      debugPrint('✅ Host fingerprint stored successfully: $hostname');
    } catch (e) {
      debugPrint('❌ Failed to store host fingerprint: $e');
      throw SecureStorageException('Failed to store host fingerprint: $e');
    }
  }

  /// Retrieve host fingerprint
  Future<HostKeyFingerprint?> getHostFingerprint(String hostname) async {
    try {
      debugPrint('🔓 Retrieving host fingerprint: $hostname');

      final fingerprintJson = await _secureStorage.read(
        key: '$_hostFingerprintPrefix$hostname',
      );

      if (fingerprintJson == null) {
        debugPrint('⚠️ Host fingerprint not found: $hostname');
        return null;
      }

      final fingerprint = HostKeyFingerprint.fromJson(
        json.decode(fingerprintJson),
      );

      debugPrint('✅ Host fingerprint retrieved: $hostname');
      return fingerprint;
    } catch (e) {
      debugPrint('❌ Failed to retrieve host fingerprint: $e');
      throw SecureStorageException('Failed to retrieve host fingerprint: $e');
    }
  }

  /// Update host fingerprint verification time
  Future<void> updateHostFingerprintVerification(String hostname) async {
    try {
      debugPrint('🔄 Updating host fingerprint verification: $hostname');

      final currentFingerprint = await getHostFingerprint(hostname);
      if (currentFingerprint == null) {
        debugPrint('⚠️ Host fingerprint not found for verification update: $hostname');
        return;
      }

      final updatedFingerprint = currentFingerprint.copyWith(
        lastVerified: DateTime.now(),
        isVerified: true,
      );

      await _secureStorage.write(
        key: '$_hostFingerprintPrefix$hostname',
        value: json.encode(updatedFingerprint.toJson()),
      );

      debugPrint('✅ Host fingerprint verification updated: $hostname');
    } catch (e) {
      debugPrint('❌ Failed to update host fingerprint verification: $e');
      throw SecureStorageException('Failed to update host fingerprint verification: $e');
    }
  }

  /// List all stored host fingerprints
  Future<List<String>> listHostFingerprints() async {
    try {
      final allKeys = await _secureStorage.readAll();
      final hostnames = <String>[];

      for (final key in allKeys.keys) {
        if (key.startsWith(_hostFingerprintPrefix)) {
          final hostname = key.substring(_hostFingerprintPrefix.length);
          hostnames.add(hostname);
        }
      }

      debugPrint('📋 Found ${hostnames.length} host fingerprints');
      return hostnames;
    } catch (e) {
      debugPrint('❌ Failed to list host fingerprints: $e');
      throw SecureStorageException('Failed to list host fingerprints: $e');
    }
  }

  /// Get all host fingerprints with details
  Future<List<HostKeyFingerprint>> getAllHostFingerprints() async {
    try {
      final hostnames = await listHostFingerprints();
      final fingerprints = <HostKeyFingerprint>[];

      for (final hostname in hostnames) {
        final fingerprint = await getHostFingerprint(hostname);
        if (fingerprint != null) {
          fingerprints.add(fingerprint);
        }
      }

      return fingerprints;
    } catch (e) {
      debugPrint('❌ Failed to get all host fingerprints: $e');
      throw SecureStorageException('Failed to get all host fingerprints: $e');
    }
  }

  /// Delete host fingerprint
  Future<void> deleteHostFingerprint(String hostname) async {
    try {
      debugPrint('🗑️ Deleting host fingerprint: $hostname');

      await _secureStorage.delete(key: '$_hostFingerprintPrefix$hostname');

      debugPrint('✅ Host fingerprint deleted successfully: $hostname');
    } catch (e) {
      debugPrint('❌ Failed to delete host fingerprint: $e');
      throw SecureStorageException('Failed to delete host fingerprint: $e');
    }
  }

  /// Check if host fingerprint exists
  Future<bool> hasHostFingerprint(String hostname) async {
    try {
      final fingerprint = await _secureStorage.read(key: '$_hostFingerprintPrefix$hostname');
      return fingerprint != null;
    } catch (e) {
      debugPrint('❌ Failed to check host fingerprint existence: $e');
      return false;
    }
  }

  /// Verify host fingerprint matches stored one
  Future<bool> verifyHostFingerprint({
    required String hostname,
    required String fingerprint,
    required String keyType,
  }) async {
    try {
      debugPrint('🔍 Verifying host fingerprint: $hostname');

      final storedFingerprint = await getHostFingerprint(hostname);
      
      if (storedFingerprint == null) {
        debugPrint('⚠️ No stored fingerprint for host: $hostname');
        return false;
      }

      final matches = storedFingerprint.fingerprint == fingerprint &&
                     storedFingerprint.keyType == keyType;

      if (matches) {
        debugPrint('✅ Host fingerprint verified: $hostname');
        // Update verification time
        await updateHostFingerprintVerification(hostname);
      } else {
        debugPrint('❌ Host fingerprint mismatch: $hostname');
      }

      return matches;
    } catch (e) {
      debugPrint('❌ Failed to verify host fingerprint: $e');
      throw SecureStorageException('Failed to verify host fingerprint: $e');
    }
  }

  /// Update host fingerprint (for key rotation scenarios)
  Future<void> updateHostFingerprint({
    required String hostname,
    required String newFingerprint,
    required String newKeyType,
  }) async {
    try {
      debugPrint('🔄 Updating host fingerprint: $hostname');

      final currentFingerprint = await getHostFingerprint(hostname);
      
      final updatedFingerprint = HostKeyFingerprint(
        hostname: hostname,
        fingerprint: newFingerprint,
        keyType: newKeyType,
        firstSeen: currentFingerprint?.firstSeen ?? DateTime.now(),
        lastVerified: DateTime.now(),
        isVerified: true,
      );

      await _secureStorage.write(
        key: '$_hostFingerprintPrefix$hostname',
        value: json.encode(updatedFingerprint.toJson()),
      );

      debugPrint('✅ Host fingerprint updated successfully: $hostname');
    } catch (e) {
      debugPrint('❌ Failed to update host fingerprint: $e');
      throw SecureStorageException('Failed to update host fingerprint: $e');
    }
  }

  /// Get host fingerprints that need verification (old or unverified)
  Future<List<HostKeyFingerprint>> getFingerprintsNeedingVerification({
    Duration maxAge = const Duration(days: 30),
  }) async {
    try {
      final allFingerprints = await getAllHostFingerprints();
      final needVerification = <HostKeyFingerprint>[];
      final now = DateTime.now();

      for (final fingerprint in allFingerprints) {
        final age = now.difference(fingerprint.lastVerified);
        
        if (!fingerprint.isVerified || age > maxAge) {
          needVerification.add(fingerprint);
        }
      }

      debugPrint('⚠️ Found ${needVerification.length} fingerprints needing verification');
      return needVerification;
    } catch (e) {
      debugPrint('❌ Failed to get fingerprints needing verification: $e');
      return [];
    }
  }

  /// Get host fingerprint statistics
  Future<Map<String, dynamic>> getHostFingerprintStatistics() async {
    try {
      final fingerprints = await getAllHostFingerprints();
      
      int verifiedCount = 0;
      int recentlyVerified = 0;
      final now = DateTime.now();
      final recentThreshold = now.subtract(const Duration(days: 7));
      
      final keyTypeCounts = <String, int>{};

      for (final fingerprint in fingerprints) {
        if (fingerprint.isVerified) verifiedCount++;
        if (fingerprint.lastVerified.isAfter(recentThreshold)) recentlyVerified++;
        
        keyTypeCounts[fingerprint.keyType] = (keyTypeCounts[fingerprint.keyType] ?? 0) + 1;
      }

      return {
        'totalFingerprints': fingerprints.length,
        'verifiedCount': verifiedCount,
        'recentlyVerified': recentlyVerified,
        'keyTypeCounts': keyTypeCounts,
      };
    } catch (e) {
      debugPrint('❌ Failed to get host fingerprint statistics: $e');
      return {'error': e.toString()};
    }
  }

  /// Clean up old unverified fingerprints
  Future<int> cleanupOldFingerprints({
    Duration maxAge = const Duration(days: 90),
  }) async {
    try {
      debugPrint('🧹 Cleaning up old fingerprints...');

      final allFingerprints = await getAllHostFingerprints();
      final now = DateTime.now();
      int cleanedCount = 0;

      for (final fingerprint in allFingerprints) {
        final age = now.difference(fingerprint.firstSeen);
        
        // Remove unverified fingerprints older than maxAge
        if (!fingerprint.isVerified && age > maxAge) {
          await deleteHostFingerprint(fingerprint.hostname);
          cleanedCount++;
        }
      }

      debugPrint('✅ Cleaned up $cleanedCount old fingerprints');
      return cleanedCount;
    } catch (e) {
      debugPrint('❌ Failed to cleanup old fingerprints: $e');
      throw SecureStorageException('Failed to cleanup old fingerprints: $e');
    }
  }
}