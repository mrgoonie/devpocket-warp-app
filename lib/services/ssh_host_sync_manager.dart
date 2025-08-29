import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/ssh_profile_models.dart';
import '../models/ssh_sync_models.dart';
import 'api_client.dart';

/// Advanced sync management service for SSH host profiles
class SshHostSyncManager {
  final ApiClient _apiClient = ApiClient.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  static const String _syncConfigKey = 'ssh_sync_config';
  static const String _lastSyncTimeKey = 'last_sync_time';

  /// Sync local profiles to server
  Future<SyncResult> syncLocalProfilesToServer(List<SshProfile> localProfiles) async {
    final startTime = DateTime.now();
    
    try {
      final serverProfiles = await _getServerProfiles();
      final localOnly = _findLocalOnlyProfiles(localProfiles, serverProfiles);
      
      if (localOnly.isEmpty) {
        return SyncResult.empty();
      }
      
      final syncResults = <String, bool>{};
      int successful = 0;
      int failed = 0;
      
      for (final profile in localOnly) {
        try {
          final result = await _uploadProfileToServer(profile);
          syncResults[profile.id] = result;
          if (result) {
            successful++;
          } else {
            failed++;
          }
        } catch (e) {
          debugPrint('Failed to sync profile ${profile.id}: $e');
          syncResults[profile.id] = false;
          failed++;
        }
      }
      
      await _updateLastSyncTime();
      
      return SyncResult.success(
        successful: successful,
        failed: failed,
        details: syncResults,
        duration: DateTime.now().difference(startTime),
      );
      
    } catch (e) {
      debugPrint('Error syncing local profiles to server: $e');
      return SyncResult.error(e.toString());
    }
  }

  /// Sync server profiles to local storage
  Future<SyncResult> syncServerProfilesToLocal() async {
    final startTime = DateTime.now();
    
    try {
      final serverProfiles = await _getServerProfiles();
      await _updateLastSyncTime();
      
      return SyncResult.success(
        successful: serverProfiles.length,
        failed: 0,
        details: {for (var p in serverProfiles) p.id: true},
        duration: DateTime.now().difference(startTime),
      );
      
    } catch (e) {
      debugPrint('Error syncing server profiles to local: $e');
      return SyncResult.error(e.toString());
    }
  }

  /// Perform bidirectional sync with intelligent conflict resolution
  Future<SyncResult> performFullSync(List<SshProfile> localProfiles) async {
    final startTime = DateTime.now();
    
    try {
      final serverProfiles = await _getServerProfiles();
      final inconsistency = await _detectDataInconsistency(localProfiles, serverProfiles);
      
      if (!inconsistency.hasInconsistency) {
        await _updateLastSyncTime();
        return SyncResult.empty();
      }
      
      final config = await getSyncConfig();
      final mergedProfiles = await _resolveDataInconsistency(
        inconsistency, localProfiles, serverProfiles, config.defaultStrategy
      );
      
      await _updateLastSyncTime();
      
      return SyncResult.success(
        successful: mergedProfiles.length,
        failed: 0,
        details: {for (var p in mergedProfiles) p.id: true},
        duration: DateTime.now().difference(startTime),
      );
      
    } catch (e) {
      debugPrint('Error performing full sync: $e');
      return SyncResult.error(e.toString());
    }
  }

  /// Resolve data inconsistency based on strategy
  Future<List<SshProfile>> _resolveDataInconsistency(
    DataInconsistency inconsistency,
    List<SshProfile> localProfiles,
    List<SshProfile> serverProfiles,
    SyncStrategy strategy,
  ) async {
    try {
      switch (strategy) {
        case SyncStrategy.uploadLocal:
          await syncLocalProfilesToServer(localProfiles);
          return localProfiles;
        
        case SyncStrategy.downloadRemote:
          await syncServerProfilesToLocal();
          return serverProfiles;
        
        case SyncStrategy.merge:
          return await _mergeProfiles(localProfiles, serverProfiles, inconsistency);
        
        case SyncStrategy.askUser:
          await _storePendingConflict(inconsistency);
          return localProfiles;
      }
    } catch (e) {
      debugPrint('Error resolving data inconsistency: $e');
      return localProfiles;
    }
  }

  /// Detect data inconsistencies between local and server profiles
  Future<DataInconsistency> _detectDataInconsistency(
    List<SshProfile> localProfiles,
    List<SshProfile> serverProfiles,
  ) async {
    if (localProfiles.isEmpty && serverProfiles.isEmpty) {
      return DataInconsistency.none();
    }
    
    if (localProfiles.isNotEmpty && serverProfiles.isEmpty) {
      return DataInconsistency.localOnly(localProfiles);
    }
    
    if (localProfiles.isEmpty && serverProfiles.isNotEmpty) {
      return DataInconsistency.serverOnly(serverProfiles);
    }
    
    final localOnly = _findLocalOnlyProfiles(localProfiles, serverProfiles);
    final serverOnly = _findServerOnlyProfiles(localProfiles, serverProfiles);
    
    final conflicts = <ProfileConflict>[];
    for (final local in localProfiles) {
      final server = serverProfiles.cast<SshProfile?>().firstWhere(
        (s) => s?.id == local.id,
        orElse: () => null,
      );
      if (server != null) {
        final conflict = ProfileConflict.detect(local, server);
        if (conflict != null) {
          conflicts.add(conflict);
        }
      }
    }
    
    if (localOnly.isEmpty && serverOnly.isEmpty && conflicts.isEmpty) {
      return DataInconsistency.none();
    }
    
    if (localOnly.isNotEmpty && serverOnly.isEmpty && conflicts.isEmpty) {
      return DataInconsistency.localOnly(localOnly);
    }
    
    if (localOnly.isEmpty && serverOnly.isNotEmpty && conflicts.isEmpty) {
      return DataInconsistency.serverOnly(serverOnly);
    }
    
    if (localOnly.isEmpty && serverOnly.isEmpty && conflicts.isNotEmpty) {
      return DataInconsistency.conflicts(conflicts);
    }
    
    return DataInconsistency.mixed(
      localOnly: localOnly,
      serverOnly: serverOnly,
      conflicts: conflicts,
    );
  }

