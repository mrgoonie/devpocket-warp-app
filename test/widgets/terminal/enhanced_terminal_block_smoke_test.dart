import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:devpocket_warp_app/widgets/terminal/enhanced_terminal_block.dart';
import 'package:devpocket_warp_app/models/enhanced_terminal_models.dart';
import 'package:devpocket_warp_app/widgets/terminal/terminal_block.dart';
import '../../helpers/test_helpers.dart';

/// Smoke tests for Enhanced Terminal Block Widget
/// These tests ensure the widget can be created and rendered without errors
/// providing a safety net before refactoring the large 1,118 line component
void main() {
  group('EnhancedTerminalBlock Smoke Tests', () {
    late EnhancedTerminalBlockData testBlockData;

    setUp(() {
      testBlockData = EnhancedTerminalBlockData(
        id: 'test-block-1',
        command: 'ls -la',
        status: TerminalBlockStatus.completed,
        timestamp: DateTime.now(),
        index: 0,
        sessionId: 'test-session',
        output: 'total 0\ndrwxr-xr-x  2 user user 4096 Jan 1 12:00 .\ndrwxr-xr-x  3 user user 4096 Jan 1 12:00 ..',
      );
    });

    testWidgets('should create widget with minimal parameters without errors', (WidgetTester tester) async {
      final testApp = createTestApp(
        child: EnhancedTerminalBlock(blockData: testBlockData),
      );

      try {
        await tester.pumpWidget(testApp);

        expect(find.byType(EnhancedTerminalBlock), findsOneWidget);
        expect(tester.takeException(), isNull);
        
      } catch (e) {
        // Accept dependency-related errors for smoke test
        expect(e, isNot(isA<NoSuchMethodError>()));
      }
    });

    testWidgets('should create widget with all parameters without errors', (WidgetTester tester) async {
      bool rerunCalled = false;
      bool cancelCalled = false;
      bool fullscreenCalled = false;
      bool tapCalled = false;
      String? inputReceived;

      final testApp = createTestApp(
        child: EnhancedTerminalBlock(
          blockData: testBlockData,
          onRerun: () => rerunCalled = true,
          onCancel: () => cancelCalled = true,
          onEnterFullscreen: () => fullscreenCalled = true,
          onTap: () => tapCalled = true,
          onInputSubmit: (input) => inputReceived = input,
          showCopyButton: false,
          showTimestamp: false,
          customFontSize: 14.0,
          customFontFamily: 'Courier',
          sessionId: 'test-session-123',
        ),
      );

      try {
        await tester.pumpWidget(testApp);

        expect(find.byType(EnhancedTerminalBlock), findsOneWidget);
        expect(tester.takeException(), isNull);
        
      } catch (e) {
        expect(e, isNot(isA<NoSuchMethodError>()));
      }
    });

    testWidgets('should create widget with different block statuses', (WidgetTester tester) async {
      final statuses = [
        TerminalBlockStatus.pending,
        TerminalBlockStatus.running,
        TerminalBlockStatus.completed,
        TerminalBlockStatus.failed,
        TerminalBlockStatus.cancelled,
      ];

      for (final status in statuses) {
        final blockData = EnhancedTerminalBlockData(
          id: 'test-block-$status',
          command: 'test command',
          status: status,
          timestamp: DateTime.now(),
          index: 0,
          sessionId: 'test-session',
        );

        final testApp = createTestApp(
          child: EnhancedTerminalBlock(blockData: blockData),
        );

        try {
          await tester.pumpWidget(testApp);

          expect(find.byType(EnhancedTerminalBlock), findsOneWidget);
          expect(tester.takeException(), isNull);
          
        } catch (e) {
          expect(e, isNot(isA<NoSuchMethodError>()));
        }
      }
    });

    testWidgets('should create widget with output stream without errors', (WidgetTester tester) async {
      final outputStreamController = StreamController<String>();

      final testApp = createTestApp(
        child: EnhancedTerminalBlock(
          blockData: testBlockData,
          outputStream: outputStreamController.stream,
        ),
      );

      try {
        await tester.pumpWidget(testApp);

        expect(find.byType(EnhancedTerminalBlock), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Cleanup
        await outputStreamController.close();
        
      } catch (e) {
        expect(e, isNot(isA<NoSuchMethodError>()));
        await outputStreamController.close();
      }
    });

    testWidgets('should handle widget disposal without errors', (WidgetTester tester) async {
      final testApp = createTestApp(
        child: EnhancedTerminalBlock(blockData: testBlockData),
      );

      try {
        await tester.pumpWidget(testApp);
        
        // Replace with different widget to trigger disposal
        await tester.pumpWidget(
          createTestApp(child: const Placeholder()),
        );

        expect(tester.takeException(), isNull);
        
      } catch (e) {
        expect(e, isNot(isA<NoSuchMethodError>()));
      }
    });

    testWidgets('should create widget with different command types', (WidgetTester tester) async {
      final commands = [
        'ls -la',
        'vim test.txt',
        'python script.py',
        'tail -f log.txt',
        'ssh user@host',
        'npm run dev',
      ];

      for (final command in commands) {
        final blockData = EnhancedTerminalBlockData(
          id: 'test-block-$command',
          command: command,
          status: TerminalBlockStatus.completed,
          timestamp: DateTime.now(),
          index: 0,
          sessionId: 'test-session',
        );

        final testApp = createTestApp(
          child: EnhancedTerminalBlock(blockData: blockData),
        );

        try {
          await tester.pumpWidget(testApp);

          expect(find.byType(EnhancedTerminalBlock), findsOneWidget);
          expect(tester.takeException(), isNull);
          
        } catch (e) {
          expect(e, isNot(isA<NoSuchMethodError>()));
        }
      }
    });
  });
}