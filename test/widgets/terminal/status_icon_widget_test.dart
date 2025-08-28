import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/widgets/terminal/status_icon_widget.dart';
import 'package:devpocket_warp_app/widgets/terminal/terminal_block.dart';
import 'package:devpocket_warp_app/services/command_type_detector.dart';
import 'package:devpocket_warp_app/themes/app_theme.dart';

void main() {
  group('StatusIconWidget', () {
    testWidgets('should display correct icon for one-shot pending command', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.pending,
              commandType: CommandType.oneShot,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      expect(iconWidget, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.icon, Icons.schedule);
      expect(icon.color, AppTheme.terminalYellow);
    });

    testWidgets('should display correct icon for one-shot running command', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.running,
              commandType: CommandType.oneShot,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      expect(iconWidget, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.icon, Icons.flash_on);
      expect(icon.color, AppTheme.terminalBlue);
    });

    testWidgets('should display correct icon for continuous running command', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.running,
              commandType: CommandType.continuous,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      expect(iconWidget, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.icon, Icons.timeline);
      expect(icon.color, AppTheme.terminalYellow);
    });

    testWidgets('should display correct icon for interactive running command', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.running,
              commandType: CommandType.interactive,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      expect(iconWidget, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.icon, Icons.keyboard);
      expect(icon.color, AppTheme.terminalCyan);
    });

    testWidgets('should display correct icon for completed command', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.completed,
              commandType: CommandType.oneShot,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      expect(iconWidget, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.icon, Icons.check_circle);
      expect(icon.color, AppTheme.terminalGreen);
    });

    testWidgets('should display correct icon for failed command', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.failed,
              commandType: CommandType.oneShot,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      expect(iconWidget, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.icon, Icons.error);
      expect(icon.color, AppTheme.terminalRed);
    });

    testWidgets('should display correct icon for cancelled command', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.cancelled,
              commandType: CommandType.oneShot,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      expect(iconWidget, findsOneWidget);
      
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.icon, Icons.stop_circle);
      expect(icon.color, AppTheme.darkTextSecondary);
    });

    testWidgets('should show activity indicator for continuous running commands', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.running,
              commandType: CommandType.continuous,
              showActivityIndicator: true,
            ),
          ),
        ),
      );

      // Should have AnimatedBuilder for rotation animation
      expect(find.byType(AnimatedBuilder), findsOneWidget);
      
      await tester.pump(const Duration(milliseconds: 100));
      // Animation should be running
    });

    testWidgets('should show pulse animation for running one-shot commands with activity indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.running,
              commandType: CommandType.oneShot,
              showActivityIndicator: true,
            ),
          ),
        ),
      );

      // Should have AnimatedBuilder for pulse animation
      expect(find.byType(AnimatedBuilder), findsOneWidget);
    });

    testWidgets('should not show animation for non-running status', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.completed,
              commandType: CommandType.continuous,
              showActivityIndicator: true,
            ),
          ),
        ),
      );

      // Should not have animation for completed status
      expect(find.byType(AnimatedBuilder), findsNothing);
    });

    testWidgets('should display tooltip when provided', (tester) async {
      const tooltipText = 'Test tooltip';
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.running,
              commandType: CommandType.oneShot,
              tooltip: tooltipText,
            ),
          ),
        ),
      );

      expect(find.byType(Tooltip), findsOneWidget);
      
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, tooltipText);
    });

    testWidgets('should have proper semantic label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.running,
              commandType: CommandType.oneShot,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.semanticLabel, 'One-shot command is running');
    });

    testWidgets('should handle size parameter correctly', (tester) async {
      const customSize = 24.0;
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconWidget(
              status: TerminalBlockStatus.running,
              commandType: CommandType.oneShot,
              size: customSize,
            ),
          ),
        ),
      );

      final iconWidget = find.byType(Icon);
      final icon = tester.widget<Icon>(iconWidget);
      expect(icon.size, customSize);
    });
  });

  group('StatusIconBadge', () {
    testWidgets('should display status icon and text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconBadge(
              status: TerminalBlockStatus.running,
              commandType: CommandType.oneShot,
            ),
          ),
        ),
      );

      expect(find.byType(StatusIconWidget), findsOneWidget);
      expect(find.text('Executing'), findsOneWidget);
    });

    testWidgets('should display custom text when provided', (tester) async {
      const customText = 'Custom Status';
      
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconBadge(
              status: TerminalBlockStatus.running,
              commandType: CommandType.oneShot,
              customText: customText,
            ),
          ),
        ),
      );

      expect(find.text(customText), findsOneWidget);
    });

    testWidgets('should have proper styling for different command types', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatusIconBadge(
              status: TerminalBlockStatus.running,
              commandType: CommandType.continuous,
            ),
          ),
        ),
      );

      final container = find.byType(Container).first;
      final containerWidget = tester.widget<Container>(container);
      final decoration = containerWidget.decoration as BoxDecoration;
      
      expect(decoration.color, AppTheme.terminalYellow.withValues(alpha: 0.1));
    });

    testWidgets('should display correct text for different statuses', (tester) async {
      final testCases = [
        (TerminalBlockStatus.pending, CommandType.oneShot, 'Pending'),
        (TerminalBlockStatus.running, CommandType.oneShot, 'Executing'),
        (TerminalBlockStatus.running, CommandType.continuous, 'Monitoring'),
        (TerminalBlockStatus.running, CommandType.interactive, 'Interactive'),
        (TerminalBlockStatus.completed, CommandType.oneShot, 'Success'),
        (TerminalBlockStatus.failed, CommandType.oneShot, 'Failed'),
        (TerminalBlockStatus.cancelled, CommandType.oneShot, 'Cancelled'),
      ];

      for (final (status, commandType, expectedText) in testCases) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: StatusIconBadge(
                status: status,
                commandType: commandType,
              ),
            ),
          ),
        );

        expect(find.text(expectedText), findsOneWidget, 
            reason: 'Expected "$expectedText" for $status + $commandType');
        
        // Clean up for next test
        await tester.pumpWidget(Container());
      }
    });
  });
}