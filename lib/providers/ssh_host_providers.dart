import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../models/ssh_profile_models.dart';
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
  
  /// Sync with server
  Future<bool> syncWithServer() async {
    try {
      final success = await _hostService.syncWithServer();
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      debugPrint('Error syncing with server: $e');
      return false;
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