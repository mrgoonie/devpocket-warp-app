import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../models/user_model.dart';
import 'api_client.dart';
import 'secure_storage_service.dart';

/// Authentication persistence service for handling automatic login and token refresh
class AuthPersistenceService {
  static AuthPersistenceService? _instance;
  static AuthPersistenceService get instance => _instance ??= AuthPersistenceService._();

  AuthPersistenceService._();

  final ApiClient _apiClient = ApiClient.instance;
  final SecureStorageService _secureStorage = SecureStorageService();
  
  // Stream controllers for authentication state
  final StreamController<AuthPersistenceState> _authStateController = StreamController.broadcast();
  final StreamController<User?> _userController = StreamController.broadcast();
  
  // Current state
  AuthPersistenceState _currentState = AuthPersistenceState.unknown;
  User? _currentUser;
  Timer? _tokenRefreshTimer;
  Timer? _sessionValidationTimer;

  // Getters
  Stream<AuthPersistenceState> get authStateStream => _authStateController.stream;
  Stream<User?> get userStream => _userController.stream;
  AuthPersistenceState get currentState => _currentState;
  User? get currentUser => _currentUser;

  /// Initialize the authentication service
  Future<void> initialize() async {
    debugPrint('Initializing AuthPersistenceService...');
    
    try {
      await _secureStorage.initialize();
      
      // Check if we have stored tokens
      final tokens = await _secureStorage.getAuthTokens();
      
      if (tokens != null && tokens['accessToken'] != null && tokens['refreshToken'] != null) {
        // Try to validate current session
        final user = await _validateStoredSession();
        
        if (user != null) {
          await _setAuthenticatedState(user);
          await _scheduleTokenRefresh();
        } else {
          // Tokens are invalid, try to refresh
          final refreshed = await _refreshTokens();
          
          if (refreshed) {
            final newUser = await _getCurrentUser();
            if (newUser != null) {
              await _setAuthenticatedState(newUser);
              await _scheduleTokenRefresh();
            } else {
              await _setUnauthenticatedState();
            }
          } else {
            await _setUnauthenticatedState();
          }
        }
      } else {
        await _setUnauthenticatedState();
      }
      
      // Start periodic session validation
      _startSessionValidation();
      
    } catch (e) {
      debugPrint('Error initializing AuthPersistenceService: $e');
      await _setUnauthenticatedState();
    }
  }

  /// Login with email and password
  Future<AuthResult> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    try {
      _updateAuthPersistenceState(AuthPersistenceState.authenticating);
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'remember_me': rememberMe,
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final accessToken = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final userJson = data['user'] as Map<String, dynamic>;
        final user = User.fromJson(userJson);

        // Store tokens securely
        await _secureStorage.storeAuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: user.id,
        );

        // Update last active time
        await _secureStorage.storeLastActiveTime();

        await _setAuthenticatedState(user);
        await _scheduleTokenRefresh();

