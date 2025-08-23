import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ssh_models.dart';

// Mock data providers for demonstration
// In a real app, these would connect to actual services/APIs

class HostsNotifier extends StateNotifier<AsyncValue<List<Host>>> {
  HostsNotifier() : super(const AsyncValue.loading()) {
    _loadHosts();
  }

  Future<void> _loadHosts() async {
    try {
      // Simulate API delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Mock hosts data
      final hosts = [
        HostFactory.create(
          name: 'Production Server',
          hostname: 'prod.example.com',
          username: 'ubuntu',
          description: 'Main production server',
          tags: ['production', 'web'],
          color: '#FF6B6B',
        ).copyWith(
          status: HostStatus.online,
          lastConnectedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        HostFactory.create(
          name: 'Development Server',
          hostname: 'dev.example.com', 
          username: 'developer',
          description: 'Development environment',
          tags: ['development', 'testing'],
          color: '#4ECDC4',
        ).copyWith(
          status: HostStatus.offline,
          lastConnectedAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      ];
      
      state = AsyncValue.data(hosts);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addHost(Host host) async {
    final current = state.value ?? [];
    state = AsyncValue.data([...current, host]);
  }

  Future<void> updateHost(Host host) async {
    final current = state.value ?? [];
    final updated = current.map((h) => h.id == host.id ? host : h).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> deleteHost(String hostId) async {
    final current = state.value ?? [];
    final updated = current.where((h) => h.id != hostId).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadHosts();
  }
}

class SSHKeysNotifier extends StateNotifier<AsyncValue<List<SSHKey>>> {
  SSHKeysNotifier() : super(const AsyncValue.loading()) {
    _loadKeys();
  }

  Future<void> _loadKeys() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Mock SSH keys data
      final keys = [
        SSHKeyFactory.create(
          name: 'Personal Key',
          type: 'rsa',
          publicKey: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC...',
          keySize: 2048,
          description: 'My personal RSA key',
        ),
        SSHKeyFactory.create(
          name: 'Work Key',
          type: 'ed25519',
          publicKey: 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...',
          keySize: 256,
          description: 'Work environment key',
        ),
      ];
      
      state = AsyncValue.data(keys);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addKey(SSHKey key) async {
    final current = state.value ?? [];
    state = AsyncValue.data([...current, key]);
  }

  Future<void> updateKey(SSHKey key) async {
    final current = state.value ?? [];
    final updated = current.map((k) => k.id == key.id ? key : k).toList();
    state = AsyncValue.data(updated);
  }

  Future<void> deleteKey(String keyId) async {
    final current = state.value ?? [];
    final updated = current.where((k) => k.id != keyId).toList();
    state = AsyncValue.data(updated);
  }
}

class ConnectionLogsNotifier extends StateNotifier<AsyncValue<List<ConnectionLog>>> {
  ConnectionLogsNotifier() : super(const AsyncValue.loading()) {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Mock connection logs
      final logs = [
        ConnectionLogFactory.create(
          hostId: '1',
          hostname: 'prod.example.com',
          username: 'ubuntu',
          success: true,
          duration: const Duration(minutes: 45),
          commandCount: 12,
          lastCommand: 'sudo systemctl status nginx',
        ),
        ConnectionLogFactory.create(
          hostId: '2',
          hostname: 'dev.example.com',
          username: 'developer',
          success: false,
          error: 'Connection timeout',
          message: 'Host unreachable',
        ),
      ];
      
      state = AsyncValue.data(logs);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  Future<void> addLog(ConnectionLog log) async {
    final current = state.value ?? [];
    state = AsyncValue.data([log, ...current]);
  }
}

// Providers
final hostsProvider = StateNotifierProvider<HostsNotifier, AsyncValue<List<Host>>>((ref) {
  return HostsNotifier();
});

final legacySshKeysProvider = StateNotifierProvider<SSHKeysNotifier, AsyncValue<List<SSHKey>>>((ref) {
  return SSHKeysNotifier();
});

final connectionLogsProvider = StateNotifierProvider<ConnectionLogsNotifier, AsyncValue<List<ConnectionLog>>>((ref) {
  return ConnectionLogsNotifier();
});

// Individual host provider
final hostProvider = Provider.family<Host?, String>((ref, hostId) {
  final hostsAsync = ref.watch(hostsProvider);
  return hostsAsync.whenOrNull(
    data: (hosts) => hosts.firstWhere((h) => h.id == hostId),
  );
});

// Host status provider
final hostStatusProvider = Provider.family<HostStatus, String>((ref, hostId) {
  final host = ref.watch(hostProvider(hostId));
  return host?.status ?? HostStatus.unknown;
});