  /// Merge profiles intelligently based on timestamps and conflicts
  Future<List<SshProfile>> _mergeProfiles(
    List<SshProfile> localProfiles,
    List<SshProfile> serverProfiles,
    DataInconsistency inconsistency,
  ) async {
    final mergedProfiles = <String, SshProfile>{};
    
    for (final local in localProfiles) {
      mergedProfiles[local.id] = local;
    }
    
    for (final server in serverProfiles) {
      final existing = mergedProfiles[server.id];
      if (existing == null) {
        mergedProfiles[server.id] = server;
      } else {
        if (server.updatedAt.isAfter(existing.updatedAt)) {
          mergedProfiles[server.id] = server;
        }
      }
    }
    
    return mergedProfiles.values.toList();
  }

  /// Find profiles that exist only locally
  List<SshProfile> _findLocalOnlyProfiles(
    List<SshProfile> localProfiles,
    List<SshProfile> serverProfiles,
  ) {
    final serverIds = serverProfiles.map((p) => p.id).toSet();
    return localProfiles.where((local) => !serverIds.contains(local.id)).toList();
  }

  /// Find profiles that exist only on server
  List<SshProfile> _findServerOnlyProfiles(
    List<SshProfile> localProfiles,
    List<SshProfile> serverProfiles,
  ) {
    final localIds = localProfiles.map((p) => p.id).toSet();
    return serverProfiles.where((server) => !localIds.contains(server.id)).toList();
  }

  /// Get server profiles directly
  Future<List<SshProfile>> _getServerProfiles() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>('/ssh/profiles');
      
      if (response.isSuccess && response.data != null) {
        final responseData = response.data!;
        final profilesData = responseData['profiles'] as List<dynamic>? ?? [];
        
        return profilesData
            .map((json) => SshProfile.fromJson(json))
            .toList();
      }
      
      debugPrint('Failed to get server profiles: ${response.errorMessage}');
      return [];
      
    } catch (e) {
      debugPrint('Error getting server profiles: $e');
      return [];
    }
  }

  /// Upload profile to server
  Future<bool> _uploadProfileToServer(SshProfile profile) async {
    try {
      final response = await _apiClient.post(
        '/ssh/profiles',
        data: profile.toJson(),
      );
      return response.isSuccess;
    } catch (e) {
      debugPrint('Error uploading profile to server: $e');
      return false;
    }
  }

  /// Get sync configuration
  Future<SyncConfig> getSyncConfig() async {
    try {
      final configStr = await _storage.read(key: _syncConfigKey);
      if (configStr != null) {
        final configJson = jsonDecode(configStr);
        return SyncConfig.fromJson(configJson);
      }
    } catch (e) {
      debugPrint('Error loading sync config: $e');
    }
    return const SyncConfig();
  }

  /// Save sync configuration
  Future<void> saveSyncConfig(SyncConfig config) async {
    try {
      final configStr = jsonEncode(config.toJson());
      await _storage.write(key: _syncConfigKey, value: configStr);
    } catch (e) {
      debugPrint('Error saving sync config: $e');
    }
  }

  /// Store pending conflict for UI resolution
  Future<void> _storePendingConflict(DataInconsistency inconsistency) async {
    try {
      final conflictStr = jsonEncode(inconsistency.toJson());
      await _storage.write(key: 'pending_sync_conflict', value: conflictStr);
    } catch (e) {
      debugPrint('Error storing pending conflict: $e');
    }
  }

  /// Get pending conflict
  Future<DataInconsistency?> getPendingConflict() async {
    try {
      final conflictStr = await _storage.read(key: 'pending_sync_conflict');
      if (conflictStr != null) {
        final conflictJson = jsonDecode(conflictStr);
        return DataInconsistency(
          type: InconsistencyType.values.firstWhere(
            (t) => t.name == conflictJson['type'],
            orElse: () => InconsistencyType.none,
          ),
          description: conflictJson['description'],
        );
      }
    } catch (e) {
      debugPrint('Error loading pending conflict: $e');
    }
    return null;
  }

  /// Clear pending conflict
  Future<void> clearPendingConflict() async {
    try {
      await _storage.delete(key: 'pending_sync_conflict');
    } catch (e) {
      debugPrint('Error clearing pending conflict: $e');
    }
  }

  /// Update last sync time
  Future<void> _updateLastSyncTime() async {
    try {
      final now = DateTime.now().toIso8601String();
      await _storage.write(key: _lastSyncTimeKey, value: now);
    } catch (e) {
      debugPrint('Error updating last sync time: $e');
    }
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final timeStr = await _storage.read(key: _lastSyncTimeKey);
      if (timeStr != null) {
        return DateTime.parse(timeStr);
      }
    } catch (e) {
      debugPrint('Error getting last sync time: $e');
    }
    return null;
  }

  /// Check if sync is needed based on config
  Future<bool> isSyncNeeded() async {
    try {
      final config = await getSyncConfig();
      if (!config.autoSyncEnabled) return false;
      
      final lastSync = await getLastSyncTime();
      if (lastSync == null) return true;
      
      final now = DateTime.now();
      return now.difference(lastSync) > config.syncInterval;
    } catch (e) {
      debugPrint('Error checking if sync is needed: $e');
      return false;
    }
  }
}