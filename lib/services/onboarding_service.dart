import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'secure_storage_service.dart';

/// Onboarding service to manage onboarding flow and persistence
class OnboardingService {
  static OnboardingService? _instance;
  static OnboardingService get instance => _instance ??= OnboardingService._();

  OnboardingService._();

  final SecureStorageService _secureStorage = SecureStorageService.instance;

  // Stream controllers
  final StreamController<OnboardingState> _stateController = StreamController.broadcast();
  final StreamController<int> _currentStepController = StreamController.broadcast();

  // State
  OnboardingState _currentState = OnboardingState.unknown;
  int _currentStep = 0;
  bool _isInitialized = false;

  // Getters
  Stream<OnboardingState> get stateStream => _stateController.stream;
  Stream<int> get currentStepStream => _currentStepController.stream;
  OnboardingState get currentState => _currentState;
  int get currentStep => _currentStep;
  bool get isInitialized => _isInitialized;

  /// Initialize the onboarding service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing OnboardingService...');

      // Check if onboarding is completed
      final isCompleted = await _secureStorage.isOnboardingCompleted();
      
      if (isCompleted) {
        await _updateState(OnboardingState.completed);
      } else {
        await _updateState(OnboardingState.notStarted);
      }

      _isInitialized = true;
      debugPrint('✅ OnboardingService initialized - State: $_currentState');

    } catch (e) {
      debugPrint('❌ Error initializing OnboardingService: $e');
      await _updateState(OnboardingState.error);
    }
  }

  /// Check if user has completed onboarding
  Future<bool> isOnboardingCompleted() async {
    try {
      return await _secureStorage.isOnboardingCompleted();
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return false;
    }
  }

  /// Start onboarding process
  Future<void> startOnboarding() async {
    try {
      debugPrint('Starting onboarding process...');
      
      await _updateState(OnboardingState.inProgress);
      await _updateCurrentStep(0);
      
      // Store onboarding start time for analytics
      await _secureStorage.store('onboarding_started_at', DateTime.now().toIso8601String());
      
    } catch (e) {
      debugPrint('Error starting onboarding: $e');
      await _updateState(OnboardingState.error);
    }
  }

  /// Move to next onboarding step
  Future<void> nextStep() async {
    try {
      final newStep = _currentStep + 1;
      await _updateCurrentStep(newStep);
      
      debugPrint('Moved to onboarding step: $newStep');
      
    } catch (e) {
      debugPrint('Error moving to next step: $e');
    }
  }

  /// Move to previous onboarding step
  Future<void> previousStep() async {
    try {
      if (_currentStep > 0) {
        final newStep = _currentStep - 1;
        await _updateCurrentStep(newStep);
        
        debugPrint('Moved to onboarding step: $newStep');
      }
      
    } catch (e) {
      debugPrint('Error moving to previous step: $e');
    }
  }

  /// Jump to specific onboarding step
  Future<void> goToStep(int step) async {
    try {
      await _updateCurrentStep(step);
      debugPrint('Jumped to onboarding step: $step');
      
    } catch (e) {
      debugPrint('Error jumping to step: $e');
    }
  }

  /// Complete onboarding process
  Future<void> completeOnboarding() async {
    try {
      debugPrint('Completing onboarding process...');
      
      // Mark onboarding as completed
      await _secureStorage.markOnboardingCompleted();
      
      // Store completion time for analytics
      await _secureStorage.store('onboarding_completed_at', DateTime.now().toIso8601String());
      
      // Update state
      await _updateState(OnboardingState.completed);
      await _updateCurrentStep(0); // Reset step counter
      
      debugPrint('✅ Onboarding completed successfully');
      
    } catch (e) {
      debugPrint('❌ Error completing onboarding: $e');
      await _updateState(OnboardingState.error);
      rethrow;
    }
  }

  /// Skip onboarding (same as completing)
  Future<void> skipOnboarding() async {
    try {
      debugPrint('Skipping onboarding process...');
      
      // Mark onboarding as completed
      await _secureStorage.markOnboardingCompleted();
      
      // Store skip time for analytics
      await _secureStorage.store('onboarding_skipped_at', DateTime.now().toIso8601String());
      
      // Update state
      await _updateState(OnboardingState.completed);
      await _updateCurrentStep(0);
      
      debugPrint('✅ Onboarding skipped successfully');
      
    } catch (e) {
      debugPrint('❌ Error skipping onboarding: $e');
      await _updateState(OnboardingState.error);
      rethrow;
    }
  }

  /// Reset onboarding (for testing or re-onboarding)
  Future<void> resetOnboarding() async {
    try {
      debugPrint('Resetting onboarding process...');
      
      // Clear onboarding completion status
      await _secureStorage.resetOnboarding();
      
      // Clear analytics data
      await _secureStorage.delete('onboarding_started_at');
      await _secureStorage.delete('onboarding_completed_at');
      await _secureStorage.delete('onboarding_skipped_at');
      
      // Update state
      await _updateState(OnboardingState.notStarted);
      await _updateCurrentStep(0);
      
      debugPrint('✅ Onboarding reset successfully');
      
    } catch (e) {
      debugPrint('❌ Error resetting onboarding: $e');
      await _updateState(OnboardingState.error);
      rethrow;
    }
  }

  /// Get onboarding analytics data
  Future<OnboardingAnalytics?> getOnboardingAnalytics() async {
    try {
      final startedAt = await _secureStorage.read('onboarding_started_at');
      final completedAt = await _secureStorage.read('onboarding_completed_at');
      final skippedAt = await _secureStorage.read('onboarding_skipped_at');
      final isCompleted = await _secureStorage.isOnboardingCompleted();
      
      if (startedAt == null) return null;
      
      final startTime = DateTime.parse(startedAt);
      DateTime? endTime;
      OnboardingCompletionType completionType = OnboardingCompletionType.incomplete;
      
      if (completedAt != null) {
        endTime = DateTime.parse(completedAt);
        completionType = OnboardingCompletionType.completed;
      } else if (skippedAt != null) {
        endTime = DateTime.parse(skippedAt);
        completionType = OnboardingCompletionType.skipped;
      }
      
      return OnboardingAnalytics(
        startedAt: startTime,
        completedAt: endTime,
        completionType: completionType,
        duration: endTime?.difference(startTime),
        isCompleted: isCompleted,
      );
      
    } catch (e) {
      debugPrint('Error getting onboarding analytics: $e');
      return null;
    }
  }

  /// Store user preferences during onboarding
  Future<void> storeOnboardingPreference(String key, dynamic value) async {
    try {
      await _secureStorage.store('onboarding_pref_$key', value.toString());
    } catch (e) {
      debugPrint('Error storing onboarding preference: $e');
    }
  }

  /// Get user preferences from onboarding
  Future<String?> getOnboardingPreference(String key) async {
    try {
      return await _secureStorage.read('onboarding_pref_$key');
    } catch (e) {
      debugPrint('Error getting onboarding preference: $e');
      return null;
    }
  }

  /// Get all onboarding preferences
  Future<Map<String, String>> getAllOnboardingPreferences() async {
    try {
      final allData = await _secureStorage.readAll();
      final preferences = <String, String>{};
      
      for (final entry in allData.entries) {
        if (entry.key.startsWith('onboarding_pref_')) {
          final prefKey = entry.key.substring('onboarding_pref_'.length);
          preferences[prefKey] = entry.value;
        }
      }
      
      return preferences;
    } catch (e) {
      debugPrint('Error getting all onboarding preferences: $e');
      return {};
    }
  }

  // Private helper methods

  Future<void> _updateState(OnboardingState newState) async {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
    }
  }

  Future<void> _updateCurrentStep(int step) async {
    if (_currentStep != step) {
      _currentStep = step;
      _currentStepController.add(step);
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    await _stateController.close();
    await _currentStepController.close();
  }
}

