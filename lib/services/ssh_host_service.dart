import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../models/ssh_profile_models.dart';
import '../models/ssh_models.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

/// Enhanced SSH host management service with encryption and API integration
class SshHostService {
  static SshHostService? _instance;
  static SshHostService get instance => _instance ??= SshHostService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  final SecureStorageService _secureStorage = SecureStorageService.instance;
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
    final key = await _storage.read(key: _encryptionKeyKey);
    if (key == null) throw Exception('Encryption key not found');
    
    final keyBytes = base64Decode(key);
    final encryptedBytes = base64Decode(encryptedCredential);
    final decrypted = <int>[];
    
    for (int i = 0; i < encryptedBytes.length; i++) {
      decrypted.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    
    return utf8.decode(decrypted);
  }
  
  /// Get all SSH hosts from API with fallback to local storage
  Future<List<SshProfile>> getHosts() async {
    try {
      // Try API first
      final response = await _apiClient.get<List<dynamic>>(
        '/ssh/profiles',
      );
      
      if (response.isSuccess && response.data != null) {
        final hosts = response.data!
            .map((json) => SshProfile.fromJson(json))
            .toList();
        
        // Cache successful API response locally
        await _cacheHosts(hosts);
        return hosts;
      }
      
      debugPrint('API call failed, falling back to cache: ${response.errorMessage}');
      return await _getCachedHosts();
      
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
      
      debugPrint('Delete SSH host failed: ${response.errorMessage}');
      
      // Even if API fails, remove from local cache
      await _removeFromCache(id);
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
        error: response.errorMessage ?? 'Connection test failed',
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
    
    try {
      if (host.password != null) {
        decryptedPassword = await _decryptCredential(host.password!);
      }
      if (host.privateKey != null) {
        decryptedPrivateKey = await _decryptCredential(host.privateKey!);
      }
      if (host.passphrase != null) {
        decryptedPassphrase = await _decryptCredential(host.passphrase!);
      }
    } catch (e) {
      debugPrint('Error decrypting credentials: $e');
      // Return original if decryption fails
      return host;
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
}