// ignore_for_file: unnecessary_brace_in_string_interps

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devpocket_warp_app/providers/auth_provider.dart';
import 'package:devpocket_warp_app/models/user_model.dart';
import 'package:devpocket_warp_app/services/enhanced_auth_service.dart';

/// Mock auth service for testing
class MockAuthService implements EnhancedAuthService {
  User? _currentUser;

  void setCurrentUser(User? user) {
    _currentUser = user;
  }

  @override
  Future<User?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<AuthResult> login({required String email, required String password}) async {
    // Mock login - always succeeds with a test user
    final testUser = User(
      id: 'test-user-id',
      email: email,
      username: email.split('@').first,
      firstName: 'Test',
      lastName: 'User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    setCurrentUser(testUser);
    return AuthResult(success: true, user: testUser);
  }

  @override
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    // Mock register - always succeeds
    final testUser = User(
      id: 'test-user-id',
      email: email,
      username: username,
      firstName: username,
      lastName: 'User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    setCurrentUser(testUser);
    return AuthResult(success: true, user: testUser);
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    // Mock Google sign-in
    final testUser = User(
      id: 'test-google-user-id',
      email: 'testuser@gmail.com',
      username: 'testuser',
      firstName: 'Google',
      lastName: 'User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    setCurrentUser(testUser);
    return AuthResult(success: true, user: testUser);
  }

  @override
  Future<bool> logout() async {
    setCurrentUser(null);
    return true;
  }

  @override
  Future<User?> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? company,
    String? location,
  }) async {
    if (_currentUser == null) return null;
    
    final updatedUser = _currentUser!.copyWith(
      firstName: firstName ?? _currentUser!.firstName,
      lastName: lastName ?? _currentUser!.lastName,
      bio: bio ?? _currentUser!.bio,
      company: company ?? _currentUser!.company,
      location: location ?? _currentUser!.location,
    );
    
    setCurrentUser(updatedUser);
    return updatedUser;
  }

  @override
  Future<bool> requestPasswordReset(String email) async {
    // Mock password reset request
    return true;
  }

  @override
  Future<bool> resetPassword({required String token, required String newPassword}) async {
    // Mock password reset
    return true;
  }

  @override
  Future<bool> isServerHealthy() async {
    // Mock server health check - always healthy
    return true;
  }

  @override
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // Mock password change - always succeeds
    return true;
  }

  @override
  Future<bool> verifyEmail(String token) async {
    // Mock email verification - always succeeds
    return true;
  }

  @override
  Future<bool> resendEmailVerification() async {
    // Mock resend verification - always succeeds
    return true;
  }

  @override
  Future<bool> refreshTokens() async {
    // Mock token refresh - always succeeds
    return true;
  }

  static EnhancedAuthService get instance => MockAuthService();
}

/// Create a widget tester with mock providers - supports both named and positional parameters
Widget createTestApp({Widget? child, ThemeData? theme, List<Override>? additionalOverrides}) {
  if (child == null) {
    throw ArgumentError('child parameter is required');
  }
  
  final mockAuthService = MockAuthService();
  
  // If child is DevPocketApp (which contains MaterialApp), just wrap with ProviderScope
  if (child.runtimeType.toString() == 'DevPocketApp') {
    return ProviderScope(
      overrides: [
        // Mock auth service
        authServiceProvider.overrideWithValue(mockAuthService),
        
        // Mock onboarding as completed to skip onboarding flow
        onboardingProvider.overrideWith((ref) => MockOnboardingNotifier(true)),
        
        // Mock first launch as false to skip first launch logic
        isFirstLaunchProvider.overrideWith((ref) => Future.value(false)),
        
        ...(additionalOverrides ?? []),
      ],
      child: child,
    );
  }
  
  // For other widgets, wrap in MaterialApp
  return MaterialApp(
    theme: theme,
    home: ProviderScope(
      overrides: [
        // Mock auth service
        authServiceProvider.overrideWithValue(mockAuthService),
        
        // Mock onboarding as completed to skip onboarding flow
        onboardingProvider.overrideWith((ref) => MockOnboardingNotifier(true)),
        
        // Mock first launch as false to skip first launch logic
        isFirstLaunchProvider.overrideWith((ref) => Future.value(false)),
        
        ...(additionalOverrides ?? []),
      ],
      child: child,
    ),
  );
}

