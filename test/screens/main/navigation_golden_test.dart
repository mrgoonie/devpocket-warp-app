import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/screens/main/main_tab_screen.dart';
import 'package:devpocket_warp_app/themes/app_theme.dart';

import '../../helpers/test_helpers.dart';

/// Golden tests for visual regression testing of responsive navigation
void main() {
  group('Navigation Bar Golden Tests', () {
    
    testWidgets('should match golden for icon-only mode on small screen', 
        (WidgetTester tester) async {
      
      await tester.binding.setSurfaceSize(TestHelpers.iconOnlyScreen);
      
      final widget = TestHelpers.createTestApp(
        child: const MainTabScreen(),
      );
      
      await tester.pumpWidget(widget);
      await TestHelpers.pumpAndSettleWithAnimations(tester);
      
      // Focus on the bottom navigation area
      final bottomNav = find.byType(Container).last;
      
      await expectLater(
        bottomNav,
        matchesGoldenFile('golden/navigation_icon_only_mode.png'),
      );
    });

    testWidgets('should match golden for full mode on large screen',
        (WidgetTester tester) async {
      
      await tester.binding.setSurfaceSize(TestHelpers.fullModeScreen);
      
      final widget = TestHelpers.createTestApp(
        child: const MainTabScreen(),
      );
      
      await tester.pumpWidget(widget);
      await TestHelpers.pumpAndSettleWithAnimations(tester);
      
      final bottomNav = find.byType(Container).last;
      
      await expectLater(
        bottomNav,
        matchesGoldenFile('golden/navigation_full_mode.png'),
      );
    });

    testWidgets('should match golden for selected tab in icon-only mode',
        (WidgetTester tester) async {
      
      await tester.binding.setSurfaceSize(TestHelpers.iconOnlyScreen);
      
      final widget = TestHelpers.createTestApp(
        child: const MainTabScreen(),
      );
      
      await tester.pumpWidget(widget);
      await TestHelpers.pumpAndSettleWithAnimations(tester);
      
      // Tap terminal tab
      await tester.tap(find.byIcon(Icons.terminal));
      await TestHelpers.pumpAndSettleWithAnimations(tester);
      
      final bottomNav = find.byType(Container).last;
      
      await expectLater(
        bottomNav,
        matchesGoldenFile('golden/navigation_icon_only_selected.png'),
      );
    });

    testWidgets('should match golden for selected tab in full mode',
        (WidgetTester tester) async {
      
      await tester.binding.setSurfaceSize(TestHelpers.fullModeScreen);
      
      final widget = TestHelpers.createTestApp(
        child: const MainTabScreen(),
      );
      
      await tester.pumpWidget(widget);
      await TestHelpers.pumpAndSettleWithAnimations(tester);
      
      // Tap settings tab
      await tester.tap(find.byIcon(Icons.settings));
      await TestHelpers.pumpAndSettleWithAnimations(tester);
      
      final bottomNav = find.byType(Container).last;
      
      await expectLater(
        bottomNav,
        matchesGoldenFile('golden/navigation_full_mode_selected.png'),
      );
    });

    testWidgets('should match golden for narrow tabs threshold case',
        (WidgetTester tester) async {
      
      // Use size that's right at the boundary between modes
      await tester.binding.setSurfaceSize(TestHelpers.narrowTabScreen);
      
      final widget = TestHelpers.createTestApp(
        child: const MainTabScreen(),
      );
      
      await tester.pumpWidget(widget);
      await TestHelpers.pumpAndSettleWithAnimations(tester);
      
      final bottomNav = find.byType(Container).last;
      
      await expectLater(
        bottomNav,
        matchesGoldenFile('golden/navigation_narrow_tabs.png'),
      );
    });

    group('Dark vs Light Theme Comparison', () {
      
      testWidgets('should match golden for light theme icon-only mode',
          (WidgetTester tester) async {
        
        await tester.binding.setSurfaceSize(TestHelpers.iconOnlyScreen);
        
        final widget = TestHelpers.createTestApp(
          theme: AppTheme.lightTheme,
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        final bottomNav = find.byType(Container).last;
        
        await expectLater(
          bottomNav,
          matchesGoldenFile('golden/navigation_light_theme_icon_only.png'),
        );
      });

      testWidgets('should match golden for light theme full mode',
          (WidgetTester tester) async {
        
        await tester.binding.setSurfaceSize(TestHelpers.fullModeScreen);
        
        final widget = TestHelpers.createTestApp(
          theme: AppTheme.lightTheme,
          child: const MainTabScreen(),
        );
        
        await tester.pumpWidget(widget);
        await TestHelpers.pumpAndSettleWithAnimations(tester);
        
        final bottomNav = find.byType(Container).last;
        
        await expectLater(
          bottomNav,
          matchesGoldenFile('golden/navigation_light_theme_full_mode.png'),
        );
      });
    });

    group('Multi-Tab Selection Golden Tests', () {
      
      for (int i = 0; i < TestHelpers.tabIcons.length; i++) {
        testWidgets('should match golden for tab $i selected in full mode',
            (WidgetTester tester) async {
          
          await tester.binding.setSurfaceSize(TestHelpers.fullModeScreen);
          
          final widget = TestHelpers.createTestApp(
            child: const MainTabScreen(),
          );
          
          await tester.pumpWidget(widget);
          await TestHelpers.pumpAndSettleWithAnimations(tester);
          
          // Tap specific tab
          await tester.tap(find.byIcon(TestHelpers.tabIcons[i]));
          await TestHelpers.pumpAndSettleWithAnimations(tester);
          
          final bottomNav = find.byType(Container).last;
          
          await expectLater(
            bottomNav,
            matchesGoldenFile('golden/navigation_tab_${i}_selected.png'),
          );
        });
      }
    });

    tearDown(() async {
      // Reset surface size after each test
      // Note: tester variable not available in tearDown, so this is handled per test
    });
  });
}