/// Onboarding states
enum OnboardingState {
  unknown,
  notStarted,
  inProgress,
  completed,
  error,
}

/// Onboarding completion types
enum OnboardingCompletionType {
  incomplete,
  completed,
  skipped,
}

/// Onboarding analytics data
class OnboardingAnalytics {
  final DateTime startedAt;
  final DateTime? completedAt;
  final OnboardingCompletionType completionType;
  final Duration? duration;
  final bool isCompleted;

  const OnboardingAnalytics({
    required this.startedAt,
    this.completedAt,
    required this.completionType,
    this.duration,
    required this.isCompleted,
  });

  Map<String, dynamic> toJson() {
    return {
      'startedAt': startedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'completionType': completionType.name,
      'duration': duration?.inMilliseconds,
      'isCompleted': isCompleted,
    };
  }

  @override
  String toString() {
    return 'OnboardingAnalytics{startedAt: $startedAt, completedAt: $completedAt, '
        'completionType: $completionType, duration: $duration, isCompleted: $isCompleted}';
  }
}

// Providers

/// Provider for onboarding service
final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService.instance;
});

/// Provider for onboarding state stream
final onboardingStateProvider = StreamProvider<OnboardingState>((ref) {
  final service = ref.watch(onboardingServiceProvider);
  return service.stateStream;
});

/// Provider for current onboarding step stream
final onboardingCurrentStepProvider = StreamProvider<int>((ref) {
  final service = ref.watch(onboardingServiceProvider);
  return service.currentStepStream;
});

/// Provider for checking if onboarding is completed
final isOnboardingCompletedProvider = FutureProvider<bool>((ref) {
  final service = ref.watch(onboardingServiceProvider);
  return service.isOnboardingCompleted();
});

/// Provider for onboarding analytics
final onboardingAnalyticsProvider = FutureProvider<OnboardingAnalytics?>((ref) {
  final service = ref.watch(onboardingServiceProvider);
  return service.getOnboardingAnalytics();
});

/// Provider for onboarding preferences
final onboardingPreferencesProvider = FutureProvider<Map<String, String>>((ref) {
  final service = ref.watch(onboardingServiceProvider);
  return service.getAllOnboardingPreferences();
});