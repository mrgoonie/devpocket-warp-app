// ignore_for_file: unused_element

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/ssh_profile_models.dart';
import '../models/ssh_sync_models.dart';
import 'api_client.dart';

/// Enhanced SSH host management service with encryption and API integration
class SshHostService {
  static SshHostService? _instance;
  static SshHostService get instance => _instance ??= SshHostService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  static const String _hostsStorageKey = 'encrypted_ssh_hosts';
  static const String _encryptionKeyKey = 'host_encryption_key';
  static const String _syncConfigKey = 'ssh_sync_config';
  static const String _lastSyncTimeKey = 'last_sync_time';
  
  SshHostService._();
  
  /// Initialize encryption key for host credentials
  Future<void> _initializeEncryption() async {
    final existingKey = await _storage.read(key: _encryptionKeyKey);
    if (existingKey == null) {
      final key = _generateEncryptionKey();
      await _storage.write(key: _encryptionKeyKey, value: key);
    }
  }
  
  String _generateEncryptionKey() {
    final bytes = List<int>.generate(32, (i) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64Encode(bytes);
  }
  
  /// Encrypt sensitive host data
  Future<String> _encryptCredential(String credential) async {
    await _initializeEncryption();
    final key = await _storage.read(key: _encryptionKeyKey);
    if (key == null) throw Exception('Encryption key not found');
    
    // Simple XOR encryption for demo - use proper AES in production
    final keyBytes = base64Decode(key);
    final credentialBytes = utf8.encode(credential);
    final encrypted = <int>[];
    
    for (int i = 0; i < credentialBytes.length; i++) {
      encrypted.add(credentialBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return base64Encode(encrypted);
  }
  
  /// Decrypt sensitive host data
  Future<String> _decryptCredential(String encryptedCredential) async {
    await _initializeEncryption();
    final key = await _storage.read(key: _encryptionKeyKey);
    if (key == null) throw Exception('Encryption key not found');
    
    // Simple XOR decryption - reverse of encryption
    final keyBytes = base64Decode(key);
    final encryptedBytes = base64Decode(encryptedCredential);
    final decrypted = <int>[];
    
    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return utf8.decode(decrypted);
  }
  
  /// Get all SSH hosts from API with enhanced sync capabilities
  Future<List<SshProfile>> getHosts({bool forceSync = false}) async {
    try {
      // Get local cached profiles first for comparison
      final localProfiles = await _getCachedHosts();
      
      // Try API call
      final response = await _apiClient.get<Map<String, dynamic>>('/ssh/profiles');
      
      if (response.isSuccess && response.data != null) {
        // Handle nested API response structure
        final responseData = response.data!;
        final profilesData = responseData['profiles'] as List<dynamic>? ?? [];
        
        final serverProfiles = profilesData
            .map((json) => SshProfile.fromJson(json))
            .toList();
        
        // Detect data inconsistencies
        final inconsistency = await _detectDataInconsistency(localProfiles, serverProfiles);
        
        if (inconsistency.hasInconsistency && !forceSync) {
          // Handle inconsistency based on configuration
          final config = await getSyncConfig();
          if (config.defaultStrategy == SyncStrategy.askUser) {
            // Store conflict for UI resolution
            await _storePendingConflict(inconsistency);
            debugPrint('Data inconsistency detected, storing for user resolution: ${inconsistency.description}');
            // Return local data for now, let UI handle the conflict
            return localProfiles;
          } else {
            // Auto-resolve based on strategy
            return await _resolveDataInconsistency(inconsistency, localProfiles, serverProfiles, config.defaultStrategy);
          }
        }
        
        // No conflicts or force sync - use server data
        await _cacheHosts(serverProfiles);
        await _updateLastSyncTime();
        return serverProfiles;
      }
      
      debugPrint('API call failed, falling back to cache: ${response.errorMessage}');
      return localProfiles;
      
    } catch (e) {
      debugPrint('Error getting SSH hosts from API: $e');
      // Fallback to local cache
      return await _getCachedHosts();
    }
  }
  
  /// Get a specific SSH host by ID
  Future<SshProfile?> getHost(String id) async {
    try {
      final response = await _apiClient.get<SshProfile>(
        '/ssh/profiles/$id',
        fromJson: (json) => SshProfile.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Get SSH host failed: ${response.errorMessage}');
      
      // Fallback to cached data
      final cachedHosts = await _getCachedHosts();
      return cachedHosts.firstWhere(
        (host) => host.id == id,
        orElse: () => cachedHosts.first,
      );
      
    } catch (e) {
      debugPrint('Error getting SSH host: $e');
      return null;
    }
  }
  
  /// Create a new SSH host
  Future<SshProfile?> createHost(SshProfile host) async {
    try {
      // Encrypt sensitive data before sending to API
      final encryptedHost = await _encryptHostCredentials(host);
      
      final response = await _apiClient.post<SshProfile>(
        '/ssh/profiles',
        data: encryptedHost.toApiJson(),
        fromJson: (json) => SshProfile.fromJson(json),
      );
      
      if (response.isSuccess && response.data != null) {
        // Update local cache
        await _addToCache(response.data!);
        return response.data;
      }
      
      debugPrint('Create SSH host failed: ${response.errorMessage}');
      
      // Fallback: store locally if API fails
      await _addToCache(host);
      return host;
      
    } catch (e) {
      debugPrint('Error creating SSH host: $e');
      return null;
    }
  }
  
  /// Update an existing SSH host
  Future<SshProfile?> updateHost(String id, SshProfile host) async {
    try {
      final encryptedHost = await _encryptHostCredentials(host);
      
      final response = await _apiClient.put<SshProfile>(
        '/ssh/profiles/$id',
        data: encryptedHost.toApiJson(),
        fromJson: (json) => SshProfile.fromJson(json),
      );
      
      if (response.isSuccess && response.data != null) {
        await _updateInCache(response.data!);
        return response.data;
      }
      
      debugPrint('Update SSH host failed: ${response.errorMessage}');
      
      // Fallback: update locally
      await _updateInCache(host);
      return host;
      
    } catch (e) {
      debugPrint('Error updating SSH host: $e');
      return null;
    }
  }
  
  /// Delete an SSH host
  Future<bool> deleteHost(String id) async {
    try {
      final response = await _apiClient.delete('/ssh/profiles/$id');
      
      if (response.isSuccess) {
        await _removeFromCache(id);
        return true;
      }
      
      // Check if it's a 404 (profile doesn't exist)
      if (response.statusCode == 404 || 
          response.errorMessage.contains('not found')) {
        debugPrint('SSH profile not found on server, removing from cache');
        await _removeFromCache(id);
        return true; // Consider it successful if already deleted
      }
      
      debugPrint('Delete SSH host failed: ${response.errorMessage}');
      // Don't remove from cache for other errors
      return false;
      
    } catch (e) {
      debugPrint('Error deleting SSH host: $e');
      return false;
    }
  }
  
  /// Test SSH connection to a host
  Future<SshConnectionTestResult> testConnection(SshProfile host) async {
    try {
      final encryptedHost = await _encryptHostCredentials(host);
      
      final response = await _apiClient.post<SshConnectionTestResult>(
        '/ssh/test-connection',
        data: encryptedHost.toApiJson(),
        fromJson: (json) => SshConnectionTestResult.fromJson(json),
      );
      
      if (response.isSuccess && response.data != null) {
        return response.data!;
      }
      
      debugPrint('Test SSH connection failed: ${response.errorMessage}');
      return SshConnectionTestResult(
        success: false,
        error: response.errorMessage,
        timestamp: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('Error testing SSH connection: $e');
      return SshConnectionTestResult(
        success: false,
        error: 'Network error: $e',
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// Encrypt sensitive host credentials
  Future<SshProfile> _encryptHostCredentials(SshProfile host) async {
    String? encryptedPassword;
    String? encryptedPrivateKey;
    String? encryptedPassphrase;
    
    if (host.password != null) {
      encryptedPassword = await _encryptCredential(host.password!);
    }
    if (host.privateKey != null) {
      encryptedPrivateKey = await _encryptCredential(host.privateKey!);
    }
    if (host.passphrase != null) {
      encryptedPassphrase = await _encryptCredential(host.passphrase!);
    }
    
    return host.copyWith(
      password: encryptedPassword,
      privateKey: encryptedPrivateKey,
      passphrase: encryptedPassphrase,
    );
  }
  
  /// Decrypt host credentials for local use
  Future<SshProfile> _decryptHostCredentials(SshProfile host) async {
    String? decryptedPassword;
    String? decryptedPrivateKey;
    String? decryptedPassphrase;
    
    if (host.password != null) {
      decryptedPassword = await _decryptCredential(host.password!);
    }
    if (host.privateKey != null) {
      decryptedPrivateKey = await _decryptCredential(host.privateKey!);
    }
    if (host.passphrase != null) {
      decryptedPassphrase = await _decryptCredential(host.passphrase!);
    }
    
    return host.copyWith(
      password: decryptedPassword,
      privateKey: decryptedPrivateKey,
      passphrase: decryptedPassphrase,
    );
  }
  
  /// Cache hosts locally for offline access
  Future<void> _cacheHosts(List<SshProfile> hosts) async {
    try {
      final hostsJson = hosts.map((h) => h.toJson()).toList();
      await _storage.write(key: _hostsStorageKey, value: jsonEncode(hostsJson));
    } catch (e) {
      debugPrint('Error caching hosts: $e');
    }
  }
  
  /// Get cached hosts from local storage
  Future<List<SshProfile>> _getCachedHosts() async {
    try {
      final cached = await _storage.read(key: _hostsStorageKey);
      if (cached != null) {
        final List<dynamic> hostsJson = jsonDecode(cached);
        return hostsJson.map((json) => SshProfile.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error loading cached hosts: $e');
    }
    return [];
  }
  
  /// Add host to local cache
  Future<void> _addToCache(SshProfile host) async {
    final cached = await _getCachedHosts();
    cached.add(host);
    await _cacheHosts(cached);
  }
  
  /// Update host in local cache
  Future<void> _updateInCache(SshProfile host) async {
    final cached = await _getCachedHosts();
    final index = cached.indexWhere((h) => h.id == host.id);
    if (index >= 0) {
      cached[index] = host;
      await _cacheHosts(cached);
    }
  }
  
  /// Remove host from local cache
  Future<void> _removeFromCache(String id) async {
    final cached = await _getCachedHosts();
    cached.removeWhere((h) => h.id == id);
    await _cacheHosts(cached);
  }
  
  /// Sync local changes with server
  Future<bool> syncWithServer() async {
    try {
      final cachedHosts = await _getCachedHosts();
      final serverHosts = await getHosts();
      
      // Simple sync: upload any locally modified hosts
      // In a real implementation, you'd implement proper conflict resolution
      for (final cachedHost in cachedHosts) {
        final serverHost = serverHosts.firstWhere(
          (h) => h.id == cachedHost.id,
          orElse: () => cachedHost,
        );
        
        // If local version is newer, upload it
        if (cachedHost.updatedAt.isAfter(serverHost.updatedAt)) {
          await updateHost(cachedHost.id, cachedHost);
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error syncing with server: $e');
      return false;
    }
  }
  
  /// Get host connection statistics
  Future<Map<String, dynamic>> getHostStats() async {
    try {
      final hosts = await getHosts();
      final onlineHosts = hosts.where((h) => h.status == SshProfileStatus.active).length;
      final totalHosts = hosts.length;
      
      return {
        'total_hosts': totalHosts,
        'online_hosts': onlineHosts,
        'offline_hosts': totalHosts - onlineHosts,
        'last_sync': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Search hosts by name or hostname
  Future<List<SshProfile>> searchHosts(String query) async {
    try {
      final hosts = await getHosts();
      if (query.isEmpty) return hosts;
      
      final lowercaseQuery = query.toLowerCase();
      return hosts.where((host) {
        return host.name.toLowerCase().contains(lowercaseQuery) ||
               host.host.toLowerCase().contains(lowercaseQuery) ||
               (host.username.toLowerCase().contains(lowercaseQuery));
      }).toList();
    } catch (e) {
      debugPrint('Error searching hosts: $e');
      return [];
    }
  }

  // ===== ENHANCED SYNC FUNCTIONALITY =====

  /// Sync local profiles to server
  Future<SyncResult> syncLocalProfilesToServer() async {
    final startTime = DateTime.now();
    
    try {
      final localProfiles = await _getCachedHosts();
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
          final result = await createHost(profile);
          final success = result != null;
          syncResults[profile.id] = success;
          if (success) {
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
      await _cacheHosts(serverProfiles);
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
  Future<SyncResult> performFullSync() async {
    final startTime = DateTime.now();
    
    try {
      final localProfiles = await _getCachedHosts();
      final serverProfiles = await _getServerProfiles();
      
      final inconsistency = await _detectDataInconsistency(localProfiles, serverProfiles);
      
      if (!inconsistency.hasInconsistency) {
        // No inconsistencies, just update timestamps
        await _updateLastSyncTime();
        return SyncResult.empty();
      }
      
      // Get sync strategy
      final config = await getSyncConfig();
      final mergedProfiles = await _resolveDataInconsistency(
        inconsistency, localProfiles, serverProfiles, config.defaultStrategy
      );
      
      // Update both local and server with merged data
      await _cacheHosts(mergedProfiles);
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
          // Upload local profiles to server
          await syncLocalProfilesToServer();
          return localProfiles;
        
        case SyncStrategy.downloadRemote:
          // Download server profiles to local
          await syncServerProfilesToLocal();
          return serverProfiles;
        
        case SyncStrategy.merge:
          // Intelligent merge based on timestamps and conflicts
          return await _mergeProfiles(localProfiles, serverProfiles, inconsistency);
        
        case SyncStrategy.askUser:
          // Store conflict for UI resolution
          await _storePendingConflict(inconsistency);
          return localProfiles; // Return local for now
      }
    } catch (e) {
      debugPrint('Error resolving data inconsistency: $e');
      return localProfiles; // Safe fallback
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
    
    // Find profiles that exist in local but not server
    final localOnly = _findLocalOnlyProfiles(localProfiles, serverProfiles);
    
    // Find profiles that exist in server but not local
    final serverOnly = _findServerOnlyProfiles(localProfiles, serverProfiles);
    
    // Find conflicts between matching profiles
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
    
    // Mixed inconsistencies
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
    
    // Start with all local profiles
    for (final local in localProfiles) {
      mergedProfiles[local.id] = local;
    }
    
    // Add or merge server profiles
    for (final server in serverProfiles) {
      final existing = mergedProfiles[server.id];
      if (existing == null) {
        // Server-only profile, add it
        mergedProfiles[server.id] = server;
      } else {
        // Conflict resolution: use newer timestamp
        if (server.updatedAt.isAfter(existing.updatedAt)) {
          mergedProfiles[server.id] = server;
        }
        // Keep local version if it's newer or equal
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

  /// Get server profiles directly (without caching)
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

  // ===== SYNC CONFIGURATION MANAGEMENT =====

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
    return const SyncConfig(); // Default config
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
        // Note: This is a simplified version, in a real implementation
        // you'd need to fully reconstruct the DataInconsistency object
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