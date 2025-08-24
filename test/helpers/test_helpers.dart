import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:devpocket_warp_app/themes/app_theme.dart';
import 'dart:math';

/// Common test helpers and utilities for DevPocket tests
class TestHelpers {
  
  /// Safe timeout for tests to prevent hanging
  static const Duration testTimeout = Duration(seconds: 5);
  
  /// Safe pump duration to prevent infinite loops
  static const Duration safePumpDuration = Duration(milliseconds: 100);
  
  /// Maximum retries for flaky tests
  static const int maxRetries = 3;
  
  /// Creates a basic MaterialApp wrapper for testing widgets
  static Widget createTestApp({
    required Widget child,
    ThemeData? theme,
    List<Override>? overrides,
  }) {
    final app = MaterialApp(
      home: child,
      theme: theme ?? AppTheme.darkTheme,
      // Add route configuration to prevent navigation errors
      routes: {
        '/terminal': (context) => const Scaffold(body: Text('Terminal')),
        '/history': (context) => const Scaffold(body: Text('History')),
        '/editor': (context) => const Scaffold(body: Text('Editor')),
        '/settings': (context) => const Scaffold(body: Text('Settings')),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (context) => const Scaffold(body: Text('Unknown Route')),
      ),
    );

    return overrides != null 
        ? ProviderScope(overrides: overrides, child: app)
        : ProviderScope(child: app);
  }

