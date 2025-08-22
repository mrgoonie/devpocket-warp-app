import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/subscription_service.dart';
import '../services/ssh_profile_service.dart';
import '../services/terminal_session_service.dart';
import '../services/websocket_manager.dart';
import '../services/openrouter_ai_service.dart';
import '../services/ai_command_service.dart';
import '../services/user_service.dart';
import '../services/preferences_sync_service.dart';
import '../models/subscription_models.dart';
import '../models/ssh_profile_models.dart';
import '../models/ai_chat_models.dart';
import '../models/user_models.dart';

// Core API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient.instance;
});

// Subscription Service Providers
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService.instance;
});

final currentSubscriptionProvider = FutureProvider<SubscriptionStatus?>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getCurrentSubscription();
});

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getAvailablePlans();
});

final paymentHistoryProvider = FutureProvider<List<PaymentHistoryEntry>>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getPaymentHistory();
});

// SSH Profile Service Providers
final sshProfileServiceProvider = Provider<SshProfileService>((ref) {
  return SshProfileService.instance;
});

final sshProfilesProvider = FutureProvider<List<SshProfile>>((ref) async {
  final service = ref.watch(sshProfileServiceProvider);
  return await service.getProfiles();
});

// SSH Profile State Provider
class SshProfilesNotifier extends StateNotifier<AsyncValue<List<SshProfile>>> {
  SshProfilesNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }
  
  final SshProfileService _service;
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final profiles = await _service.getProfiles();
      state = AsyncValue.data(profiles);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  Future<bool> createProfile(SshProfile profile) async {
    try {
      final created = await _service.createProfile(profile);
      if (created != null) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> updateProfile(String id, SshProfile profile) async {
    try {
      final updated = await _service.updateProfile(id, profile);
      if (updated != null) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> deleteProfile(String id) async {
    try {
      final success = await _service.deleteProfile(id);
      if (success) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<SshConnectionTestResult?> testConnection(SshProfile profile) async {
    try {
      return await _service.testConnection(profile);
    } catch (e) {
      return null;
    }
  }
}

final sshProfilesNotifierProvider = StateNotifierProvider<SshProfilesNotifier, AsyncValue<List<SshProfile>>>((ref) {
  final service = ref.watch(sshProfileServiceProvider);
  return SshProfilesNotifier(service);
});

// Terminal Session Service Providers
final terminalSessionServiceProvider = Provider<TerminalSessionService>((ref) {
  return TerminalSessionService.instance;
});

final terminalSessionsProvider = FutureProvider<List<TerminalSession>>((ref) async {
  final service = ref.watch(terminalSessionServiceProvider);
  return await service.getSessions();
});

final terminalStatsProvider = FutureProvider<TerminalStats?>((ref) async {
  final service = ref.watch(terminalSessionServiceProvider);
  return await service.getTerminalStats();
});

// Terminal Sessions State Provider
class TerminalSessionsNotifier extends StateNotifier<AsyncValue<List<TerminalSession>>> {
  TerminalSessionsNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }
  
  final TerminalSessionService _service;
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final sessions = await _service.getSessions();
      state = AsyncValue.data(sessions);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  Future<TerminalSession?> createLocalSession({String shell = '/bin/bash'}) async {
    try {
      final session = await _service.createLocalSession(shell: shell);
      if (session != null) {
        await refresh();
      }
      return session;
    } catch (e) {
      return null;
    }
  }
  
  Future<TerminalSession?> createSshSession(String sshProfileId) async {
    try {
      final session = await _service.createSshSession(sshProfileId);
      if (session != null) {
        await refresh();
      }
      return session;
    } catch (e) {
      return null;
    }
  }
  
  Future<bool> terminateSession(String sessionId) async {
    try {
      final success = await _service.terminateSession(sessionId);
      if (success) {
        await refresh();
      }
      return success;
    } catch (e) {
      return false;
    }
  }
  
  Future<List<String>> getSessionHistory(String sessionId) async {
    try {
      return await _service.getSessionHistory(sessionId);
    } catch (e) {
      return [];
    }
  }
}

final terminalSessionsNotifierProvider = StateNotifierProvider<TerminalSessionsNotifier, AsyncValue<List<TerminalSession>>>((ref) {
  final service = ref.watch(terminalSessionServiceProvider);
  return TerminalSessionsNotifier(service);
});

// WebSocket Manager Provider
final webSocketManagerProvider = Provider<WebSocketManager>((ref) {
  return WebSocketManager.instance;
});

// WebSocket State Provider
class WebSocketNotifier extends StateNotifier<WebSocketState> {
  WebSocketNotifier(this._manager) : super(WebSocketState.disconnected) {
    _manager.stateStream.listen((newState) {
      state = newState;
    });
  }
  
  final WebSocketManager _manager;
  
  Future<bool> connect() => _manager.connect();
  Future<void> disconnect() => _manager.disconnect();
  
  Future<bool> sendTerminalData(String data, {String? sessionId}) {
    return _manager.sendTerminalData(data, sessionId: sessionId);
  }
  
  Future<bool> resizeTerminal(int cols, int rows, {String? sessionId}) {
    return _manager.resizeTerminal(cols, rows, sessionId: sessionId);
  }
  
  Future<bool> sendControlCommand(String command, {String? sessionId}) {
    return _manager.sendControlCommand(command, sessionId: sessionId);
  }
}

final webSocketNotifierProvider = StateNotifierProvider<WebSocketNotifier, WebSocketState>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return WebSocketNotifier(manager);
});

// WebSocket Message Stream Provider
final webSocketMessageProvider = StreamProvider<TerminalMessage>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager.messageStream;
});

