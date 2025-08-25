import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../models/user_model.dart';
import 'auth_persistence_service.dart' show AuthPersistenceService, AuthPersistenceState;
import 'secure_storage_service.dart';

/// App initialization service to handle startup processes
class AppInitializationService {
  static AppInitializationService? _instance;
  static AppInitializationService get instance => _instance ??= AppInitializationService._();

  AppInitializationService._();

  final AuthPersistenceService _authService = AuthPersistenceService.instance;
  final SecureStorageService _secureStorage = SecureStorageService.instance;

  bool _isInitialized = false;
  AppInitializationState _state = AppInitializationState.notStarted;

  final StreamController<AppInitializationState> _stateController = StreamController.broadcast();
  final StreamController<String> _statusController = StreamController.broadcast();

  // Getters
  bool get isInitialized => _isInitialized;
  AppInitializationState get state => _state;
  Stream<AppInitializationState> get stateStream => _stateController.stream;
  Stream<String> get statusStream => _statusController.stream;

  /// Initialize the entire app
  Future<AppInitializationResult> initialize() async {
    if (_isInitialized) {
      return AppInitializationResult.success();
    }

    try {
      _updateState(AppInitializationState.initializing);
      _updateStatus('Starting app initialization...');

      // Step 1: Initialize secure storage
      _updateStatus('Initializing secure storage...');
      await _secureStorage.initialize();
      debugPrint('✅ Secure storage initialized');

      // Step 2: Check onboarding status
      _updateStatus('Checking onboarding status...');
      final isOnboardingCompleted = await _secureStorage.isOnboardingCompleted();
      debugPrint('✅ Onboarding status: ${isOnboardingCompleted ? 'completed' : 'pending'}');

      // Step 3: Initialize authentication service
      _updateStatus('Initializing authentication...');
      await _authService.initialize();
      debugPrint('✅ Authentication service initialized');

      // Step 4: Check authentication state
      _updateStatus('Validating session...');
      final authState = _authService.currentState;
      final user = _authService.currentUser;
      
      debugPrint('✅ Authentication state: $authState');
      if (user != null) {
        debugPrint('✅ Authenticated user: ${user.email}');
      }

      // Step 5: Determine initial route
      _updateStatus('Determining initial route...');
      final initialRoute = _determineInitialRoute(
        isOnboardingCompleted: isOnboardingCompleted,
        authState: authState,
        user: user,
      );
      debugPrint('✅ Initial route: $initialRoute');

      _updateState(AppInitializationState.completed);
      _updateStatus('App initialization completed');
      _isInitialized = true;

      return AppInitializationResult.success(
        initialRoute: initialRoute,
        isOnboardingCompleted: isOnboardingCompleted,
        authState: null, // AuthState and AuthPersistenceState are different types
        user: user,
      );

    } catch (e) {
      debugPrint('❌ App initialization failed: $e');
      _updateState(AppInitializationState.failed);
      _updateStatus('Initialization failed: $e');

      return AppInitializationResult.error(
        message: 'App initialization failed: $e',
      );
    }
  }

  /// Reset initialization state (useful for testing or re-initialization)
  Future<void> reset() async {
    _isInitialized = false;
    _updateState(AppInitializationState.notStarted);
    _updateStatus('App reset');
  }

  /// Handle app resume (check for expired sessions)
  Future<void> handleAppResume() async {
    if (!_isInitialized) return;

    try {
      _updateStatus('Handling app resume...');

      // Check session validity
      final sessionInfo = await _authService.getSessionInfo();
      
      if (sessionInfo?.isAuthenticated == true) {
        // Check if session is still valid
        final isValid = await _authService.isSessionValid();
        
        if (!isValid) {
          debugPrint('Session expired during app background, attempting refresh');
          
          final refreshed = await _authService.refreshTokens();
          if (refreshed) {
            debugPrint('✅ Session refreshed successfully');
          } else {
            debugPrint('❌ Session refresh failed, user needs to re-authenticate');
          }
        }
        
        // Update last active time
        await _secureStorage.storeLastActiveTime();
      }

      _updateStatus('App resume handled');
    } catch (e) {
      debugPrint('Error handling app resume: $e');
      _updateStatus('App resume error: $e');
    }
  }

  /// Check for app updates or maintenance
  Future<AppHealthStatus> checkAppHealth() async {
    try {
      _updateStatus('Checking app health...');

      // Check API server health by testing session validation
      final sessionInfo = await _authService.getSessionInfo();
      final isServerHealthy = sessionInfo != null;
      
      if (!isServerHealthy) {
        return const AppHealthStatus(
          isHealthy: false,
          message: 'Server is currently unavailable. Please try again later.',
          requiresUpdate: false,
        );
      }

      // TODO: Add version check and maintenance mode check
      // This would typically involve calling a version endpoint
      
      return const AppHealthStatus(
        isHealthy: true,
        message: 'App is healthy',
        requiresUpdate: false,
      );

    } catch (e) {
      debugPrint('Health check failed: $e');
      return AppHealthStatus(
        isHealthy: false,
        message: 'Unable to check app health: $e',
        requiresUpdate: false,
      );
    }
  }

  String _determineInitialRoute({
    required bool isOnboardingCompleted,
    required AuthPersistenceState authState,
    required User? user,
  }) {
    // If onboarding is not completed, go to onboarding
    if (!isOnboardingCompleted) {
      return '/onboarding';
    }

    // If user is authenticated, go to main app
    if (authState == AuthPersistenceState.authenticated && user != null) {
      return '/main';
    }

    // If authentication state is unknown or user is not authenticated, go to login
    return '/login';
  }

  void _updateState(AppInitializationState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  void _updateStatus(String status) {
    debugPrint('🔄 Init: $status');
    _statusController.add(status);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _stateController.close();
    await _statusController.close();
  }
}

/// App initialization states
enum AppInitializationState {
  notStarted,
  initializing,
  completed,
  failed,
}

/// App initialization result
class AppInitializationResult {
  final bool isSuccess;
  final String? initialRoute;
  final bool? isOnboardingCompleted;
  final AuthState? authState;
  final User? user;
  final String? message;

  const AppInitializationResult._({
    required this.isSuccess,
    this.initialRoute,
    this.isOnboardingCompleted,
    this.authState,
    this.user,
    this.message,
  });

  factory AppInitializationResult.success({
    String? initialRoute,
    bool? isOnboardingCompleted,
    AuthState? authState,
    User? user,
  }) {
    return AppInitializationResult._(
      isSuccess: true,
      initialRoute: initialRoute,
      isOnboardingCompleted: isOnboardingCompleted,
      authState: authState,
      user: user,
    );
  }

  factory AppInitializationResult.error({String? message}) {
    return AppInitializationResult._(
      isSuccess: false,
      message: message,
    );
  }
}

/// App health status
class AppHealthStatus {
  final bool isHealthy;
  final String message;
  final bool requiresUpdate;
  final String? minimumVersion;
  final bool? isMaintenanceMode;

  const AppHealthStatus({
    required this.isHealthy,
    required this.message,
    required this.requiresUpdate,
    this.minimumVersion,
    this.isMaintenanceMode,
  });
}

/// Providers for app initialization

final appInitializationServiceProvider = Provider<AppInitializationService>((ref) {
  return AppInitializationService.instance;
});

final appInitializationStateProvider = StreamProvider<AppInitializationState>((ref) {
  final service = ref.watch(appInitializationServiceProvider);
  return service.stateStream;
});

final appInitializationStatusProvider = StreamProvider<String>((ref) {
  final service = ref.watch(appInitializationServiceProvider);
  return service.statusStream;
});