/// Mock onboarding notifier
class MockOnboardingNotifier extends OnboardingNotifier {
  MockOnboardingNotifier(bool initialState) : super() {
    state = initialState;
  }

  @override
  Future<void> completeOnboarding() async {
    state = true;
  }

  @override
  Future<void> resetOnboarding() async {
    state = false;
  }
}

/// Mock auth notifier for testing specific auth states
class MockAuthNotifier extends AuthNotifier {
  MockAuthNotifier(AuthState initialState) : super(MockAuthService()) {
    state = initialState;
  }

  void updateState(AuthState newState) {
    state = newState;
  }
}

/// Test authentication states
class TestAuthStates {
  static const unauthenticated = AuthState();
  
  static final authenticated = AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'test-user-id',
      email: 'test@example.com',
      username: 'testuser',
      firstName: 'Test',
      lastName: 'User',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    ),
    isLoading: false,
  );
  
  static const loading = AuthState(
    status: AuthStatus.loading,
    isLoading: true,
  );
  
  static const error = AuthState(
    status: AuthStatus.error,
    error: 'Test error',
    isLoading: false,
  );
}

/// Helper to pump widget with proper settling for async operations
Future<void> pumpAppWidget(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  // Give time for initial async operations but avoid indefinite settling
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Main TestHelpers class with utility methods
class TestHelpers {
  // Screen size configurations
  static const Size iconOnlyScreen = Size(400, 800);
  static const Size narrowTabScreen = Size(600, 800);
  static const Size fullModeScreen = Size(800, 600);
  static const Size largePhone = Size(430, 932);
  static const Size smallTablet = Size(768, 1024);
  
  // Tab configuration
  static const List<IconData> tabIcons = [
    Icons.storage,
    Icons.terminal,
    Icons.history,
    Icons.code,
    Icons.settings,
  ];
  
  static const List<String> tabLabels = [
    'Vaults',
    'Terminal', 
    'History',
    'Code',
    'Settings',
  ];

  // Test timeout configuration
  static const Duration testTimeout = Duration(seconds: 30);

  /// Initialize test environment
  static void initializeTestEnvironment() {
    // Initialize test environment setup
    TestWidgetsFlutterBinding.ensureInitialized();
  }

  /// Create test app with proper providers - supports both named and positional parameters
  static Widget createTestApp({Widget? child, ThemeData? theme, List<Override>? additionalOverrides}) {
    if (child == null) {
      throw ArgumentError('child parameter is required');
    }
    
    final mockAuthService = MockAuthService();
    
    // If child is DevPocketApp (which contains MaterialApp), just wrap with ProviderScope
    if (child.runtimeType.toString() == 'DevPocketApp') {
      return ProviderScope(
        overrides: [
          // Mock auth service
          authServiceProvider.overrideWithValue(mockAuthService),
          
          // Mock onboarding as completed to skip onboarding flow
          onboardingProvider.overrideWith((ref) => MockOnboardingNotifier(true)),
          
          // Mock first launch as false to skip first launch logic
          isFirstLaunchProvider.overrideWith((ref) => Future.value(false)),
          
          ...(additionalOverrides ?? []),
        ],
        child: child,
      );
    }
    
    // For other widgets, wrap in MaterialApp
    return MaterialApp(
      theme: theme,
      home: ProviderScope(
        overrides: [
          // Mock auth service
          authServiceProvider.overrideWithValue(mockAuthService),
          
          // Mock onboarding as completed to skip onboarding flow
          onboardingProvider.overrideWith((ref) => MockOnboardingNotifier(true)),
          
          // Mock first launch as false to skip first launch logic
          isFirstLaunchProvider.overrideWith((ref) => Future.value(false)),
          
          ...(additionalOverrides ?? []),
        ],
        child: child,
      ),
    );
  }

  /// Change screen size for responsive testing
  static Future<void> changeScreenSize(WidgetTester tester, Size size) async {
    await tester.binding.setSurfaceSize(size);
    await tester.pumpAndSettle();
  }

  /// Safe pump method for avoiding test flakiness
  static Future<void> safePump(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 16));
  }

  /// Verify semantic labels are present
  static void verifySemanticLabels(WidgetTester tester, [List<String>? expectedLabels]) {
    expectedLabels ??= tabLabels;
    
    for (final label in expectedLabels) {
      expect(
        find.bySemanticsLabel(label),
        findsOneWidget,
        reason: 'Expected to find semantic label: $label',
      );
    }
  }

  /// Verify no semantic labels are present (icon-only mode)
  static void verifyNoSemanticLabels(WidgetTester tester, [List<String>? labels]) {
    labels ??= tabLabels;
    
    for (final label in labels) {
      expect(
        find.bySemanticsLabel(label),
        findsNothing,
        reason: 'Expected NOT to find semantic label in icon-only mode: $label',
      );
    }
  }

  /// Verify minimum tap targets for accessibility
  static void verifyMinimumTapTargets(WidgetTester tester, [double minTapTargetSize = 44.0]) {
    final gestures = tester.allWidgets.whereType<GestureDetector>();
    
    for (final gesture in gestures) {
      final renderBox = tester.renderObject(find.byWidget(gesture)) as RenderBox?;
      if (renderBox != null) {
        final size = renderBox.size;
        expect(
          size.width >= minTapTargetSize && size.height >= minTapTargetSize,
          isTrue,
          reason: 'Tap target should be at least ${minTapTargetSize}x${minTapTargetSize} pixels for accessibility. Found: ${size.width}x${size.height}',
        );
      }
    }
  }

  /// Verify full mode display (labels + icons)
  static void verifyFullMode(WidgetTester tester, [List<String>? expectedLabels]) {
    expectedLabels ??= tabLabels;
    
    // Should show both icons and labels
    for (int i = 0; i < expectedLabels.length; i++) {
      final label = expectedLabels[i];
      final icon = tabIcons[i];
      
      expect(
        find.byIcon(icon),
        findsAtLeastNWidgets(1),
        reason: 'Expected to find icon in full mode: $icon',
      );
      
      expect(
        find.text(label),
        findsAtLeastNWidgets(1),
        reason: 'Expected to find text label in full mode: $label',
      );
    }
  }

  /// Verify icon-only mode display
  static void verifyIconOnlyMode(WidgetTester tester, [List<String>? labels]) {
    labels ??= tabLabels;
    
    // Should show icons but not labels
    for (int i = 0; i < labels.length; i++) {
      final label = labels[i];
      final icon = tabIcons[i];
      
      expect(
        find.byIcon(icon),
        findsAtLeastNWidgets(1),
        reason: 'Expected to find icon in icon-only mode: $icon',
      );
      
      // Labels should not be visible in icon-only mode
      expect(
        find.text(label),
        findsNothing,
        reason: 'Expected NOT to find text label in icon-only mode: $label',
      );
    }
  }

  /// Verify font size is within expected range
  static void verifyFontSizeInRange(WidgetTester tester, {double minSize = 12.0, double maxSize = 24.0}) {
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    
    for (final textWidget in textWidgets) {
      final style = textWidget.style;
      if (style?.fontSize != null) {
        final fontSize = style!.fontSize!;
        expect(
          fontSize,
          inInclusiveRange(minSize, maxSize),
          reason: 'Font size $fontSize should be between $minSize and $maxSize',
        );
      }
    }
  }

  /// Verify text doesn't overflow
  static void verifyTextOverflow(WidgetTester tester) {
    final renderObjectList = tester.allRenderObjects.whereType<RenderParagraph>();
    
    for (final renderObject in renderObjectList) {
      // Check if text overflows by comparing size with constraints
      final constraints = renderObject.constraints;
      final size = renderObject.size;
      
      if (constraints.hasBoundedWidth) {
        expect(
          size.width <= constraints.maxWidth,
          isTrue,
          reason: 'Text width (${size.width}) should not exceed max width constraint (${constraints.maxWidth})',
        );
      }
      
      if (constraints.hasBoundedHeight) {
        expect(
          size.height <= constraints.maxHeight,
          isTrue,
          reason: 'Text height (${size.height}) should not exceed max height constraint (${constraints.maxHeight})',
        );
      }
    }
  }

  /// Pump and settle with animations support
  static Future<void> pumpAndSettleWithAnimations(WidgetTester tester, {Duration timeout = const Duration(seconds: 10)}) async {
    await tester.pumpAndSettle(timeout);
  }

  /// Retry helper for flaky tests
  static Future<T> withRetry<T>(Future<T> Function() action, {int maxRetries = 3, Duration delay = const Duration(milliseconds: 100)}) async {
    Exception? lastException;
    
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await action();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (i < maxRetries - 1) {
          await Future.delayed(delay);
        }
      }
    }
    
    throw lastException!;
  }
}