// Health Check Providers
final apiHealthProvider = FutureProvider<bool>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.healthCheck();
});

final paymentServiceHealthProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.isPaymentServiceHealthy();
});

// Feature Usage Providers
final sshConnectionUsageProvider = FutureProvider<FeatureUsage?>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getFeatureUsage('ssh_connections');
});

final aiRequestUsageProvider = FutureProvider<FeatureUsage?>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getFeatureUsage('ai_requests');
});

// Computed Providers
final canCreateSshProfileProvider = FutureProvider<bool>((ref) async {
  final usage = await ref.watch(sshConnectionUsageProvider.future);
  return usage?.isAtLimit != true;
});

final canMakeAiRequestProvider = FutureProvider<bool>((ref) async {
  final usage = await ref.watch(aiRequestUsageProvider.future);
  return usage?.isAtLimit != true;
});

// Subscription Status Helpers
final isProUserProvider = FutureProvider<bool>((ref) async {
  final subscription = await ref.watch(currentSubscriptionProvider.future);
  return subscription?.isPro == true;
});

final isTeamUserProvider = FutureProvider<bool>((ref) async {
  final subscription = await ref.watch(currentSubscriptionProvider.future);
  return subscription?.isTeam == true;
});

final hasActiveSubscriptionProvider = FutureProvider<bool>((ref) async {
  final subscription = await ref.watch(currentSubscriptionProvider.future);
  return subscription?.isActive == true;
});

// AI Service Providers
final openRouterAiServiceProvider = Provider<OpenRouterAiService>((ref) {
  return OpenRouterAiService.instance;
});

final aiCommandServiceProvider = Provider<AiCommandService>((ref) {
  return AiCommandService.instance;
});

// AI Configuration Providers
final aiApiKeyProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(openRouterAiServiceProvider);
  return await service.getApiKey();
});

final hasAiApiKeyProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(openRouterAiServiceProvider);
  return await service.hasApiKey();
});

final aiModelsProvider = FutureProvider<List<AiModel>>((ref) async {
  final service = ref.watch(openRouterAiServiceProvider);
  return await service.getModels();
});

final aiReadyProvider = FutureProvider<bool>((ref) async {
  final commandService = ref.watch(aiCommandServiceProvider);
  return await commandService.isReady();
});

// AI Command Results Stream Provider
final aiCommandResultsProvider = StreamProvider<AiCommandResult>((ref) {
  final commandService = ref.watch(aiCommandServiceProvider);
  return commandService.resultsStream;
});

// AI Usage Providers
final canUseAiProvider = FutureProvider<bool>((ref) async {
  final hasKey = await ref.watch(hasAiApiKeyProvider.future);
  final canMakeRequest = await ref.watch(canMakeAiRequestProvider.future);
  return hasKey && canMakeRequest;
});

// AI Models with Capabilities
final chatModelsProvider = FutureProvider<List<AiModel>>((ref) async {
  final service = ref.watch(openRouterAiServiceProvider);
  return await service.getModelsWithCapability(
    supportsStreaming: true,
    minContextLength: 4000,
  );
});

