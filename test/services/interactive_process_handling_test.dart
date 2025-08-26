import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/services/persistent_process_detector.dart';
import 'package:devpocket_warp_app/services/active_block_manager.dart';
import 'package:devpocket_warp_app/services/pty_focus_manager.dart';
import 'package:devpocket_warp_app/models/enhanced_terminal_models.dart';
import 'package:devpocket_warp_app/widgets/terminal/terminal_block.dart';

void main() {
  group('Interactive Process Handling Tests', () {
    late PersistentProcessDetector processDetector;
    late ActiveBlockManager activeBlockManager;
    late PTYFocusManager focusManager;

    setUp(() {
      processDetector = PersistentProcessDetector.instance;
      activeBlockManager = ActiveBlockManager.instance;
      focusManager = PTYFocusManager.instance;
      
      // Clear any previous state
      processDetector.clearCache();
    });

    tearDown(() async {
      // Cleanup after each test
      await activeBlockManager.cleanupAll();
      focusManager.dispose();
    });

    group('PersistentProcessDetector', () {
      test('should detect REPL commands correctly', () {
        final testCases = [
          'python',
          'python3',
          'node',
          'irb',
          'julia',
          'R',
          'psql',
          'mysql',
          'claude',
        ];

        for (final command in testCases) {
          final info = processDetector.detectProcessType(command);
          expect(info.type, ProcessType.repl, reason: 'Command "$command" should be detected as REPL');
          expect(info.requiresInput, isTrue, reason: 'REPL "$command" should require input');
          expect(info.isPersistent, isTrue, reason: 'REPL "$command" should be persistent');
        }
      });

      test('should detect development server commands correctly', () {
        final testCases = [
          'npm run dev',
          'pnpm dev',
          'yarn dev',
          'next dev',
          'vite',
          'rails server',
          'python manage.py runserver',
          'flask run',
          'flutter run',
        ];

        for (final command in testCases) {
          final info = processDetector.detectProcessType(command);
          expect(info.type, ProcessType.devServer, reason: 'Command "$command" should be detected as dev server');
          expect(info.isPersistent, isTrue, reason: 'Dev server "$command" should be persistent');
        }
      });

      test('should detect watcher commands correctly', () {
        final testCases = [
          'watch ls',
          'nodemon server.js',
          'tail -f /var/log/system.log',
          'docker logs -f container',
          'kubectl logs -f pod',
          'webpack --watch',
        ];

        for (final command in testCases) {
          final info = processDetector.detectProcessType(command);
          expect(info.type, ProcessType.watcher, reason: 'Command "$command" should be detected as watcher');
          expect(info.isPersistent, isTrue, reason: 'Watcher "$command" should be persistent');
        }
      });

      test('should detect interactive commands correctly', () {
        final testCases = [
          'vi file.txt',
          'nano config.ini',
          'top',
          'htop',
          'less README.md',
          'man git',
          'ssh user@host',
        ];

        for (final command in testCases) {
          final info = processDetector.detectProcessType(command);
          expect(info.type, ProcessType.interactive, reason: 'Command "$command" should be detected as interactive');
          expect(info.requiresInput, isTrue, reason: 'Interactive command "$command" should require input');
          expect(info.isPersistent, isTrue, reason: 'Interactive command "$command" should be persistent');
        }
      });

      test('should detect oneshot commands correctly', () {
        final testCases = [
          'ls -la',
          'pwd',
          'echo hello',
          'cat file.txt',
          'grep pattern file.txt',
          'cp source dest',
          'mkdir directory',
        ];

        for (final command in testCases) {
          final info = processDetector.detectProcessType(command);
          expect(info.type, ProcessType.oneshot, reason: 'Command "$command" should be detected as oneshot');
          expect(info.requiresInput, isFalse, reason: 'Oneshot command "$command" should not require input');
          expect(info.isPersistent, isFalse, reason: 'Oneshot command "$command" should not be persistent');
        }
      });

      test('should cache detection results', () {
        const command = 'python';
        
        // First call should detect and cache
        final info1 = processDetector.detectProcessType(command);
        
        // Second call should return cached result
        final info2 = processDetector.detectProcessType(command);
        
        expect(identical(info1, info2), isFalse); // Different instances but same values
        expect(info1.type, info2.type);
        expect(info1.command, info2.command);
        
        // Verify cache has the entry
        final stats = processDetector.getCacheStats();
        expect(stats['cacheSize'], greaterThan(0));
      });

      test('should handle complex commands correctly', () {
        final testCases = {
          'npm run dev -- --port 3000': ProcessType.devServer,
          'python -c "import time; time.sleep(10)"': ProcessType.repl,
          'watch -n 1 ls -la': ProcessType.watcher,
          'vi /path/with spaces/file.txt': ProcessType.interactive,
        };

        testCases.forEach((command, expectedType) {
          final info = processDetector.detectProcessType(command);
          expect(info.type, expectedType, reason: 'Complex command "$command" should be detected as $expectedType');
        });
      });
    });

    group('ActiveBlockManager', () {
      test('should initialize correctly', () {
        expect(activeBlockManager.activeBlockIds, isEmpty);
        expect(activeBlockManager.focusedBlockId, isNull);
      });

      test('should activate and track interactive blocks', () async {
        const sessionId = 'test-session';
        const blockId = 'test-block';
        const command = 'python';

        final blockData = EnhancedTerminalBlockData(
          id: blockId,
          command: command,
          status: TerminalBlockStatus.running,
          timestamp: DateTime.now(),
          sessionId: sessionId,
          index: 0,
        );

        final result = await activeBlockManager.activateBlock(
          blockId: blockId,
          sessionId: sessionId,
          command: command,
          blockData: blockData,
        );

        expect(result, isNotNull);
        expect(activeBlockManager.activeBlockIds, contains(blockId));
        expect(activeBlockManager.isBlockActive(blockId), isTrue);
      });

      test('should handle block termination correctly', () async {
        const sessionId = 'test-session';
        const blockId = 'test-block';
        const command = 'python';

        final blockData = EnhancedTerminalBlockData(
          id: blockId,
          command: command,
          status: TerminalBlockStatus.running,
          timestamp: DateTime.now(),
          sessionId: sessionId,
          index: 0,
        );

        // Activate block
        await activeBlockManager.activateBlock(
          blockId: blockId,
          sessionId: sessionId,
          command: command,
          blockData: blockData,
        );

        expect(activeBlockManager.isBlockActive(blockId), isTrue);

        // Terminate block
        final terminated = await activeBlockManager.terminateBlock(blockId);

        expect(terminated, isTrue);
        expect(activeBlockManager.isBlockActive(blockId), isFalse);
        expect(activeBlockManager.activeBlockIds, isEmpty);
      });

      test('should auto-terminate previous active process on new command', () async {
        const sessionId = 'test-session';
        const blockId1 = 'test-block-1';
        const blockId2 = 'test-block-2';
        const command1 = 'python';
        const command2 = 'node';

        final blockData1 = EnhancedTerminalBlockData(
          id: blockId1,
          command: command1,
          status: TerminalBlockStatus.running,
          timestamp: DateTime.now(),
          sessionId: sessionId,
          index: 0,
        );

        final blockData2 = EnhancedTerminalBlockData(
          id: blockId2,
          command: command2,
          status: TerminalBlockStatus.running,
          timestamp: DateTime.now(),
          sessionId: sessionId,
          index: 1,
        );

        // Activate first block
        await activeBlockManager.activateBlock(
          blockId: blockId1,
          sessionId: sessionId,
          command: command1,
          blockData: blockData1,
        );

        expect(activeBlockManager.isBlockActive(blockId1), isTrue);

        // Start new command (should auto-terminate previous)
        await activeBlockManager.onNewCommandStarted(sessionId, command2);

        // Wait a bit for async cleanup
        await Future.delayed(const Duration(milliseconds: 100));

        expect(activeBlockManager.isBlockActive(blockId1), isFalse);

        // Activate second block
        await activeBlockManager.activateBlock(
          blockId: blockId2,
          sessionId: sessionId,
          command: command2,
          blockData: blockData2,
        );

        expect(activeBlockManager.isBlockActive(blockId2), isTrue);
      });
    });

    group('PTYFocusManager', () {
      setUp(() {
        focusManager.initialize();
      });

      test('should initialize correctly', () {
        expect(focusManager.currentState.destination, InputDestination.mainInput);
        expect(focusManager.currentState.focusedBlockId, isNull);
      });

      test('should handle text input routing', () {
        const input = 'print("hello")';
        
        // Initially should route to main input (return false to let UI handle)
        final handled = focusManager.handleTextInput(input);
        expect(handled, isFalse);
      });

      test('should handle control key sequences', () {
        // Test control keys when no block is focused
        final ctrlCHandled = focusManager.handleControlKey(ControlKey.ctrlC);
        expect(ctrlCHandled, isTrue); // Should be handled by main input context
      });

      test('should provide input routing suggestions', () {
        final suggestions = focusManager.getInputRoutingSuggestions();
        expect(suggestions, isNotEmpty);
        expect(suggestions, contains('Type commands here'));
      });

      test('should provide debug information', () {
        final debugInfo = focusManager.getFocusDebugInfo();
        expect(debugInfo, containsPair('initialized', isTrue));
        expect(debugInfo, contains('currentState'));
        expect(debugInfo, contains('activeBlocks'));
      });
    });

    group('Integration Tests', () {
      test('should handle complete workflow for interactive command', () async {
        const sessionId = 'integration-session';
        const blockId = 'integration-block';
        const command = 'python';

        // Step 1: Detect process type
        final processInfo = processDetector.detectProcessType(command);
        expect(processInfo.type, ProcessType.repl);
        expect(processInfo.needsSpecialHandling, isTrue);

        // Step 2: Create enhanced block data
        final blockData = EnhancedTerminalBlockData(
          id: blockId,
          command: command,
          status: TerminalBlockStatus.running,
          timestamp: DateTime.now(),
          sessionId: sessionId,
          index: 0,
        );

        // Step 3: Activate block
        final result = await activeBlockManager.activateBlock(
          blockId: blockId,
          sessionId: sessionId,
          command: command,
          blockData: blockData,
        );

        expect(result, isNotNull);
        expect(activeBlockManager.isBlockActive(blockId), isTrue);

        // Step 4: Focus block (should happen automatically for interactive processes)
        focusManager.focusBlock(blockId);

        // Step 5: Send input to focused block
        const testInput = 'x = 42';
        activeBlockManager.sendInputToBlock(blockId, testInput);

        // Step 6: Verify state
        expect(activeBlockManager.canBlockAcceptInput(blockId), isTrue);

        // Step 7: Cleanup
        await activeBlockManager.terminateBlock(blockId);
        expect(activeBlockManager.isBlockActive(blockId), isFalse);
      });

      test('should handle multiple sessions correctly', () async {
        const session1 = 'session-1';
        const session2 = 'session-2';
        const block1 = 'block-1';
        const block2 = 'block-2';

        final blockData1 = EnhancedTerminalBlockData(
          id: block1,
          command: 'python',
          status: TerminalBlockStatus.running,
          timestamp: DateTime.now(),
          sessionId: session1,
          index: 0,
        );

        final blockData2 = EnhancedTerminalBlockData(
          id: block2,
          command: 'node',
          status: TerminalBlockStatus.running,
          timestamp: DateTime.now(),
          sessionId: session2,
          index: 0,
        );

        // Activate blocks in different sessions
        await activeBlockManager.activateBlock(
          blockId: block1,
          sessionId: session1,
          command: 'python',
          blockData: blockData1,
        );

        await activeBlockManager.activateBlock(
          blockId: block2,
          sessionId: session2,
          command: 'node',
          blockData: blockData2,
        );

        // Verify both blocks are active
        expect(activeBlockManager.isBlockActive(block1), isTrue);
        expect(activeBlockManager.isBlockActive(block2), isTrue);

        // Verify session mappings
        final session1Blocks = activeBlockManager.getActiveBlocksForSession(session1);
        final session2Blocks = activeBlockManager.getActiveBlocksForSession(session2);

        expect(session1Blocks, contains(block1));
        expect(session2Blocks, contains(block2));

        // Cleanup
        await activeBlockManager.terminateBlock(block1);
        await activeBlockManager.terminateBlock(block2);
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle unknown commands gracefully', () {
        final unknownCommands = [
          'nonexistent-command',
          'some-random-binary',
          'custom-script.sh',
        ];

        for (final command in unknownCommands) {
          final info = processDetector.detectProcessType(command);
          expect(info.type, ProcessType.oneshot);
          expect(info.needsSpecialHandling, isFalse);
        }
      });

      test('should handle empty and invalid commands', () {
        final invalidCommands = ['', '   ', '\n', '\t'];

        for (final command in invalidCommands) {
          final info = processDetector.detectProcessType(command);
          expect(info.type, ProcessType.oneshot);
        }
      });

      test('should handle rapid command execution', () async {
        const sessionId = 'rapid-session';
        
        for (int i = 0; i < 5; i++) {
          await activeBlockManager.onNewCommandStarted(sessionId, 'echo $i');
        }

        // Should not crash or leave dangling processes
        expect(activeBlockManager.activeBlockIds.length, lessThanOrEqualTo(1));
      });

      test('should cleanup properly on dispose', () async {
        const sessionId = 'dispose-session';
        const blockId = 'dispose-block';

        final blockData = EnhancedTerminalBlockData(
          id: blockId,
          command: 'python',
          status: TerminalBlockStatus.running,
          timestamp: DateTime.now(),
          sessionId: sessionId,
          index: 0,
        );

        await activeBlockManager.activateBlock(
          blockId: blockId,
          sessionId: sessionId,
          command: 'python',
          blockData: blockData,
        );

        expect(activeBlockManager.isBlockActive(blockId), isTrue);

        // Cleanup all
        await activeBlockManager.cleanupAll();

        expect(activeBlockManager.activeBlockIds, isEmpty);
        expect(activeBlockManager.focusedBlockId, isNull);
      });
    });
  });
}