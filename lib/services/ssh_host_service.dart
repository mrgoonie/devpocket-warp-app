// ignore_for_file: unused_element

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

import '../models/ssh_profile_models.dart';
import '../models/ssh_sync_models.dart';
import 'api_client.dart';
import 'ssh_host_encryption.dart';
import 'ssh_host_sync_manager.dart';

/// Enhanced SSH host management service with encryption and API integration
class SshHostService {
  static SshHostService? _instance;
  static SshHostService get instance => _instance ??= SshHostService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  final SshHostEncryption _encryption = SshHostEncryption();
  final SshHostSyncManager _syncManager = SshHostSyncManager();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  static const String _hostsStorageKey = 'encrypted_ssh_hosts';
  
  SshHostService._();
  
  
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
        
        if (forceSync) {
          // Force sync requested - cache server data directly
          await _cacheHosts(serverProfiles);
          return serverProfiles;
        }
        
        // Use sync manager for intelligent sync handling
        final syncResult = await _syncManager.performFullSync(localProfiles);
        
        if (syncResult.success) {
          await _cacheHosts(serverProfiles);
          return serverProfiles;
        } else {
          debugPrint('Sync failed: ${syncResult.error}, returning local profiles');
          return localProfiles;
        }
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
      encryptedPassword = await _encryption.encryptCredential(host.password!);
    }
    if (host.privateKey != null) {
      encryptedPrivateKey = await _encryption.encryptCredential(host.privateKey!);
    }
    if (host.passphrase != null) {
      encryptedPassphrase = await _encryption.encryptCredential(host.passphrase!);
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
      decryptedPassword = await _encryption.decryptCredential(host.password!);
    }
    if (host.privateKey != null) {
      decryptedPrivateKey = await _encryption.decryptCredential(host.privateKey!);
    }
    if (host.passphrase != null) {
      decryptedPassphrase = await _encryption.decryptCredential(host.passphrase!);
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
    final localProfiles = await _getCachedHosts();
    return await _syncManager.syncLocalProfilesToServer(localProfiles);
  }

  /// Sync server profiles to local storage
  Future<SyncResult> syncServerProfilesToLocal() async {
    return await _syncManager.syncServerProfilesToLocal();
  }

  /// Perform bidirectional sync with intelligent conflict resolution
  Future<SyncResult> performFullSync() async {
    final localProfiles = await _getCachedHosts();
    return await _syncManager.performFullSync(localProfiles);
  }


  // ===== SYNC CONFIGURATION MANAGEMENT =====

  /// Get sync configuration
  Future<SyncConfig> getSyncConfig() async {
    return await _syncManager.getSyncConfig();
  }

  /// Save sync configuration
  Future<void> saveSyncConfig(SyncConfig config) async {
    return await _syncManager.saveSyncConfig(config);
  }

  /// Get pending conflict
  Future<DataInconsistency?> getPendingConflict() async {
    return await _syncManager.getPendingConflict();
  }

  /// Clear pending conflict
  Future<void> clearPendingConflict() async {
    return await _syncManager.clearPendingConflict();
  }

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    return await _syncManager.getLastSyncTime();
  }

  /// Check if sync is needed based on config
  Future<bool> isSyncNeeded() async {
    return await _syncManager.isSyncNeeded();
  }
}