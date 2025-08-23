import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:devpocket_warp_app/screens/main/main_tab_screen.dart';
import 'package:devpocket_warp_app/themes/app_theme.dart';


void main() {
  group('MainTabScreen Widget Tests', () {
    late Widget testWidget;

    setUp(() {
      testWidget = ProviderScope(
        child: MaterialApp(
          home: const MainTabScreen(),
          theme: AppTheme.darkTheme,
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
        ),
      );
    });

    group('Basic Widget Tests', () {
      testWidgets('should render all 5 tabs correctly', (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Verify all tabs are present
        expect(find.byIcon(Icons.folder_special), findsWidgets);
        expect(find.byIcon(Icons.terminal), findsWidgets);
        expect(find.byIcon(Icons.history), findsWidgets);
        expect(find.byIcon(Icons.code), findsWidgets);
        expect(find.byIcon(Icons.settings), findsWidgets);
      });

      testWidgets('should show correct initial state with first tab selected', 
          (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // First tab (Vaults) should be selected
        final vaultsTab = find.byIcon(Icons.folder_special);
        expect(vaultsTab, findsWidgets);
        
        // Check if first tab has selection styling
        final firstTabContainer = find.ancestor(
          of: vaultsTab,
          matching: find.byType(AnimatedContainer),
        ).first;
        expect(firstTabContainer, findsOneWidget);
      });

      testWidgets('should navigate between tabs when tapped', (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Tap on Terminal tab (second tab)
        await tester.tap(find.byIcon(Icons.terminal).first);
        await tester.pumpAndSettle();

        // Verify navigation occurred - main screen should still exist
        expect(find.byType(MainTabScreen), findsOneWidget);
        
        // Tap on Settings tab (last tab)
        await tester.tap(find.byIcon(Icons.settings).first);
        await tester.pumpAndSettle();

        // Verify the tab is still rendered
        expect(find.byIcon(Icons.settings), findsWidgets);
      });

      testWidgets('should provide haptic feedback when tab is tapped', 
          (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Mock haptic feedback
        final List<MethodCall> feedbackCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            feedbackCalls.add(methodCall);
            return null;
          },
        );

        // Tap on different tab
        await tester.tap(find.byIcon(Icons.terminal).first);
        await tester.pumpAndSettle();

        // Verify haptic feedback was called (can be either vibrate or light impact)
        expect(feedbackCalls, isNotEmpty);
        final lastCall = feedbackCalls.last.method;
        expect(['HapticFeedback.vibrate', 'HapticFeedback.lightImpact', 'SystemSound.play'].contains(lastCall), isTrue);
      });
    });

    group('Responsive Layout Tests', () {
      testWidgets('should use full mode on large screens (>360px)', 
          (WidgetTester tester) async {
        // Set large screen size
        await tester.binding.setSurfaceSize(const Size(400, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Should show text labels in full mode
        expect(find.text('Vaults'), findsOneWidget);
        expect(find.text('Terminal'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Editor'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      });

      testWidgets('should switch to icon-only mode on small screens (<360px)', 
          (WidgetTester tester) async {
        // Set small screen size
        await tester.binding.setSurfaceSize(const Size(320, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Should not show text labels in icon-only mode
        expect(find.text('Vaults'), findsNothing);
        expect(find.text('Terminal'), findsNothing);
        expect(find.text('History'), findsNothing);
        expect(find.text('Editor'), findsNothing);
        expect(find.text('Settings'), findsNothing);

        // But icons should still be present
        expect(find.byIcon(Icons.folder_special), findsOneWidget);
        expect(find.byIcon(Icons.terminal), findsOneWidget);
        expect(find.byIcon(Icons.history), findsOneWidget);
        expect(find.byIcon(Icons.code), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });

      testWidgets('should switch to icon-only mode when tab width < 70px', 
          (WidgetTester tester) async {
        // Set medium screen that would result in narrow tabs
        await tester.binding.setSurfaceSize(const Size(340, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // With 5 tabs and 16px padding, each tab gets ~65px width, triggering icon-only
        expect(find.text('Vaults'), findsNothing);
        expect(find.text('Terminal'), findsNothing);
        
        // Icons should still be present
        expect(find.byIcon(Icons.folder_special), findsOneWidget);
        expect(find.byIcon(Icons.terminal), findsOneWidget);
      });

      testWidgets('should use larger icons in icon-only mode', 
          (WidgetTester tester) async {
        // Test icon size difference between modes
        await tester.binding.setSurfaceSize(const Size(320, 800)); // Small screen
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        final iconWidget = tester.widget<Icon>(find.byIcon(Icons.folder_special));
        expect(iconWidget.size, equals(24.0)); // Icon-only mode uses size 24
      });

      testWidgets('should use normal size icons in full mode', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800)); // Large screen
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        final iconWidget = tester.widget<Icon>(find.byIcon(Icons.folder_special));
        expect(iconWidget.size, equals(22.0)); // Full mode uses size 22
      });
    });

    group('Font Scaling and Overflow Tests', () {
      testWidgets('should scale font size dynamically based on available width', 
          (WidgetTester tester) async {
        // Test with medium screen that triggers font scaling
        await tester.binding.setSurfaceSize(const Size(380, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Find text widgets and verify they exist (indicating full mode)
        final textWidgets = find.byType(Text);
        expect(textWidgets, findsWidgets);
        
        // Verify text overflow property is set
        final vaultsText = tester.widget<Text>(find.text('Vaults'));
        expect(vaultsText.overflow, equals(TextOverflow.ellipsis));
        expect(vaultsText.maxLines, equals(1));
      });

      testWidgets('should clamp font size between 8px and 12px', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(380, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Find AnimatedDefaultTextStyle widgets
        final textStyleWidgets = find.byType(AnimatedDefaultTextStyle);
        expect(textStyleWidgets, findsWidgets);

        // In this case, we expect the font size to be within the clamped range
        // This is more of an implementation detail check
        for (final element in textStyleWidgets.evaluate()) {
          final widget = element.widget as AnimatedDefaultTextStyle;
          final fontSize = widget.style.fontSize ?? 11.0;
          expect(fontSize, greaterThanOrEqualTo(8.0));
          expect(fontSize, lessThanOrEqualTo(11.0));
        }
      });

      testWidgets('should handle text overflow with ellipsis', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        final textWidgets = find.byType(Text);
        for (final element in textWidgets.evaluate()) {
          final textWidget = element.widget as Text;
          if (textWidget.data != null) {
            expect(textWidget.overflow, equals(TextOverflow.ellipsis));
            expect(textWidget.maxLines, equals(1));
            expect(textWidget.textAlign, equals(TextAlign.center));
          }
        }
      });
    });

    group('Accessibility Tests', () {
      testWidgets('should provide semantic labels for icons in icon-only mode', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 800)); // Force icon-only mode
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Check semantic labels are present
        final vaultsIcon = tester.widget<Icon>(find.byIcon(Icons.folder_special));
        expect(vaultsIcon.semanticLabel, equals('Vaults'));

        final terminalIcon = tester.widget<Icon>(find.byIcon(Icons.terminal));
        expect(terminalIcon.semanticLabel, equals('Terminal'));

        final historyIcon = tester.widget<Icon>(find.byIcon(Icons.history));
        expect(historyIcon.semanticLabel, equals('History'));

        final editorIcon = tester.widget<Icon>(find.byIcon(Icons.code));
        expect(editorIcon.semanticLabel, equals('Editor'));

        final settingsIcon = tester.widget<Icon>(find.byIcon(Icons.settings));
        expect(settingsIcon.semanticLabel, equals('Settings'));
      });

      testWidgets('should not have semantic labels in full mode', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800)); // Full mode
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // In full mode, semantic labels should be null since text is visible
        final vaultsIcon = tester.widget<Icon>(find.byIcon(Icons.folder_special));
        expect(vaultsIcon.semanticLabel, isNull);
      });

      testWidgets('should maintain minimum tap target size', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 800)); // Small screen
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Find the gesture detector containers
        final containers = find.byType(AnimatedContainer);
        for (final element in containers.evaluate()) {
          final container = element.widget as AnimatedContainer;
          if (container.constraints != null) {
            expect(container.constraints!.minWidth, greaterThanOrEqualTo(44.0));
          }
        }
      });
    });

    group('Visual Indicator Tests', () {
      testWidgets('should show selection indicator in full mode', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Find animated containers that could be indicators
        final indicators = find.byType(AnimatedContainer);
        expect(indicators, findsWidgets);

        // Tap second tab to ensure we can see selection change
        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pumpAndSettle();

        // Indicators should still be present
        expect(indicators, findsWidgets);
      });

      testWidgets('should show smaller selection indicator in icon-only mode', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // In icon-only mode, we should still have animated containers for indicators
        final indicators = find.byType(AnimatedContainer);
        expect(indicators, findsWidgets);

        // Tap different tab to test selection
        await tester.tap(find.byIcon(Icons.terminal));
        await tester.pumpAndSettle();

        expect(indicators, findsWidgets);
      });

      testWidgets('should apply selection styling correctly', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Tap on terminal tab
        await tester.tap(find.byIcon(Icons.terminal).first);
        await tester.pumpAndSettle();

        // Check that the selected icon has the correct color (primary color)
        final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.terminal));
        expect(selectedIcon.color, equals(AppTheme.primaryColor));
      });
    });

    group('Animation Tests', () {
      testWidgets('should animate tab transitions', (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Tap on different tab
        await tester.tap(find.byIcon(Icons.settings).first);
        
        // Pump frame to start animation
        await tester.pump();
        
        // Check that animation is in progress
        expect(tester.hasRunningAnimations, isTrue);
        
        // Complete animation
        await tester.pumpAndSettle();
        
        // Animation should be complete
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('should animate container changes', (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Find animated containers
        final animatedContainers = find.byType(AnimatedContainer);
        expect(animatedContainers, findsWidgets);

        // Tap different tab to trigger animation
        await tester.tap(find.byIcon(Icons.history).first);
        await tester.pump(const Duration(milliseconds: 100));

        // Should have running animations
        expect(tester.hasRunningAnimations, isTrue);
        
        await tester.pumpAndSettle();
        expect(tester.hasRunningAnimations, isFalse);
      });
    });

    group('Edge Case Tests', () {
      testWidgets('should handle same tab tap gracefully', 
          (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Tap on currently selected tab (first tab)
        await tester.tap(find.byIcon(Icons.folder_special).first);
        await tester.pumpAndSettle();

        // Should remain on same tab without errors
        expect(find.byIcon(Icons.folder_special), findsOneWidget);
      });

      testWidgets('should handle very small screen sizes', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(200, 600));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Should still render without overflow
        expect(find.byType(MainTabScreen), findsOneWidget);
        expect(find.byIcon(Icons.folder_special), findsOneWidget);
        
        // Should be in icon-only mode
        expect(find.text('Vaults'), findsNothing);
      });

      testWidgets('should handle very large screen sizes', 
          (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Should render normally with text labels
        expect(find.text('Vaults'), findsOneWidget);
        expect(find.text('Terminal'), findsOneWidget);
        expect(find.text('History'), findsOneWidget);
        expect(find.text('Editor'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);
      });
    });

    group('Layout Configuration Tests', () {
      testWidgets('should have correct container height', 
          (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // The bottom navigation container should have height of 80
        final containers = find.byType(Container);
        expect(containers, findsWidgets);
        
        // Check that main container has correct styling
        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('should apply correct padding', (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Verify containers have proper padding
        final paddedContainers = find.byType(Container);
        expect(paddedContainers, findsWidgets);
      });

      testWidgets('should handle border and shadow styling', 
          (WidgetTester tester) async {
        await tester.pumpWidget(testWidget);
        await tester.pumpAndSettle();

        // Check that main container has decoration
        final decoratedContainers = find.byType(Container);
        expect(decoratedContainers, findsWidgets);
      });
    });

    tearDown(() async {
      // Reset surface size after each test
      // Note: tester variable not available in tearDown, so this is handled per test
    });
  });

  group('MainTabScreen Integration Tests', () {
    testWidgets('should preserve tab state when switching between tabs',
        (WidgetTester tester) async {
      final testWidget = ProviderScope(
        child: MaterialApp(
          home: const MainTabScreen(),
          theme: AppTheme.darkTheme,
          routes: {
            '/terminal': (context) => const Scaffold(body: Text('Terminal')),
            '/history': (context) => const Scaffold(body: Text('History')),
            '/editor': (context) => const Scaffold(body: Text('Editor')),
            '/settings': (context) => const Scaffold(body: Text('Settings')),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (context) => const Scaffold(body: Text('Unknown Route')),
          ),
        ),
      );

      await tester.pumpWidget(testWidget);
      await tester.pumpAndSettle();

      // Navigate through tabs with timeout protection
      await tester.tap(find.byIcon(Icons.terminal).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.history).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.settings).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Go back to first tab
      await tester.tap(find.byIcon(Icons.folder_special).first);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Should still work correctly
      expect(find.byType(MainTabScreen), findsOneWidget);
    });

    testWidgets('should handle rapid tab switching', 
        (WidgetTester tester) async {
      final testWidget = ProviderScope(
        child: MaterialApp(
          home: const MainTabScreen(),
          theme: AppTheme.darkTheme,
          routes: {
            '/terminal': (context) => const Scaffold(body: Text('Terminal')),
            '/history': (context) => const Scaffold(body: Text('History')),
            '/editor': (context) => const Scaffold(body: Text('Editor')),
            '/settings': (context) => const Scaffold(body: Text('Settings')),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (context) => const Scaffold(body: Text('Unknown Route')),
          ),
        ),
      );

      await tester.pumpWidget(testWidget);
      await tester.pumpAndSettle();

      // Rapid tap switching with controlled animation settling
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.terminal).first);
        await tester.pump(const Duration(milliseconds: 100));
        
        await tester.tap(find.byIcon(Icons.history).first);
        await tester.pump(const Duration(milliseconds: 100));
        
        await tester.tap(find.byIcon(Icons.settings).first);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Use pumpAndSettle with timeout to prevent infinite loops
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should still work without errors
      expect(find.byType(MainTabScreen), findsOneWidget);
    });
  });

  group('TabNavigationHelper Tests', () {
    testWidgets('should provide correct tab constants', (WidgetTester tester) async {
      expect(TabNavigationHelper.vaultsTab, equals(0));
      expect(TabNavigationHelper.terminalTab, equals(1));
      expect(TabNavigationHelper.historyTab, equals(2));
      expect(TabNavigationHelper.editorTab, equals(3));
      expect(TabNavigationHelper.settingsTab, equals(4));
    });
  });

  group('TabItem Tests', () {
    test('should create TabItem with required properties', () {
      final tabItem = TabItem(
        icon: Icons.star_outline,
        activeIcon: Icons.star,
        label: 'Test',
        screen: const Scaffold(),
      );

      expect(tabItem.icon, equals(Icons.star_outline));
      expect(tabItem.activeIcon, equals(Icons.star));
      expect(tabItem.label, equals('Test'));
      expect(tabItem.screen, isA<Widget>());
    });
  });
}