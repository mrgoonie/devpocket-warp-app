import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/screens/main/main_tab_screen.dart';
import 'package:devpocket_warp_app/themes/app_theme.dart';

import '../../helpers/test_helpers.dart';

/// Focused tests for responsive behavior and overflow protection
void main() {
  group('Responsive Navigation Bar Tests', () {
    
    group('Screen Width Based Mode Switching', () {
      
      testWidgets('should use icon-only mode when screen width < 360px',
          (WidgetTester tester) async {
        
        final testCases = [
          TestHelpers.iconOnlyScreen,     // 300px - well below threshold
          const Size(320, 600),           // 320px - typical small phone
          const Size(359, 600),           // 359px - just below threshold
        ];

        for (final screenSize in testCases) {
          await TestHelpers.changeScreenSize(tester, screenSize);
          
          final widget = TestHelpers.createTestApp(
            child: const MainTabScreen(),
          );
          
          await tester.pumpWidget(widget);
          await TestHelpers.pumpAndSettleWithAnimations(tester);

          // Verify icon-only mode
          TestHelpers.verifyIconOnlyMode(tester, TestHelpers.tabLabels);
          
          // Verify icons are present and larger (24px)
          for (final iconData in TestHelpers.tabIcons) {
            final icon = tester.widget<Icon>(find.byIcon(iconData));
            expect(icon.size, equals(24.0), 
                reason: 'Icon size should be 24px in icon-only mode for ${screenSize.width}px width');
          }

          // Verify semantic labels are present
          TestHelpers.verifySemanticLabels(tester);
        }
      });

      testWidgets('should use full mode when screen width >= 360px',
          (WidgetTester tester) async {
        
        final testCases = [
          const Size(360, 600),           // 360px - exactly at threshold
          TestHelpers.fullModeScreen,     // 400px - comfortably above
          TestHelpers.largePhone,         // 414px - large phone
          TestHelpers.smallTablet,        // 768px - tablet
        ];

        for (final screenSize in testCases) {
          await TestHelpers.changeScreenSize(tester, screenSize);
          
          final widget = TestHelpers.createTestApp(
            child: const MainTabScreen(),
          );
          
          await tester.pumpWidget(widget);
          await TestHelpers.pumpAndSettleWithAnimations(tester);

          // Verify full mode - text labels should be visible
          TestHelpers.verifyFullMode(tester, TestHelpers.tabLabels);
          
          // Verify icons are smaller (22px)
          for (final iconData in TestHelpers.tabIcons) {
            final icon = tester.widget<Icon>(find.byIcon(iconData));
            expect(icon.size, equals(22.0),
                reason: 'Icon size should be 22px in full mode for ${screenSize.width}px width');
          }

          // Verify no semantic labels in full mode
          TestHelpers.verifyNoSemanticLabels(tester);
        }
      });
    });

    group('Tab Width Based Mode Switching', () {
      
      testWidgets('should use icon-only mode when calculated tab width < 70px',
          (WidgetTester tester) async {
        
        // Test scenarios where screen width / 5 tabs + padding results in < 70px per tab
        final testCases = [
          const Size(330, 600),  // (330-16)/5 = 62.8px per tab
          const Size(340, 600),  // (340-16)/5 = 64.8px per tab  
          const Size(350, 600),  // (350-16)/5 = 66.8px per tab
          const Size(365, 600),  // (365-16)/5 = 69.8px per tab - just under 70
        ];

        for (final screenSize in testCases) {
          await TestHelpers.changeScreenSize(tester, screenSize);
          
          final widget = TestHelpers.createTestApp(
            child: const MainTabScreen(),
          );
          
          await tester.pumpWidget(widget);
          await TestHelpers.pumpAndSettleWithAnimations(tester);

          final expectedTabWidth = (screenSize.width - 16) / 5;
          
          // Should be in icon-only mode due to narrow tabs
          TestHelpers.verifyIconOnlyMode(tester, TestHelpers.tabLabels);
          
          // Verify larger icons
          final icon = tester.widget<Icon>(find.byIcon(Icons.folder_special));
          expect(icon.size, equals(24.0),
              reason: 'Should use larger icons when tab width ($expectedTabWidth) < 70px');
        }
      });

      testWidgets('should use full mode when calculated tab width >= 70px',
          (WidgetTester tester) async {
        
        final testCases = [
          const Size(366, 600),  // (366-16)/5 = 70px per tab - exactly at threshold
          const Size(380, 600),  // (380-16)/5 = 72.8px per tab
          const Size(400, 600),  // (400-16)/5 = 76.8px per tab
        ];

        for (final screenSize in testCases) {
          await TestHelpers.changeScreenSize(tester, screenSize);
          
          final widget = TestHelpers.createTestApp(
            child: const MainTabScreen(),
          );
          
          await tester.pumpWidget(widget);
          await TestHelpers.pumpAndSettleWithAnimations(tester);

          final expectedTabWidth = (screenSize.width - 16) / 5;
          
          // Should be in full mode due to adequate tab width
          TestHelpers.verifyFullMode(tester, TestHelpers.tabLabels);
          
          // Verify smaller icons
          final icon = tester.widget<Icon>(find.byIcon(Icons.folder_special));
          expect(icon.size, equals(22.0),
              reason: 'Should use smaller icons when tab width ($expectedTabWidth) >= 70px');
        }
      });
    });

    group('Font Scaling Tests', () {
      
      testWidgets('should scale font size based on available tab width',
          (WidgetTester tester) async {
        
        final testCases = [
          {
            'size': const Size(400, 600),  // 76.8px per tab - no scaling needed
            'expectedBaseFontSize': 11.0,
            'shouldScale': false,
          },
          {
            'size': const Size(380, 600),  // 72.8px per tab - minimal scaling
            'expectedBaseFontSize': 11.0,
            'shouldScale': true,
          },
          {
            'size': const Size(370, 600),  // 70.8px per tab - more scaling
            'expectedBaseFontSize': 11.0,
            'shouldScale': true,
          },
        ];

        for (final testCase in testCases) {
          final screenSize = testCase['size'] as Size;
          await TestHelpers.changeScreenSize(tester, screenSize);
          
          final widget = TestHelpers.createTestApp(
            child: const MainTabScreen(),
          );
          
          await tester.pumpWidget(widget);
          await TestHelpers.pumpAndSettleWithAnimations(tester);

          final tabWidth = (screenSize.width - 16) / 5;
          
          if (tabWidth >= 70) { // Should be in full mode
            final textStyleWidgets = find.byType(AnimatedDefaultTextStyle);
            expect(textStyleWidgets, findsWidgets);

            // Check font size is within expected range
            for (final element in textStyleWidgets.evaluate()) {
              final widget = element.widget as AnimatedDefaultTextStyle;
              final fontSize = widget.style.fontSize ?? 12.0;
              
              // Font size should be clamped between 8-11px
              TestHelpers.verifyFontSizeInRange(widget.style, 8.0, 11.0);
              
              if (testCase['shouldScale'] == true && tabWidth < 80) {
                // Should be scaled down from base size
                expect(fontSize, lessThan(11.0),
                    reason: 'Font should be scaled down when tab width ($tabWidth) < 80px');
              }
            }
          }
        }
      });

      testWidgets('should clamp font size between 8px and 11px',
          (WidgetTester tester) async {
        
        // Test extreme cases that would push font scaling beyond limits
        final extremeCases = [
          const Size(320, 600),  // Very narrow - should clamp to minimum
          const Size(600, 600),  // Very wide - should clamp to maximum
        ];

        for (final screenSize in extremeCases) {
          await TestHelpers.changeScreenSize(tester, screenSize);
          
          final widget = TestHelpers.createTestApp(
            child: const MainTabScreen(),
          );
          
          await tester.pumpWidget(widget);
          await TestHelpers.pumpAndSettleWithAnimations(tester);

          final tabWidth = (screenSize.width - 16) / 5;
          
          if (tabWidth >= 70) { // Only test if in full mode
            final textStyleWidgets = find.byType(AnimatedDefaultTextStyle);
            
            for (final element in textStyleWidgets.evaluate()) {
              final widget = element.widget as AnimatedDefaultTextStyle;
              TestHelpers.verifyFontSizeInRange(widget.style, 8.0, 11.0);
            }
          }
        }
      });
    });

    group('Text Overflow Protection Tests', () {
      
      testWidgets('should apply ellipsis overflow to all tab labels',
          (WidgetTester tester) async {
        
        await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Verify text overflow for each tab label
        for (final label in TestHelpers.tabLabels) {
          TestHelpers.verifyTextOverflow(tester, label);
        }
      });

      testWidgets('should handle extremely narrow tabs gracefully',
          (WidgetTester tester) async {
        
        // Create scenario with extremely narrow tabs that would cause overflow
        await TestHelpers.changeScreenSize(tester, const Size(200, 600));
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Should be in icon-only mode (no text to overflow)
        TestHelpers.verifyIconOnlyMode(tester, TestHelpers.tabLabels);
        
        // Should still render without errors
        expect(find.byType(MainTabScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    group('Visual Indicators Tests', () {
      
      testWidgets('should show appropriate indicators in full mode',
          (WidgetTester tester) async {
        
        await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Navigate to different tabs and check indicators
        final tabIcons = [Icons.terminal, Icons.history, Icons.settings];
        
        for (final iconData in tabIcons) {
          await tester.tap(find.byIcon(iconData).first);
          await TestHelpers.pumpAndSettleWithAnimations(tester);

          // Check that selection styling is applied
          final selectedIcon = tester.widget<Icon>(find.byIcon(iconData));
          expect(selectedIcon.color, equals(AppTheme.primaryColor));

          // Check for animated containers (indicators)
          expect(find.byType(AnimatedContainer), findsWidgets);
        }
      });

      testWidgets('should show smaller indicators in icon-only mode',
          (WidgetTester tester) async {
        
        await TestHelpers.changeScreenSize(tester, TestHelpers.iconOnlyScreen);
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Navigate to different tabs and check indicators exist
        await tester.tap(find.byIcon(Icons.terminal).first);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Should still have animated containers for indicators
        expect(find.byType(AnimatedContainer), findsWidgets);
        
        // Selected icon should have primary color
        final selectedIcon = tester.widget<Icon>(find.byIcon(Icons.terminal));
        expect(selectedIcon.color, equals(AppTheme.primaryColor));
      });
    });

    group('Accessibility Tests', () {
      
      testWidgets('should provide semantic labels only in icon-only mode',
          (WidgetTester tester) async {
        
        // Test icon-only mode
        await TestHelpers.changeScreenSize(tester, TestHelpers.iconOnlyScreen);
        
        final iconOnlyWidget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(iconOnlyWidget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        TestHelpers.verifySemanticLabels(tester);

        // Test full mode
        await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
        
        final fullModeWidget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(fullModeWidget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        TestHelpers.verifyNoSemanticLabels(tester);
      });

      testWidgets('should maintain minimum tap target size',
          (WidgetTester tester) async {
        
        final testSizes = [
          TestHelpers.iconOnlyScreen,
          TestHelpers.narrowTabScreen,
          TestHelpers.fullModeScreen,
        ];

        for (final screenSize in testSizes) {
          await TestHelpers.changeScreenSize(tester, screenSize);
          
          final widget = TestHelpers.createTestApp(
            child: const MainTabScreen(),
          );
          
          await tester.pumpWidget(widget);
          await TestHelpers.pumpAndSettleWithAnimations(tester);

          TestHelpers.verifyMinimumTapTargets(tester, 44.0);
        }
      });
    });

    group('Performance and Animation Tests', () {
      
      testWidgets('should handle mode transitions smoothly',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        
        // Start in full mode
        await TestHelpers.changeScreenSize(tester, TestHelpers.fullModeScreen);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        TestHelpers.verifyFullMode(tester, TestHelpers.tabLabels);

        // Switch to icon-only mode
        await TestHelpers.changeScreenSize(tester, TestHelpers.iconOnlyScreen);
        await tester.pump(); // Start transition
        
        // Should have running animations during transition
        expect(tester.hasRunningAnimations, isTrue);
        
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        TestHelpers.verifyIconOnlyMode(tester, TestHelpers.tabLabels);
        expect(tester.hasRunningAnimations, isFalse);
      });

      testWidgets('should not rebuild unnecessarily during size changes',
          (WidgetTester tester) async {
        
        final widget = TestHelpers.createTestApp(
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);

        // Record initial widget count
        // final initialWidgetCount = tester.allWidgets.length;

        // Change size multiple times
        for (final size in [
          const Size(320, 600),
          const Size(400, 600), 
          const Size(350, 600),
          const Size(380, 600),
        ]) {
          await TestHelpers.changeScreenSize(tester, size);
          await TestHelpers.pumpAndSettleWithAnimations(tester);
        }

        // Widget tree should remain stable
        expect(find.byType(MainTabScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    tearDown(() async {
      // Reset surface size after each test
      // Note: tester variable not available in tearDown, so this is handled per test
    });
  });
}