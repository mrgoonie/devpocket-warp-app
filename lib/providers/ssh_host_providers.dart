import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/ssh_profile_models.dart';
import '../models/ssh_sync_models.dart';
import '../services/ssh_host_service.dart';
import '../services/ssh_connection_test_service.dart';

/// SSH hosts state notifier with API integration
class SshHostsNotifier extends StateNotifier<AsyncValue<List<SshProfile>>> {
  SshHostsNotifier() : super(const AsyncValue.loading()) {
    _loadHosts();
  }
  
  final SshHostService _hostService = SshHostService.instance;
  final SshConnectionTestService _testService = SshConnectionTestService.instance;
  
  /// Load hosts from service
  Future<void> _loadHosts() async {
    try {
      state = const AsyncValue.loading();
      final hosts = await _hostService.getHosts();
      state = AsyncValue.data(hosts);
    } catch (e, stackTrace) {
      debugPrint('Error loading SSH hosts: $e');
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// Add a new host
  Future<bool> addHost(SshProfile host) async {
    try {
      final createdHost = await _hostService.createHost(host);
      if (createdHost != null) {
        final currentHosts = state.value ?? [];
        state = AsyncValue.data([...currentHosts, createdHost]);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding host: $e');
      return false;
    }
  }
  
  /// Update an existing host
  Future<bool> updateHost(SshProfile host) async {
    try {
      final updatedHost = await _hostService.updateHost(host.id, host);
      if (updatedHost != null) {
        final currentHosts = state.value ?? [];
        final updatedHosts = currentHosts
            .map((h) => h.id == host.id ? updatedHost : h)
            .toList();
        state = AsyncValue.data(updatedHosts);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating host: $e');
      return false;
    }
  }
  
  /// Delete a host
  Future<bool> deleteHost(String hostId) async {
    try {
      final success = await _hostService.deleteHost(hostId);
      if (success) {
        final currentHosts = state.value ?? [];
        final filteredHosts = currentHosts.where((h) => h.id != hostId).toList();
        state = AsyncValue.data(filteredHosts);
      }
      return success;
    } catch (e) {
      debugPrint('Error deleting host: $e');
      return false;
    }
  }
  
  /// Test connection to a host
  Future<SshConnectionTestResult> testConnection(SshProfile host) async {
    try {
      // Update host status to testing
      await _updateHostStatus(host.id, SshProfileStatus.testing);
      
      final result = await _testService.testConnectionWithTimeout(host);
      
      // Update host status based on result
      final newStatus = result.success 
          ? SshProfileStatus.active 
          : SshProfileStatus.failed;
      await _updateHostStatus(host.id, newStatus);
      
      return result;
    } catch (e) {
      debugPrint('Error testing connection: $e');
      await _updateHostStatus(host.id, SshProfileStatus.failed);
      return SshConnectionTestResult(
        success: false,
        error: 'Test failed: $e',
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// Update host status
  Future<void> _updateHostStatus(String hostId, SshProfileStatus status) async {
    final currentHosts = state.value ?? [];
    final hostIndex = currentHosts.indexWhere((h) => h.id == hostId);
    
    if (hostIndex >= 0) {
      final host = currentHosts[hostIndex];
      final updatedHost = host.copyWith(
        status: status,
        lastConnectedAt: status == SshProfileStatus.active ? DateTime.now() : null,
      );
      
      final updatedHosts = [...currentHosts];
      updatedHosts[hostIndex] = updatedHost;
      state = AsyncValue.data(updatedHosts);
      
      // Persist status update
      await _hostService.updateHost(hostId, updatedHost);
    }
  }
  
  /// Refresh hosts from server
  Future<void> refresh() async {
    await _loadHosts();
  }
  
  /// Enhanced sync with server using new sync methods
  Future<SyncResult> syncWithServer() async {
    try {
      final result = await _hostService.performFullSync();
      if (result.success) {
        await refresh();
      }
      return result;
    } catch (e) {
      debugPrint('Error syncing with server: $e');
      return SyncResult.error(e.toString());
    }
  }
  
  /// Sync local profiles to server
  Future<SyncResult> syncToServer() async {
    try {
      final result = await _hostService.syncLocalProfilesToServer();
      if (result.success) {
        await refresh();
      }
      return result;
    } catch (e) {
      debugPrint('Error syncing to server: $e');
      return SyncResult.error(e.toString());
    }
  }
  
  /// Sync server profiles to local
  Future<SyncResult> syncFromServer() async {
    try {
      final result = await _hostService.syncServerProfilesToLocal();
      if (result.success) {
        await refresh();
      }
      return result;
    } catch (e) {
      debugPrint('Error syncing from server: $e');
      return SyncResult.error(e.toString());
    }
  }
  
  /// Resolve pending sync conflicts
  Future<SyncResult> resolveConflict(SyncStrategy strategy) async {
    try {
      // Update sync config with user's choice
      final currentConfig = await _hostService.getSyncConfig();
      final newConfig = SyncConfig(
        defaultStrategy: strategy,
        autoSyncEnabled: currentConfig.autoSyncEnabled,
        syncInterval: currentConfig.syncInterval,
        conflictNotificationsEnabled: currentConfig.conflictNotificationsEnabled,
        backgroundSyncEnabled: currentConfig.backgroundSyncEnabled,
      );
      await _hostService.saveSyncConfig(newConfig);
      
      // Clear pending conflict
      await _hostService.clearPendingConflict();
      
      // Perform sync with the chosen strategy
      final result = await _hostService.performFullSync();
      if (result.success) {
        await refresh();
      }
      return result;
    } catch (e) {
      debugPrint('Error resolving conflict: $e');
      return SyncResult.error(e.toString());
    }
  }
  
  /// Test multiple hosts concurrently
  Future<Map<String, SshConnectionTestResult>> testAllHosts() async {
    final hosts = state.value ?? [];
    if (hosts.isEmpty) return {};
    
    try {
      // Update all hosts to testing status
      for (final host in hosts) {
        await _updateHostStatus(host.id, SshProfileStatus.testing);
      }
      
      final results = await _testService.testMultipleHosts(hosts);
      
      // Update host statuses based on results
      for (final entry in results.entries) {
        final hostId = entry.key;
        final result = entry.value;
        final newStatus = result.success 
            ? SshProfileStatus.active 
            : SshProfileStatus.failed;
        await _updateHostStatus(hostId, newStatus);
      }
      
      return results;
    } catch (e) {
      debugPrint('Error testing all hosts: $e');
      return {};
    }
  }
  
  /// Get host statistics
  Future<Map<String, dynamic>> getStats() async {
    return await _hostService.getHostStats();
  }
}

/// Connection test state notifier
class ConnectionTestNotifier extends StateNotifier<AsyncValue<SshConnectionTestResult?>> {
  ConnectionTestNotifier() : super(const AsyncValue.data(null));
  
  final SshConnectionTestService _testService = SshConnectionTestService.instance;
  
  /// Test connection to a specific host
  Future<void> testHost(SshProfile host) async {
    state = const AsyncValue.loading();
    
    try {
      final result = await _testService.testConnectionWithTimeout(host);
      state = AsyncValue.data(result);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// Clear test result
  void clearResult() {
    state = const AsyncValue.data(null);
  }
}

/// Host statistics notifier
class HostStatsNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  HostStatsNotifier() : super(const AsyncValue.loading()) {
    _loadStats();
  }
  
  final SshHostService _hostService = SshHostService.instance;
  
  Future<void> _loadStats() async {
    try {
      final stats = await _hostService.getHostStats();
      state = AsyncValue.data(stats);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// Refresh statistics
  Future<void> refresh() async {
    await _loadStats();
  }
}

// Providers
final sshHostsProvider = StateNotifierProvider<SshHostsNotifier, AsyncValue<List<SshProfile>>>((ref) {
  return SshHostsNotifier();
});

final connectionTestProvider = StateNotifierProvider<ConnectionTestNotifier, AsyncValue<SshConnectionTestResult?>>((ref) {
  return ConnectionTestNotifier();
});

final hostStatsProvider = StateNotifierProvider<HostStatsNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return HostStatsNotifier();
});

// Individual host provider
final sshHostProvider = Provider.family<SshProfile?, String>((ref, hostId) {
  final hostsAsync = ref.watch(sshHostsProvider);
  return hostsAsync.whenOrNull(
    data: (hosts) {
      try {
        return hosts.firstWhere((h) => h.id == hostId);
      } catch (e) {
        return null;
      }
    },
  );
});

// Host status provider
final hostStatusProvider = Provider.family<SshProfileStatus, String>((ref, hostId) {
  final host = ref.watch(sshHostProvider(hostId));
  return host?.status ?? SshProfileStatus.unknown;
});

// Active hosts count provider
final activeHostsCountProvider = Provider<int>((ref) {
  final hostsAsync = ref.watch(sshHostsProvider);
  return hostsAsync.whenOrNull(
    data: (hosts) => hosts.where((h) => h.status == SshProfileStatus.active).length,
  ) ?? 0;
});

// ===== SYNC STATE MANAGEMENT =====

/// Sync state notifier for managing SSH profile synchronization
class SyncStateNotifier extends StateNotifier<SyncState> {
  SyncStateNotifier() : super(const SyncState()) {
    _checkForPendingConflicts();
  }
  
  final SshHostService _hostService = SshHostService.instance;
  
  /// Check for pending conflicts on initialization
  Future<void> _checkForPendingConflicts() async {
    try {
      final conflict = await _hostService.getPendingConflict();
      if (conflict != null) {
        state = SyncState(
          status: SyncStatus.conflict,
          message: conflict.description,
          pendingConflict: conflict,
        );
      }
    } catch (e) {
      debugPrint('Error checking for pending conflicts: $e');
    }
  }
  
  /// Sync local profiles to server
  Future<void> syncToServer() async {
    state = const SyncState(status: SyncStatus.syncing, message: 'Uploading local profiles...');
    
    try {
      final result = await _hostService.syncLocalProfilesToServer();
      
      if (result.success) {
        state = SyncState(
          status: SyncStatus.success,
          message: 'Successfully synced ${result.successful} profile(s) to server',
          lastResult: result,
          lastSyncTime: DateTime.now(),
        );
      } else {
        state = SyncState(
          status: SyncStatus.error,
          message: result.error ?? 'Sync failed with unknown error',
          lastResult: result,
        );
      }
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        message: 'Sync failed: $e',
      );
    }
  }
  
  /// Sync server profiles to local
  Future<void> syncFromServer() async {
    state = const SyncState(status: SyncStatus.syncing, message: 'Downloading server profiles...');
    
    try {
      final result = await _hostService.syncServerProfilesToLocal();
      
      if (result.success) {
        state = SyncState(
          status: SyncStatus.success,
          message: 'Successfully synced ${result.successful} profile(s) from server',
          lastResult: result,
          lastSyncTime: DateTime.now(),
        );
      } else {
        state = SyncState(
          status: SyncStatus.error,
          message: result.error ?? 'Sync failed with unknown error',
          lastResult: result,
        );
      }
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        message: 'Sync failed: $e',
      );
    }
  }
  
  /// Perform full bidirectional sync
  Future<void> performFullSync() async {
    state = const SyncState(status: SyncStatus.syncing, message: 'Performing full sync...');
    
    try {
      final result = await _hostService.performFullSync();
      
      if (result.success) {
        state = SyncState(
          status: SyncStatus.success,
          message: result.total > 0 
              ? 'Successfully synced ${result.successful} profile(s)'
              : 'Profiles are already in sync',
          lastResult: result,
          lastSyncTime: DateTime.now(),
        );
      } else {
        // Check if failure is due to conflicts
        final conflict = await _hostService.getPendingConflict();
        if (conflict != null) {
          state = SyncState(
            status: SyncStatus.conflict,
            message: 'Sync conflicts detected - user intervention required',
            pendingConflict: conflict,
          );
        } else {
          state = SyncState(
            status: SyncStatus.error,
            message: result.error ?? 'Full sync failed with unknown error',
            lastResult: result,
          );
        }
      }
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        message: 'Full sync failed: $e',
      );
    }
  }
  
  /// Resolve conflicts with a specific strategy
  Future<void> resolveConflict(SyncStrategy strategy) async {
    final conflict = state.pendingConflict;
    if (conflict == null) return;
    
    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'Resolving conflicts with ${strategy.name} strategy...',
    );
    
    try {
      // Update sync config with chosen strategy
      final currentConfig = await _hostService.getSyncConfig();
      final newConfig = SyncConfig(
        defaultStrategy: strategy,
        autoSyncEnabled: currentConfig.autoSyncEnabled,
        syncInterval: currentConfig.syncInterval,
        conflictNotificationsEnabled: currentConfig.conflictNotificationsEnabled,
        backgroundSyncEnabled: currentConfig.backgroundSyncEnabled,
      );
      await _hostService.saveSyncConfig(newConfig);
      
      // Clear the conflict
      await _hostService.clearPendingConflict();
      
      // Perform sync with the chosen strategy
      final result = await _hostService.performFullSync();
      
      if (result.success) {
        state = SyncState(
          status: SyncStatus.success,
          message: 'Conflicts resolved successfully using ${strategy.name} strategy',
          lastResult: result,
          lastSyncTime: DateTime.now(),
        );
      } else {
        state = SyncState(
          status: SyncStatus.error,
          message: 'Failed to resolve conflicts: ${result.error}',
          lastResult: result,
        );
      }
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        message: 'Failed to resolve conflicts: $e',
      );
    }
  }
  
  /// Clear current sync status
  void clearStatus() {
    state = SyncState(
      lastSyncTime: state.lastSyncTime,
      lastResult: state.lastResult,
    );
  }
  
  /// Check if sync is needed
  Future<bool> isSyncNeeded() async {
    return await _hostService.isSyncNeeded();
  }
  
  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    return await _hostService.getLastSyncTime();
  }
}

/// Sync configuration notifier
class SyncConfigNotifier extends StateNotifier<AsyncValue<SyncConfig>> {
  SyncConfigNotifier() : super(const AsyncValue.loading()) {
    _loadConfig();
  }
  
  final SshHostService _hostService = SshHostService.instance;
  
  Future<void> _loadConfig() async {
    try {
      final config = await _hostService.getSyncConfig();
      state = AsyncValue.data(config);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// Update sync configuration
  Future<void> updateConfig(SyncConfig config) async {
    try {
      await _hostService.saveSyncConfig(config);
      state = AsyncValue.data(config);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
  
  /// Toggle auto sync
  Future<void> toggleAutoSync(bool enabled) async {
    final currentConfig = state.valueOrNull;
    if (currentConfig != null) {
      final newConfig = SyncConfig(
        defaultStrategy: currentConfig.defaultStrategy,
        autoSyncEnabled: enabled,
        syncInterval: currentConfig.syncInterval,
        conflictNotificationsEnabled: currentConfig.conflictNotificationsEnabled,
        backgroundSyncEnabled: currentConfig.backgroundSyncEnabled,
      );
      await updateConfig(newConfig);
    }
  }
  
  /// Update sync interval
  Future<void> updateSyncInterval(Duration interval) async {
    final currentConfig = state.valueOrNull;
    if (currentConfig != null) {
      final newConfig = SyncConfig(
        defaultStrategy: currentConfig.defaultStrategy,
        autoSyncEnabled: currentConfig.autoSyncEnabled,
        syncInterval: interval,
        conflictNotificationsEnabled: currentConfig.conflictNotificationsEnabled,
        backgroundSyncEnabled: currentConfig.backgroundSyncEnabled,
      );
      await updateConfig(newConfig);
    }
  }
}

// Host search provider
final hostSearchProvider = StateProvider<String>((ref) => '');

final filteredHostsProvider = Provider<AsyncValue<List<SshProfile>>>((ref) {
  final hostsAsync = ref.watch(sshHostsProvider);
  final searchQuery = ref.watch(hostSearchProvider);
  
  return hostsAsync.whenOrNull(
    data: (hosts) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(hosts);
      }
      
      final filtered = hosts.where((host) {
        final query = searchQuery.toLowerCase();
        return host.name.toLowerCase().contains(query) ||
               host.host.toLowerCase().contains(query) ||
               host.username.toLowerCase().contains(query) ||
               host.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
      
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  ) ?? const AsyncValue.loading();
});

// ===== NEW SYNC PROVIDERS =====

/// SSH profiles sync state provider
final syncStateProvider = StateNotifierProvider<SyncStateNotifier, SyncState>((ref) {
  return SyncStateNotifier();
});

/// Sync configuration provider
final syncConfigProvider = StateNotifierProvider<SyncConfigNotifier, AsyncValue<SyncConfig>>((ref) {
  return SyncConfigNotifier();
});

/// Provider to check if sync is needed
final syncNeededProvider = FutureProvider<bool>((ref) async {
  final syncNotifier = ref.read(syncStateProvider.notifier);
  return await syncNotifier.isSyncNeeded();
});

/// Provider to get last sync time
final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final syncNotifier = ref.read(syncStateProvider.notifier);
  return await syncNotifier.getLastSyncTime();
});

/// Provider for sync status display message
final syncStatusMessageProvider = Provider<String>((ref) {
  final syncState = ref.watch(syncStateProvider);
  return syncState.displayMessage;
});

/// Provider to check if there are pending conflicts
final hasPendingConflictsProvider = Provider<bool>((ref) {
  final syncState = ref.watch(syncStateProvider);
  return syncState.hasConflict && syncState.pendingConflict != null;
});

/// Provider for sync button enabled state
final syncButtonEnabledProvider = Provider<bool>((ref) {
  final syncState = ref.watch(syncStateProvider);
  final hostsAsync = ref.watch(sshHostsProvider);
  
  // Disabled if currently syncing or if no hosts available
  return !syncState.isSyncing && hostsAsync.hasValue;
});

/// Provider for the currently selected SSH profile for terminal connection
final currentSshProfileProvider = StateProvider<SshProfile?>((ref) => null);