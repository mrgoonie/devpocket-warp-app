import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

import '../models/ssh_models.dart';
import '../services/ssh_key_management_service.dart';

/// SSH Key Management Service Provider
final sshKeyManagementServiceProvider = Provider<SshKeyManagementService>((ref) {
  return SshKeyManagementService.instance;
});

/// SSH Keys State Notifier
class SshKeysNotifier extends StateNotifier<AsyncValue<List<SshKeyRecord>>> {
  SshKeysNotifier(this._sshKeyService) : super(const AsyncValue.loading()) {
    _initialize();
  }

  final SshKeyManagementService _sshKeyService;
  StreamSubscription? _eventSubscription;

  void _initialize() {
    // Listen to SSH key events
    _eventSubscription = _sshKeyService.events.listen((event) {
      debugPrint('SSH Key Event: ${event.type}');
      
      // Refresh keys on relevant events
      switch (event.type) {
        case SshKeyEventType.created:
        case SshKeyEventType.imported:
        case SshKeyEventType.updated:
        case SshKeyEventType.deleted:
        case SshKeyEventType.cleanup:
          refreshKeys();
          break;
        default:
          break;
      }
    });

    // Load initial keys
    refreshKeys();
  }

  /// Refresh SSH keys from storage
  Future<void> refreshKeys() async {
    try {
      debugPrint('Refreshing SSH keys...');
      state = const AsyncValue.loading();
      
      final keys = await _sshKeyService.getAllKeys();
      state = AsyncValue.data(keys);
      
      debugPrint('SSH keys refreshed: ${keys.length} keys found');
      
    } catch (e, stack) {
      debugPrint('Failed to refresh SSH keys: $e');
      state = AsyncValue.error(e, stack);
    }
  }

  /// Generate and store new SSH key
  Future<SshKeyRecord?> generateKey({
    required String name,
    required SshKeyType keyType,
    String? passphrase,
    String? comment,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Generating SSH key: $name');
      
      final keyRecord = await _sshKeyService.generateAndStoreKey(
        name: name,
        keyType: keyType,
        passphrase: passphrase,
        comment: comment,
        metadata: metadata,
      );
      
      // Keys will be refreshed via event listener
      return keyRecord;
      
    } catch (e) {
      debugPrint('Failed to generate SSH key: $e');
      rethrow;
    }
  }

  /// Import existing SSH key
  Future<SshKeyRecord?> importKey({
    required String name,
    required String publicKey,
    required String privateKey,
    String? passphrase,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('Importing SSH key: $name');
      
      final keyRecord = await _sshKeyService.importKey(
        name: name,
        publicKey: publicKey,
        privateKey: privateKey,
        passphrase: passphrase,
        metadata: metadata,
      );
      
      // Keys will be refreshed via event listener
      return keyRecord;
      
    } catch (e) {
      debugPrint('Failed to import SSH key: $e');
      rethrow;
    }
  }