        return AuthResult.success(
          user: user,
          message: 'Login successful',
        );
      } else {
        await _setUnauthenticatedState();
        return AuthResult.error(
          message: response.errorMessage,
          errors: response.errors,
        );
      }
    } catch (e) {
      debugPrint('Login error: $e');
      await _setUnauthenticatedState();
      return AuthResult.error(message: 'Login failed: $e');
    }
  }

  /// Register new user
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      _updateAuthPersistenceState(AuthPersistenceState.authenticating);

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'username': username,
          'password': password,
        },
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final accessToken = data['accessToken'] as String;
        final refreshToken = data['refreshToken'] as String;
        final userJson = data['user'] as Map<String, dynamic>;
        final user = User.fromJson(userJson);

        // Store tokens securely
        await _secureStorage.storeAuthTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          userId: user.id,
        );

        await _setAuthenticatedState(user);
        await _scheduleTokenRefresh();

        return AuthResult.success(
          user: user,
          message: 'Registration successful',
        );
      } else {
        await _setUnauthenticatedState();
        return AuthResult.error(
          message: response.errorMessage,
          errors: response.errors,
        );
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      await _setUnauthenticatedState();
      return AuthResult.error(message: 'Registration failed: $e');
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      // Cancel timers
      _tokenRefreshTimer?.cancel();
      _sessionValidationTimer?.cancel();

      // Notify server of logout
      try {
        await _apiClient.post('/auth/logout');
      } catch (e) {
        debugPrint('Error notifying server of logout: $e');
      }

      // Clear stored tokens and data
      await _secureStorage.clearAuthTokens();
      
      await _setUnauthenticatedState();
      
    } catch (e) {
      debugPrint('Logout error: $e');
      await _setUnauthenticatedState();
    }
  }

  /// Force refresh tokens
  Future<bool> refreshTokens() async {
    return await _refreshTokens();
  }

  /// Check if user session is valid
  Future<bool> isSessionValid() async {
    try {
      final user = await _getCurrentUser();
      return user != null;
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }

  /// Get session info
  Future<SessionInfo?> getSessionInfo() async {
    try {
      final tokens = await _secureStorage.getAuthTokens();
      final lastActiveTime = await _secureStorage.getLastActiveTime();
      
      if (tokens == null || tokens['accessToken'] == null) return null;
      
      return SessionInfo(
        isAuthenticated: _currentState == AuthPersistenceState.authenticated,
        userId: tokens['userId'],
        lastActiveTime: lastActiveTime,
        hasValidTokens: tokens['accessToken'] != null && tokens['refreshToken'] != null,
      );
    } catch (e) {
      debugPrint('Error getting session info: $e');
      return null;
    }
  }

  // Private methods

  Future<User?> _validateStoredSession() async {
    try {
      return await _getCurrentUser();
    } catch (e) {
      debugPrint('Session validation failed: $e');
      return null;
    }
  }

  Future<User?> _getCurrentUser() async {
    try {
      final response = await _apiClient.get<User>(
        '/auth/me',
        fromJson: (json) => User.fromJson(json),
      );

      if (response.isSuccess) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  Future<bool> _refreshTokens() async {
    try {
      final tokens = await _secureStorage.getAuthTokens();
      if (tokens == null) return false;
      final refreshToken = tokens['refreshToken'];
      
      if (refreshToken == null) return false;

      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final newAccessToken = data['accessToken'] as String;
        final newRefreshToken = data['refreshToken'] as String;

        await _secureStorage.storeAuthTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
          userId: tokens['userId'] ?? '',
        );

        debugPrint('Tokens refreshed successfully');
        return true;
      }

      debugPrint('Token refresh failed: ${response.errorMessage}');
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  Future<void> _scheduleTokenRefresh() async {
    _tokenRefreshTimer?.cancel();
    
    // Schedule refresh 5 minutes before expiration (default 50 minutes)
    const refreshInterval = Duration(minutes: 50);
    
    _tokenRefreshTimer = Timer(refreshInterval, () async {
      debugPrint('Automatic token refresh triggered');
      
      final refreshed = await _refreshTokens();
      if (refreshed) {
        await _scheduleTokenRefresh(); // Schedule next refresh
      } else {
        await _setUnauthenticatedState();
      }
    });
    
    debugPrint('Token refresh scheduled for ${refreshInterval.inMinutes} minutes');
  }

  void _startSessionValidation() {
    _sessionValidationTimer?.cancel();
    
    // Validate session every 10 minutes
    _sessionValidationTimer = Timer.periodic(
      const Duration(minutes: 10),
      (timer) async {
        if (_currentState == AuthPersistenceState.authenticated) {
          final isValid = await isSessionValid();
          if (!isValid) {
            debugPrint('Session validation failed, attempting refresh');
            
            final refreshed = await _refreshTokens();
            if (!refreshed) {
              await _setUnauthenticatedState();
            }
          } else {
            // Update last active time
            await _secureStorage.storeLastActiveTime();
          }
        }
      },
    );
  }

  Future<void> _setAuthenticatedState(User user) async {
    _currentUser = user;
    _updateAuthPersistenceState(AuthPersistenceState.authenticated);
    _updateUser(user);
    
    debugPrint('User authenticated: ${user.email}');
  }

  Future<void> _setUnauthenticatedState() async {
    _currentUser = null;
    _updateAuthPersistenceState(AuthPersistenceState.unauthenticated);
    _updateUser(null);
    
    // Cancel timers
    _tokenRefreshTimer?.cancel();
    
    debugPrint('User unauthenticated');
  }

  void _updateAuthPersistenceState(AuthPersistenceState state) {
    if (_currentState != state) {
      _currentState = state;
      _authStateController.add(state);
    }
  }

  void _updateUser(User? user) {
    _userController.add(user);
  }

  /// Dispose the service
  Future<void> dispose() async {
    _tokenRefreshTimer?.cancel();
    _sessionValidationTimer?.cancel();
    await _authStateController.close();
    await _userController.close();
  }
}

/// Authentication state enumeration
enum AuthPersistenceState {
  unknown,
  authenticated,
  unauthenticated,
  authenticating,
  refreshing,
}

/// Authentication result
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? message;
  final List<String>? errors;

  const AuthResult._({
    required this.isSuccess,
    this.user,
    this.message,
    this.errors,
  });

  factory AuthResult.success({User? user, String? message}) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      message: message,
    );
  }

  factory AuthResult.error({String? message, List<String>? errors}) {
    return AuthResult._(
      isSuccess: false,
      message: message,
      errors: errors,
    );
  }
}

/// Session information
class SessionInfo {
  final bool isAuthenticated;
  final String? userId;
  final DateTime? lastActiveTime;
  final bool hasValidTokens;

  const SessionInfo({
    required this.isAuthenticated,
    this.userId,
    this.lastActiveTime,
    required this.hasValidTokens,
  });

  Duration? get timeSinceLastActive {
    if (lastActiveTime == null) return null;
    return DateTime.now().difference(lastActiveTime!);
  }

  bool get isRecentlyActive {
    final timeSince = timeSinceLastActive;
    if (timeSince == null) return false;
    return timeSince.inHours < 24; // Consider active if within 24 hours
  }
}

/// Provider for auth persistence service
final authPersistenceServiceProvider = Provider<AuthPersistenceService>((ref) {
  return AuthPersistenceService.instance;
});

/// Provider for auth state stream
final authStateProvider = StreamProvider<AuthPersistenceState>((ref) {
  final service = ref.watch(authPersistenceServiceProvider);
  return service.authStateStream;
});

/// Provider for current user stream
final currentUserProvider = StreamProvider<User?>((ref) {
  final service = ref.watch(authPersistenceServiceProvider);
  return service.userStream;
});

/// Provider for session info
final sessionInfoProvider = FutureProvider<SessionInfo?>((ref) {
  final service = ref.watch(authPersistenceServiceProvider);
  return service.getSessionInfo();
});