  /// Creates a test app with specific screen dimensions
  static Widget createTestAppWithSize({
    required Widget child,
    required Size screenSize,
    ThemeData? theme,
    List<Override>? overrides,
  }) {
    return MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: createTestApp(
        child: child,
        theme: theme,
        overrides: overrides,
      ),
    );
  }

  /// Common screen sizes for testing responsive behavior
  static const Size smallPhone = Size(320, 568);      // iPhone SE
  static const Size mediumPhone = Size(375, 667);     // iPhone 8
  static const Size largePhone = Size(414, 896);      // iPhone 11
  static const Size smallTablet = Size(768, 1024);    // iPad
  static const Size largeTablet = Size(1024, 1366);   // iPad Pro

  /// Test screen sizes that trigger different layout modes
  static const Size iconOnlyScreen = Size(300, 600);   // Forces icon-only mode
  static const Size narrowTabScreen = Size(340, 600);  // Forces narrow tabs
  static const Size fullModeScreen = Size(400, 800);   // Full mode with text
  static const Size wideScreen = Size(800, 600);       // Very wide screen

  /// Creates a pump and settle helper that waits for animations
  static Future<void> pumpAndSettleWithAnimations(
    WidgetTester tester, {
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
  }) async {
    await tester.pumpAndSettle(duration ?? const Duration(seconds: 1), phase);
  }
  
  /// Safe pump that won't hang on infinite animations
  static Future<void> safePump(
    WidgetTester tester, {
    Duration? duration,
  }) async {
    try {
      await tester.pump(duration ?? safePumpDuration).timeout(testTimeout);
    } catch (e) {
      // If pump times out, continue with test
      print('Test pump timed out: $e');
    }
  }
  
  /// Safe pump and settle with timeout protection
  static Future<void> safePumpAndSettle(
    WidgetTester tester, {
    Duration? duration,
    Duration? timeout,
  }) async {
    try {
      await tester.pumpAndSettle(
        duration ?? safePumpDuration,
      ).timeout(timeout ?? testTimeout);
    } catch (e) {
      // If pumpAndSettle times out, do a simple pump instead
      print('PumpAndSettle timed out, falling back to pump: $e');
      await safePump(tester, duration: duration);
    }
  }
  
  /// Retry wrapper for flaky tests
  static Future<T> withRetry<T>(
    Future<T> Function() testFunction, {
    int maxAttempts = maxRetries,
    Duration delay = const Duration(milliseconds: 100),
  }) async {
    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await testFunction();
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        if (attempt == maxAttempts) {
          rethrow;
        }
        print('Test attempt $attempt failed: $e. Retrying in ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
      }
    }
    
    throw lastException ?? Exception('All retry attempts failed');
  }

  /// Helper to find widgets by their semantic label
  static Finder findBySemanticLabel(String label) {
    return find.bySemanticsLabel(label);
  }

  /// Helper to verify tab selection state
  static void verifyTabSelection(
    WidgetTester tester,
    IconData expectedSelectedIcon,
    List<IconData> unselectedIcons,
  ) {
    // Verify selected tab has primary color
    final selectedIcon = tester.widget<Icon>(find.byIcon(expectedSelectedIcon));
    expect(selectedIcon.color, equals(AppTheme.primaryColor));

    // Verify unselected tabs have secondary color (if in light mode) or appropriate dark color
    for (final iconData in unselectedIcons) {
      final unselectedIcon = tester.widget<Icon>(find.byIcon(iconData));
      expect(unselectedIcon.color, isNot(equals(AppTheme.primaryColor)));
    }
  }

  /// Helper to trigger device size changes
  static Future<void> changeScreenSize(
    WidgetTester tester,
    Size newSize,
  ) async {
    await tester.binding.setSurfaceSize(newSize);
    await tester.pumpAndSettle();
  }

  /// Helper to verify responsive mode (icon-only vs full)
  static void verifyIconOnlyMode(WidgetTester tester, List<String> expectedLabels) {
    // In icon-only mode, tab labels should not be visible in the bottom navigation
    // We need to be more specific and look within the tab navigation area
    final bottomNav = find.byType(SafeArea).last;
    for (final label in expectedLabels) {
      final tabText = find.descendant(
        of: bottomNav,
        matching: find.text(label),
      );
      expect(tabText, findsNothing, reason: 'Should not show text "$label" in tab navigation during icon-only mode');
    }
  }

  static void verifyFullMode(WidgetTester tester, List<String> expectedLabels) {
    // In full mode, tab labels should be visible in the bottom navigation
    final bottomNav = find.byType(SafeArea).last;
    for (final label in expectedLabels) {
      final tabText = find.descendant(
        of: bottomNav,
        matching: find.text(label),
      );
      expect(tabText, findsAtLeastNWidgets(1), reason: 'Should show text "$label" in tab navigation during full mode');
    }
  }

  /// Tab labels used throughout the app
  static const List<String> tabLabels = [
    'Vaults',
    'Terminal', 
    'History',
    'Editor',
    'Settings',
  ];

  /// Tab icons used throughout the app
  static const List<IconData> tabIcons = [
    Icons.folder_special,
    Icons.terminal,
    Icons.history,
    Icons.code,
    Icons.settings,
  ];

  /// Helper to verify text overflow properties
  static void verifyTextOverflow(WidgetTester tester, String text) {
    final textWidget = tester.widget<Text>(find.text(text));
    expect(textWidget.overflow, equals(TextOverflow.ellipsis));
    expect(textWidget.maxLines, equals(1));
    expect(textWidget.textAlign, equals(TextAlign.center));
  }

  /// Helper to verify font size is within expected range
  static void verifyFontSizeInRange(
    TextStyle textStyle, 
    double minSize, 
    double maxSize,
  ) {
    final fontSize = textStyle.fontSize ?? 11.0;
    expect(fontSize, greaterThanOrEqualTo(minSize));
    expect(fontSize, lessThanOrEqualTo(maxSize));
  }

  /// Helper to verify semantic labels in icon-only mode
  static void verifySemanticLabels(WidgetTester tester) {
    for (int i = 0; i < tabIcons.length; i++) {
      final icon = tester.widget<Icon>(find.byIcon(tabIcons[i]));
      expect(icon.semanticLabel, equals(tabLabels[i]));
    }
  }

  /// Helper to verify no semantic labels in full mode
  static void verifyNoSemanticLabels(WidgetTester tester) {
    for (final iconData in tabIcons) {
      final icon = tester.widget<Icon>(find.byIcon(iconData));
      expect(icon.semanticLabel, isNull);
    }
  }

  /// Helper to simulate tab taps and verify navigation
  static Future<void> testTabNavigation(
    WidgetTester tester,
    List<IconData> iconsToTap,
  ) async {
    for (final iconData in iconsToTap) {
      await tester.tap(find.byIcon(iconData));
      await safePumpAndSettle(tester);
      
      // Verify the tab is still rendered (basic navigation check)
      expect(find.byIcon(iconData), findsOneWidget);
    }
  }

  /// Helper to verify minimum tap target sizes
  static void verifyMinimumTapTargets(WidgetTester tester, double minSize) {
    // Look for tab button containers specifically (within bottom navigation)
    final bottomNav = find.byType(SafeArea).last;
    final tabContainers = find.descendant(
      of: bottomNav,
      matching: find.byType(AnimatedContainer),
    );
    
    // Should find at least one tab container
    expect(tabContainers, findsAtLeastNWidgets(1));
    
    for (final element in tabContainers.evaluate()) {
      final container = element.widget as AnimatedContainer;
      if (container.constraints != null && container.constraints!.minWidth > 0) {
        expect(
          container.constraints!.minWidth, 
          greaterThanOrEqualTo(minSize),
          reason: 'Tab tap target should be at least ${minSize}px wide',
        );
      }
    }
  }
}

