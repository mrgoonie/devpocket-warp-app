import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/screens/main/main_tab_screen.dart';
import 'package:devpocket_warp_app/themes/app_theme.dart';

import '../helpers/test_helpers.dart';

/// Integration tests for MainTabScreen navigation and state management
void main() {
  group('MainTabScreen Integration Tests', () {
    
    group('Tab Navigation and State Preservation', () {
      
      testWidgets('should preserve tab state during navigation cycles',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Navigate through all tabs in sequence
        final navigationSequence = [
          Icons.terminal,    // Tab 1
          Icons.history,     // Tab 2
          Icons.code,        // Tab 3 (Editor)
          Icons.settings,    // Tab 4
          Icons.folder_special, // Tab 0 (back to start)
        ];

        for (final iconData in navigationSequence) {
          await tester.tap(find.byIcon(iconData).first);
          await TestHelpers.pumpAndSettleWithAnimations(tester);
          
          // Verify navigation succeeded
          expect(find.byIcon(iconData), findsOneWidget);
          expect(tester.takeException(), isNull);
        }

        // Navigate in reverse order
        final reverseSequence = navigationSequence.reversed.toList();
        
        for (final iconData in reverseSequence) {
          await tester.tap(find.byIcon(iconData).first);
          await TestHelpers.pumpAndSettleWithAnimations(tester);
          
          expect(find.byIcon(iconData), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('should handle rapid tab switching without errors',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Perform rapid tab switching
        const cycles = 5;
        for (int cycle = 0; cycle < cycles; cycle++) {
          for (final iconData in TestHelpers.tabIcons) {
            await tester.tap(find.byIcon(iconData).first);
            await tester.pump(const Duration(milliseconds: 50)); // Quick switching
          }
        }

        // Let animations complete
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Should still be functional
        expect(find.byType(MainTabScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        // Test final navigation
        await tester.tap(find.byIcon(Icons.settings).first);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.settings));
        expect(selectedIcon.color, equals(AppTheme.primaryColor));
      });

      testWidgets('should maintain PageView state during tab switches',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Verify PageView is present
        final pageView = find.byType(PageView);
        expect(pageView, findsOneWidget);

        // Navigate to different tabs and verify PageView updates
        await tester.tap(find.byIcon(Icons.terminal).first);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        // PageView should still be present
        expect(pageView, findsOneWidget);

        await tester.tap(find.byIcon(Icons.settings).first);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        expect(pageView, findsOneWidget);
      });
    });

    group('Responsive Behavior Integration', () {
      
      testWidgets('should adapt to screen size changes without losing state',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);

        // Start in full mode
        await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        // Navigate to a specific tab
        await tester.tap(find.byIcon(Icons.history).first);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        // Verify selection in full mode
        TestHelpers.verifyFullMode(tester, TestHelpers.tabLabels);
        final selectedIconFull = tester.widget<Icon>(find.byIcon(Icons.history));
        expect(selectedIconFull.color, equals(AppTheme.primaryColor));

        // Change to icon-only mode
        await TestHelpers.changeScreenSize(tester, TestHelpers.iconOnlyScreen);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        // Should maintain selection but switch to icon-only
        TestHelpers.verifyIconOnlyMode(tester, TestHelpers.tabLabels);
        final selectedIconOnly = tester.widget<Icon>(find.byIcon(Icons.history));
        expect(selectedIconOnly.color, equals(AppTheme.primaryColor));
        expect(selectedIconOnly.size, equals(24.0));

        // Switch back to full mode
        await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        // Should maintain selection and return to full mode
        TestHelpers.verifyFullMode(tester, TestHelpers.tabLabels);
        final selectedIconBack = tester.widget<Icon>(find.byIcon(Icons.history));
        expect(selectedIconBack.color, equals(AppTheme.primaryColor));
        expect(selectedIconBack.size, equals(22.0));
      });

      testWidgets('should handle orientation changes gracefully',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);

        // Portrait mode
        await TestHelpers.changeScreenSize(tester, const Size(375, 812));
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        await tester.tap(find.byIcon(Icons.code).first);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Landscape mode (swap dimensions)
        await TestHelpers.changeScreenSize(tester, const Size(812, 375));
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        // Should maintain selection and adapt layout
        expect(find.byType(MainTabScreen), findsOneWidget);
        final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.code));
        expect(selectedIcon.color, equals(AppTheme.primaryColor));

        // Back to portrait
        await TestHelpers.changeScreenSize(tester, const Size(375, 812));
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        expect(find.byType(MainTabScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Accessibility Integration', () {
      
      testWidgets('should provide consistent accessibility across mode changes',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);

        // Start in full mode - no semantic labels needed
        await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        TestHelpers.verifyNoSemanticLabels(tester);
        TestHelpers.verifyMinimumTapTargets(tester, 44.0);

        // Switch to icon-only mode - semantic labels should appear
        await TestHelpers.changeScreenSize(tester, TestHelpers.iconOnlyScreen);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        TestHelpers.verifySemanticLabels(tester);
        TestHelpers.verifyMinimumTapTargets(tester, 44.0);

        // Test navigation in icon-only mode with screen reader context
        await tester.tap(find.byIcon(Icons.terminal).first);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        final terminalIcon = tester.widget<Icon>(find.byIcon(Icons.terminal));
        expect(terminalIcon.semanticLabel, equals('Terminal'));
        expect(terminalIcon.color, equals(AppTheme.primaryColor));
      });

      testWidgets('should maintain tap targets during rapid size changes',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);

        final testSizes = [
          TestHelpers.iconOnlyScreen,
          TestHelpers.fullModeScreen,
          TestHelpers.narrowTabScreen,
          TestHelpers.largePhone,
        ];

        for (final size in testSizes) {
          await TestHelpers.changeScreenSize(tester, size);
          await tester.pump(const Duration(milliseconds: 100)); // Quick change
          
          TestHelpers.verifyMinimumTapTargets(tester, 44.0);
          
          // Test that tabs are still tappable
          await tester.tap(find.byIcon(Icons.terminal).first);
          await tester.pump(const Duration(milliseconds: 50));
          
          expect(tester.takeException(), isNull);
        }

        await TestHelpers.pumpAndSettleWithAnimations(tester);
      });
    });

    group('Performance Integration', () {
      
      testWidgets('should not cause memory leaks during extended use',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Simulate extended usage patterns
        const iterations = 20;
        
        for (int i = 0; i < iterations; i++) {
          // Navigation cycle
          for (final iconData in TestHelpers.tabIcons) {
            await tester.tap(find.byIcon(iconData).first);
            await tester.pump(const Duration(milliseconds: 50));
          }
          
          // Size change cycle
          await TestHelpers.changeScreenSize(tester, TestHelpers.iconOnlyScreen);
          await tester.pump(const Duration(milliseconds: 50));
          
          await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
          await tester.pump(const Duration(milliseconds: 50));
        }

        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Should still be functional
        expect(find.byType(MainTabScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        // Final functionality test
        await tester.tap(find.byIcon(Icons.settings).first);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        final finalIcon = tester.widget<Icon>(find.byIcon(Icons.settings));
        expect(finalIcon.color, equals(AppTheme.primaryColor));
      });

      testWidgets('should handle stress test scenarios',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);

        // Stress test: simultaneous rapid operations
        for (int i = 0; i < 10; i++) {
          // Rapid navigation
          await tester.tap(find.byIcon(TestHelpers.tabIcons[i % TestHelpers.tabIcons.length]).first);
          await tester.pump(const Duration(milliseconds: 10));
          
          // Rapid size change
          final size = i % 2 == 0 ? TestHelpers.iconOnlyScreen : TestHelpers.fullModeScreen;
          await TestHelpers.changeScreenSize(tester, size);
          await tester.pump(const Duration(milliseconds: 10));
        }

        // Allow everything to settle
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Verify still functional
        expect(find.byType(MainTabScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Haptic Feedback Integration', () {
      
      testWidgets('should provide haptic feedback during navigation',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Mock haptic feedback calls
        final List<MethodCall> feedbackCalls = <MethodCall>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            feedbackCalls.add(methodCall);
            return null;
          },
        );

        // Test haptic feedback for each tab
        int expectedCallCount = 0;
        
        for (final iconData in TestHelpers.tabIcons.skip(1)) { // Skip first (already selected)
          await tester.tap(find.byIcon(iconData));
          await TestHelpers.pumpAndSettleWithAnimations(tester);
          
          expectedCallCount++;
          expect(feedbackCalls.length, equals(expectedCallCount));
          expect(feedbackCalls.last.method, equals('HapticFeedback.vibrate'));
        }

        // Test that tapping same tab doesn't trigger haptic feedback
        final initialCallCount = feedbackCalls.length;
        await tester.tap(find.byIcon(Icons.settings).first); // Same tab
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        expect(feedbackCalls.length, equals(initialCallCount),
            reason: 'Tapping same tab should not trigger haptic feedback');
      });
    });

    group('Animation Integration', () {
      
      testWidgets('should coordinate animations across mode changes',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);

        // Start in full mode
        await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Trigger tab change animation
        await tester.tap(find.byIcon(Icons.terminal).first);
        await tester.pump(); // Start animation
        
        expect(tester.hasRunningAnimations, isTrue);
        
        // Change to icon-only mode during animation
        await TestHelpers.changeScreenSize(tester, TestHelpers.iconOnlyScreen);
        await tester.pump();
        
        // Should handle overlapping animations gracefully
        expect(tester.takeException(), isNull);
        
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        // Final state should be correct
        TestHelpers.verifyIconOnlyMode(tester, TestHelpers.tabLabels);
        final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.terminal));
        expect(selectedIcon.color, equals(AppTheme.primaryColor));
        expect(selectedIcon.size, equals(24.0));
      });
    });

    tearDown(() async {
      // Reset surface size after each test
      // Note: tester variable not available in tearDown, so this is handled per test
    });
  });
}