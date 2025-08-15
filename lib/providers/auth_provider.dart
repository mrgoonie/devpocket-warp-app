import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/mock_auth_service.dart';
import '../main.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._authService) : super(const AuthState()) {
    _initialize();
  }

  final AuthService _authService;

  Future<void> _initialize() async {
    state = state.copyWith(status: AuthStatus.loading, isLoading: true);
    
    try {
      // Check if user has valid token
      final hasValidToken = await _authService.hasValidToken();
      if (hasValidToken) {
        // Try to get current user
        final user = await _authService.getCurrentUser();
        if (user != null) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            isLoading: false,
          );
          return;
        }
      }
      
      // No valid authentication
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.login(username, password);
      
      if (result.success && result.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: result.error ?? 'Login failed',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> register({
    required String email,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.register(email, username, password);
      
      if (result.success && result.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: result.error ?? 'Registration failed',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.signInWithGoogle();
      
      if (result.success && result.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: result.error ?? 'Google sign-in failed',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> signInWithGitHub() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final result = await _authService.signInWithGitHub();
      
      if (result.success && result.user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: result.user,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: result.error ?? 'GitHub sign-in failed',
          isLoading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.logout();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      // Even if logout fails, clear local state
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        error: null,
      );
    }
  }

  Future<void> refreshUser() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        state = state.copyWith(user: user);
      }
    } catch (e) {
      debugPrint('Failed to refresh user: $e');
    }
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? company,
    String? location,
  }) async {
    if (state.user == null) return;
    
    try {
      final updatedUser = await _authService.updateProfile(
        firstName: firstName,
        lastName: lastName,
        bio: bio,
        company: company,
        location: location,
      );
      
      if (updatedUser != null) {
        state = state.copyWith(user: updatedUser);
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<bool> requestPasswordReset(String email) async {
    try {
      return await _authService.requestPasswordReset(email);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    try {
      return await _authService.resetPassword(token, newPassword);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Providers
final authServiceProvider = Provider<AuthService>((ref) {
  // Use mock service for testing UI
  // Set this to false to use real API
  const bool useMockService = true;
  
  if (useMockService) {
    debugPrint('🎭 Using MockAuthService for testing');
    return MockAuthService();
  } else {
    debugPrint('🌐 Using real AuthService');
    return AuthService();
  }
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authProvider);
  return authState.user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isAuthenticated;
});

final isLoadingProvider = Provider<bool>((ref) {
  final authState = ref.watch(authProvider);
  return authState.isLoading;
});

// Onboarding provider
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(AppConstants.onboardingCompletedKey) ?? false;
    } catch (e) {
      state = false;
    }
  }

  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.onboardingCompletedKey, true);
      state = true;
    } catch (e) {
      debugPrint('Failed to save onboarding status: $e');
    }
  }

  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.onboardingCompletedKey, false);
      state = false;
    } catch (e) {
      debugPrint('Failed to reset onboarding status: $e');
    }
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});

// First launch check
final isFirstLaunchProvider = FutureProvider<bool>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final hasLaunchedBefore = prefs.getBool('has_launched_before') ?? false;
    
    if (!hasLaunchedBefore) {
      await prefs.setBool('has_launched_before', true);
      return true;
    }
    
    return false;
  } catch (e) {
    return true; // Assume first launch if error
  }
});

// Navigation helper
class NavigationHelper {
  static String getInitialRoute(AuthState authState, bool onboardingCompleted, bool isFirstLaunch) {
    if (isFirstLaunch && !onboardingCompleted) {
      return '/onboarding';
    }
    
    switch (authState.status) {
      case AuthStatus.authenticated:
        return '/main';
      case AuthStatus.unauthenticated:
        return '/login';
      case AuthStatus.loading:
      case AuthStatus.unknown:
      case AuthStatus.error:
        return '/splash';
    }
  }
}