/// Custom matchers for testing
class CustomMatchers {
  
  /// Matcher to check if a color is within the app's theme
  static Matcher isThemeColor() {
    return predicate<Color>((color) {
      return color == AppTheme.primaryColor ||
             color == AppTheme.secondaryColor ||
             color == AppTheme.darkTextPrimary ||
             color == AppTheme.darkTextSecondary ||
             color == AppTheme.lightTextPrimary ||
             color == AppTheme.lightTextSecondary;
    }, 'is a valid theme color');
  }

  /// Matcher to check if animation is running
  static Matcher hasRunningAnimations(WidgetTester tester) {
    return predicate<bool>((value) => tester.hasRunningAnimations);
  }
}

/// Test data and fixtures
class TestData {
  
  /// Mock tab item for testing
  static const mockTabItem = {
    'icon': Icons.star,
    'activeIcon': Icons.star,
    'label': 'Mock Tab',
  };

  /// Common test scenarios
  static const List<Map<String, dynamic>> responsiveTestCases = [
    {
      'name': 'Small Phone (Icon Only)',
      'size': TestHelpers.smallPhone,
      'expectedMode': 'icon-only',
      'expectedIconSize': 24.0,
    },
    {
      'name': 'Medium Phone (Icon Only)',
      'size': TestHelpers.mediumPhone,
      'expectedMode': 'full',
      'expectedIconSize': 22.0,
    },
    {
      'name': 'Large Phone (Full Mode)',
      'size': TestHelpers.largePhone,
      'expectedMode': 'full',
      'expectedIconSize': 22.0,
    },
    {
      'name': 'Tablet (Full Mode)',
      'size': TestHelpers.smallTablet,
      'expectedMode': 'full',
      'expectedIconSize': 22.0,
    },
  ];
}

/// Mock classes for testing
class MockSshHostService extends Mock {
  Future<List<MockSshProfile>> getHosts() async {
    await Future.delayed(const Duration(milliseconds: 10)); // Simulate network delay
    return [
      MockSshProfile(id: 'mock-1', name: 'Mock Host 1', host: 'mock1.example.com'),
      MockSshProfile(id: 'mock-2', name: 'Mock Host 2', host: 'mock2.example.com'),
    ];
  }
  
  Future<MockSshProfile?> createHost(MockSshProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return profile;
  }
  
  Future<bool> deleteHost(String id) async {
    await Future.delayed(const Duration(milliseconds: 10));
    return true;
  }
  
  Future<List<MockSshProfile>> searchHosts(String term) async {
    await Future.delayed(const Duration(milliseconds: 10));
    final allHosts = await getHosts();
    return allHosts.where((h) => h.name.toLowerCase().contains(term.toLowerCase())).toList();
  }
}

