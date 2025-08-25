// DevPocket Widget Tests
//
// Basic smoke test to ensure the app builds without critical errors.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:devpocket_warp_app/main.dart';
import 'package:devpocket_warp_app/providers/auth_provider.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('DevPocket App Widget Tests', () {
    testWidgets('DevPocket App builds successfully without errors', (WidgetTester tester) async {
      // Store original ErrorWidget.builder to restore later
      final originalErrorWidgetBuilder = ErrorWidget.builder;
      
      // Create the app with mock providers to avoid real service initialization
      final testApp = createTestApp(child: const DevPocketApp());
      
      try {
        // Build our app and trigger a frame
        await pumpAppWidget(tester, testApp);

        // Verify the app builds successfully
        expect(find.byType(MaterialApp), findsOneWidget);
        
        // Verify the app doesn't crash on initial build
        expect(tester.takeException(), isNull);
        
        // Wait for any timers to complete
        await tester.pumpAndSettle();
        
        // Verify no pending timers remain
        expect(tester.binding.transientCallbackCount, equals(0));
        
      } finally {
        // Restore original ErrorWidget.builder
        ErrorWidget.builder = originalErrorWidgetBuilder;
      }
    });

    testWidgets('DevPocket App handles unauthenticated state correctly', (WidgetTester tester) async {
      // Store original ErrorWidget.builder
      final originalErrorWidgetBuilder = ErrorWidget.builder;
      
      // Create app with unauthenticated state
      final testApp = createTestApp(
        child: const DevPocketApp(),
        additionalOverrides: [
          // Override auth provider to return unauthenticated state immediately
          authProvider.overrideWith((ref) => MockAuthNotifier(TestAuthStates.unauthenticated)),
        ],
      );
      
      try {
        // Build and test
        await pumpAppWidget(tester, testApp);

        // App should build without errors
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        // Wait for all async operations to complete
        await tester.pumpAndSettle();
        
      } finally {
        // Restore original ErrorWidget.builder
        ErrorWidget.builder = originalErrorWidgetBuilder;
      }
    });

    testWidgets('DevPocket App can pump without immediate crashes', (WidgetTester tester) async {
      // Store original ErrorWidget.builder
      final originalErrorWidgetBuilder = ErrorWidget.builder;
      
      // Create a minimal app for testing
      final testApp = createTestApp(child: const DevPocketApp());
      
      try {
        // Just pump once without settling to avoid timeout
        await tester.pumpWidget(testApp);

        // App should build without errors on initial pump
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(tester.takeException(), isNull);
        
        // Pump once more to handle initial state changes
        await tester.pump();
        
      } finally {
        // Restore original ErrorWidget.builder
        ErrorWidget.builder = originalErrorWidgetBuilder;
      }
    });
  });
}