  /// Delete SSH key
  Future<bool> deleteKey(String keyId) async {
    try {
      debugPrint('Deleting SSH key: $keyId');
      
      final deleted = await _sshKeyService.deleteKey(keyId);
      
      // Keys will be refreshed via event listener
      return deleted;
      
    } catch (e) {
      debugPrint('Failed to delete SSH key: $e');
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
      debugPrint('Updating SSH key metadata: $keyId');
      
      final updated = await _sshKeyService.updateKeyMetadata(
        keyId,
        name: name,
        metadata: metadata,
      );
      
      // Keys will be refreshed via event listener
      return updated;
      
    } catch (e) {
      debugPrint('Failed to update SSH key metadata: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }
}

/// SSH Keys Provider
final sshKeysProvider = StateNotifierProvider<SshKeysNotifier, AsyncValue<List<SshKeyRecord>>>((ref) {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  return SshKeysNotifier(sshKeyService);
});

/// SSH Key Statistics Provider
final sshKeyStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  
  // Watch the keys to trigger refresh when keys change
  ref.watch(sshKeysProvider);
  
  return sshKeyService.getKeyStatistics();
});

/// SSH Key Lookup Provider
final sshKeyProvider = Provider.family<AsyncValue<SshKeyRecord?>, String>((ref, keyId) {
  final keysState = ref.watch(sshKeysProvider);
  
  return keysState.when(
    data: (keys) {
      try {
        final key = keys.firstWhere((k) => k.id == keyId);
        return AsyncValue.data(key);
      } catch (e) {
        return const AsyncValue.data(null);
      }
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

/// SSH Key Pair Provider (with private key)
final sshKeyPairProvider = FutureProvider.family<SshKeyPair?, SshKeyPairRequest>((ref, request) async {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  
  return sshKeyService.getKeyPair(request.keyId, passphrase: request.passphrase);
});

/// Public Key Provider
final publicKeyProvider = FutureProvider.family<String?, String>((ref, keyId) async {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  
  return sshKeyService.getPublicKey(keyId);
});

/// Recently Used Keys Provider
final recentlyUsedKeysProvider = FutureProvider<List<SshKeyRecord>>((ref) async {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  
  // Watch the keys to trigger refresh when keys change
  ref.watch(sshKeysProvider);
  
  return sshKeyService.getRecentlyUsedKeys(withinDays: 30);
});

/// Keys by Type Provider
final keysByTypeProvider = Provider.family<List<SshKeyRecord>, SshKeyType>((ref, keyType) {
  final keysState = ref.watch(sshKeysProvider);
  
  return keysState.when(
    data: (keys) => keys.where((key) => key.keyType == keyType).toList(),
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Key Search Provider
final keySearchProvider = Provider.family<List<SshKeyRecord>, String>((ref, query) {
  final keysState = ref.watch(sshKeysProvider);
  
  if (query.isEmpty) {
    return keysState.when(
      data: (keys) => keys,
      loading: () => [],
      error: (_, __) => [],
    );
  }
  
  return keysState.when(
    data: (keys) {
      final lowerQuery = query.toLowerCase();
      return keys.where((key) {
        return key.name.toLowerCase().contains(lowerQuery) ||
               key.keyType.displayName.toLowerCase().contains(lowerQuery) ||
               key.fingerprint.toLowerCase().contains(lowerQuery);
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Recommended Key Types Provider
final recommendedKeyTypesProvider = Provider<List<SshKeyType>>((ref) {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  return sshKeyService.getRecommendedKeyTypes();
});

/// Key Generation Time Estimate Provider
final keyGenerationTimeProvider = Provider.family<Duration, SshKeyType>((ref, keyType) {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  return sshKeyService.estimateGenerationTime(keyType);
});

/// SSH Key Events Stream Provider
final sshKeyEventsProvider = StreamProvider<SshKeyEvent>((ref) {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  return sshKeyService.events;
});

/// Passphrase Validation Provider
final passphraseValidationProvider = FutureProvider.family<bool, PassphraseValidationRequest>((ref, request) async {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  
  return sshKeyService.validatePassphrase(request.keyId, request.passphrase);
});

/// SSH Key Actions Provider - For UI actions
final sshKeyActionsProvider = Provider<SshKeyActions>((ref) {
  final sshKeyService = ref.watch(sshKeyManagementServiceProvider);
  final keysNotifier = ref.read(sshKeysProvider.notifier);
  
  return SshKeyActions(
    sshKeyService: sshKeyService,
    keysNotifier: keysNotifier,
  );
});

/// Helper classes for provider parameters
class SshKeyPairRequest {
  final String keyId;
  final String? passphrase;

  const SshKeyPairRequest({
    required this.keyId,
    this.passphrase,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SshKeyPairRequest &&
          runtimeType == other.runtimeType &&
          keyId == other.keyId &&
          passphrase == other.passphrase;

  @override
  int get hashCode => keyId.hashCode ^ passphrase.hashCode;
}

class PassphraseValidationRequest {
  final String keyId;
  final String passphrase;

  const PassphraseValidationRequest({
    required this.keyId,
    required this.passphrase,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PassphraseValidationRequest &&
          runtimeType == other.runtimeType &&
          keyId == other.keyId &&
          passphrase == other.passphrase;

  @override
  int get hashCode => keyId.hashCode ^ passphrase.hashCode;
}

/// SSH Key Actions - UI helper methods
class SshKeyActions {
  final SshKeyManagementService sshKeyService;
  final SshKeysNotifier keysNotifier;

  const SshKeyActions({
    required this.sshKeyService,
    required this.keysNotifier,
  });

  /// Generate new SSH key
  Future<SshKeyRecord?> generateKey({
    required String name,
    required SshKeyType keyType,
    String? passphrase,
    String? comment,
    Map<String, dynamic>? metadata,
  }) async {
    return keysNotifier.generateKey(
      name: name,
      keyType: keyType,
      passphrase: passphrase,
      comment: comment,
      metadata: metadata,
    );
  }

  /// Import existing SSH key
  Future<SshKeyRecord?> importKey({
    required String name,
    required String publicKey,
    required String privateKey,
    String? passphrase,
    Map<String, dynamic>? metadata,
  }) async {
    return keysNotifier.importKey(
      name: name,
      publicKey: publicKey,
      privateKey: privateKey,
      passphrase: passphrase,
      metadata: metadata,
    );
  }

  /// Delete SSH key
  Future<bool> deleteKey(String keyId) async {
    return keysNotifier.deleteKey(keyId);
  }

  /// Update SSH key metadata
  Future<bool> updateKeyMetadata(
    String keyId, {
    String? name,
    Map<String, dynamic>? metadata,
  }) async {
    return keysNotifier.updateKeyMetadata(
      keyId,
      name: name,
      metadata: metadata,
    );
  }

  /// Export public key to clipboard
  Future<bool> copyPublicKey(String keyId) async {
    return sshKeyService.copyPublicKeyToClipboard(keyId);
  }

  /// Export public key to file
  Future<bool> exportPublicKey(String keyId, String filePath) async {
    return sshKeyService.exportPublicKeyToFile(keyId, filePath);
  }

  /// Validate key passphrase
  Future<bool> validatePassphrase(String keyId, String passphrase) async {
    return sshKeyService.validatePassphrase(keyId, passphrase);
  }

  /// Cleanup old keys
  Future<int> cleanupOldKeys({int maxAgeInDays = 365}) async {
    return sshKeyService.cleanupOldKeys(maxAgeInDays: maxAgeInDays);
  }

  /// Refresh keys manually
  Future<void> refreshKeys() async {
    return keysNotifier.refreshKeys();
  }
}