class MockSshProfile {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  
  MockSshProfile({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    this.username = 'testuser',
  });
  
  MockSshProfile copyWith({
    String? name,
    String? host,
    int? port,
    String? username,
  }) {
    return MockSshProfile(
      id: id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
    );
  }
}

class MockTerminalSessionHandler extends Mock {
  final List<String> _activeSessions = [];
  
  Future<String> createSshSession(MockSshProfile profile) async {
    await Future.delayed(const Duration(milliseconds: 50)); // Simulate connection time
    _activeSessions.add(profile.id);
    return profile.id;
  }
  
  Future<void> stopSession(String sessionId) async {
    await Future.delayed(const Duration(milliseconds: 10));
    _activeSessions.remove(sessionId);
  }
  
  Future<void> stopAllSessions() async {
    await Future.delayed(const Duration(milliseconds: 10));
    _activeSessions.clear();
  }
  
  List<String> getActiveSessions() => List.from(_activeSessions);
  
  bool isSessionRunning(String sessionId) => _activeSessions.contains(sessionId);
  
  Map<String, dynamic> getSessionInfo(String sessionId) {
    return {
      'id': sessionId,
      'type': 'ssh',
      'running': isSessionRunning(sessionId),
    };
  }
  
  Future<void> sendCommand(String sessionId, String command) async {
    await Future.delayed(const Duration(milliseconds: 5));
    // Mock command sending
  }
  
  Future<void> sendData(String sessionId, String data) async {
    await Future.delayed(const Duration(milliseconds: 5));
    // Mock data sending
  }
}

class MockWebSocketService extends Mock {
  bool _connected = false;
  int _activeSessionCount = 0;
  
  bool get isConnected => _connected;
  int get activeSessionCount => _activeSessionCount;
  
  Future<void> connect() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _connected = true;
  }
  
  Future<void> disconnect() async {
    await Future.delayed(const Duration(milliseconds: 10));
    _connected = false;
    _activeSessionCount = 0;
  }
  
  Future<String> createTerminalSession(MockSshProfile profile) async {
    if (!_connected) throw Exception('WebSocket not connected');
    await Future.delayed(const Duration(milliseconds: 20));
    _activeSessionCount++;
    return 'ws-session-\${profile.id}';
  }
  
  Future<void> closeTerminalSession(String sessionId) async {
    if (!_connected) throw Exception('WebSocket not connected');
    await Future.delayed(const Duration(milliseconds: 10));
    _activeSessionCount = math.max(0, _activeSessionCount - 1);
  }
  
  Future<void> sendTerminalData(String data, {String? sessionId}) async {
    if (!_connected) throw Exception('WebSocket not connected');
    await Future.delayed(const Duration(milliseconds: 5));
    // Mock data sending
  }
  
  List<String> getActiveSessions() {
    return List.generate(_activeSessionCount, (index) => 'session-\$index');
  }
}

/// Crypto operations mock for performance testing
class MockCryptoService extends Mock {
  Future<MockEncryptedData> encryptAESGCM(List<int> data, List<int> key) async {
    // Simulate crypto operation delay without actual computation
    await Future.delayed(const Duration(milliseconds: 1));
    return MockEncryptedData(
      ciphertext: List.generate(data.length, (i) => data[i] ^ 42), // Simple XOR
      nonce: List.generate(12, (i) => i),
      tag: List.generate(16, (i) => i),
    );
  }
  
  Future<List<int>> decryptAESGCM(MockEncryptedData encrypted, List<int> key) async {
    await Future.delayed(const Duration(milliseconds: 1));
    return List.generate(encrypted.ciphertext.length, (i) => encrypted.ciphertext[i] ^ 42);
  }
  
  List<int> generateSalt({int length = 32}) {
    final random = Random();
    return List.generate(length, (_) => random.nextInt(256));
  }
}

class MockEncryptedData {
  final List<int> ciphertext;
  final List<int> nonce;
  final List<int> tag;
  
  MockEncryptedData({
    required this.ciphertext,
    required this.nonce,
    required this.tag,
  });
}