final functionCallingModelsProvider = FutureProvider<List<AiModel>>((ref) async {
  final service = ref.watch(openRouterAiServiceProvider);
  return await service.getModelsWithCapability(
    supportsToolCalling: true,
    minContextLength: 8000,
  );
});

// User Service Providers
final userServiceProvider = Provider<UserService>((ref) {
  return UserService.instance;
});

final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final service = ref.watch(userServiceProvider);
  final response = await service.getUserProfile();
  return response.isSuccess ? response.data : null;
});

final userPreferencesProvider = FutureProvider<UserPreferences?>((ref) async {
  final service = ref.watch(userServiceProvider);
  final response = await service.getUserPreferences();
  return response.isSuccess ? response.data : null;
});

final userDevicesProvider = FutureProvider<List<UserDevice>>((ref) async {
  final service = ref.watch(userServiceProvider);
  final response = await service.getUserDevices();
  return response.isSuccess ? response.data! : [];
});

// User Profile State Provider
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  UserProfileNotifier(this._service) : super(const AsyncValue.loading()) {
    refresh();
  }
  
  final UserService _service;
  
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final response = await _service.getUserProfile();
      state = AsyncValue.data(response.isSuccess ? response.data : null);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
  
  Future<bool> updateProfile(UserProfile profile) async {
    try {
      final response = await _service.updateUserProfile(profile);
      if (response.isSuccess) {
        state = AsyncValue.data(response.data);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> updateAvatar(List<int> imageBytes, String fileName) async {
    try {
      final response = await _service.updateAvatar(imageBytes, fileName);
      if (response.isSuccess) {
        // Refresh profile to get updated avatar URL
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> deleteAvatar() async {
    try {
      final response = await _service.deleteAvatar();
      if (response.isSuccess) {
        // Refresh profile to reflect avatar removal
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _service.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }
}

final userProfileNotifierProvider = StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  final service = ref.watch(userServiceProvider);
  return UserProfileNotifier(service);
});

// Preferences Sync Service Providers
final preferencesSyncServiceProvider = Provider<PreferencesSyncService>((ref) {
  return PreferencesSyncService.instance;
});

final syncStatusProvider = FutureProvider<SyncStatus>((ref) async {
  final service = ref.watch(preferencesSyncServiceProvider);
  return await service.getSyncStatus();
});

final lastSyncTimeProvider = FutureProvider<DateTime?>((ref) async {
  final service = ref.watch(preferencesSyncServiceProvider);
  return await service.getLastSyncTime();
});

final syncEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(preferencesSyncServiceProvider);
  return await service.isSyncEnabled();
});

// Preferences Sync State Provider
class PreferencesSyncNotifier extends StateNotifier<AsyncValue<SyncResult?>> {
  PreferencesSyncNotifier(this._service) : super(const AsyncValue.data(null));
  
  final PreferencesSyncService _service;
  
  Future<bool> syncNow({bool force = false}) async {
    state = const AsyncValue.loading();
    try {
      final result = force 
          ? await _service.forceSyncNow()
          : await _service.syncPreferences();
      
      state = AsyncValue.data(result);
      return result.success;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return false;
    }
  }
  
  Future<void> setSyncEnabled(bool enabled) async {
    await _service.setSyncEnabled(enabled);
  }
}

final preferencesSyncNotifierProvider = StateNotifierProvider<PreferencesSyncNotifier, AsyncValue<SyncResult?>>((ref) {
  final service = ref.watch(preferencesSyncServiceProvider);
  return PreferencesSyncNotifier(service);
});

// Settings Computed Providers
final isUserVerifiedProvider = Provider<bool>((ref) {
  final profile = ref.watch(userProfileProvider).maybeWhen(
    data: (profile) => profile?.emailVerified ?? false,
    orElse: () => false,
  );
  return profile;
});

final userSubscriptionProvider = Provider<UserSubscriptionStatus?>((ref) {
  return ref.watch(userProfileProvider).maybeWhen(
    data: (profile) => profile?.subscription,
    orElse: () => null,
  );
});

final hasProSubscriptionProvider = Provider<bool>((ref) {
  final subscription = ref.watch(userSubscriptionProvider);
  return subscription?.isPro == true;
});

final hasTeamSubscriptionProvider = Provider<bool>((ref) {
  final subscription = ref.watch(userSubscriptionProvider);
  return subscription?.isTeam == true;
});

final hasActiveSubscriptionProvider2 = Provider<bool>((ref) {
  final subscription = ref.watch(userSubscriptionProvider);
  return subscription?.isActive == true;
});