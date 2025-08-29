import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/services/terminal_application_tracker.dart';

void main() {
  group('TerminalApplicationTracker', () {
    late TerminalApplicationTracker tracker;

    setUp(() {
      tracker = TerminalApplicationTracker.instance;
      tracker.clearCurrentCommand();
    });

    tearDown(() {
      tracker.clearCurrentCommand();
    });

    group('ESC Key Applications Detection', () {
      test('should detect vi as requiring ESC key', () {
        tracker.updateCurrentCommand('vi test.txt');
        expect(tracker.isTerminalApplicationRunning, true);
        expect(tracker.currentCommand, 'vi test.txt');
      });

      test('should detect vim as requiring ESC key', () {
        tracker.updateCurrentCommand('vim ~/.bashrc');
        expect(tracker.isTerminalApplicationRunning, true);
        expect(tracker.currentCommand, 'vim ~/.bashrc');
      });

      test('should detect nano as requiring ESC key', () {
        tracker.updateCurrentCommand('nano file.txt');
        expect(tracker.isTerminalApplicationRunning, true);
        expect(tracker.currentCommand, 'nano file.txt');
      });

      test('should detect less as requiring ESC key', () {
        tracker.updateCurrentCommand('less README.md');
        expect(tracker.isTerminalApplicationRunning, true);
        expect(tracker.currentCommand, 'less README.md');
      });

      test('should not detect regular commands as requiring ESC key', () {
        tracker.updateCurrentCommand('ls -la');
        expect(tracker.isTerminalApplicationRunning, false);
        expect(tracker.currentCommand, 'ls -la');
      });

      test('should not detect empty command as requiring ESC key', () {
        tracker.updateCurrentCommand('');
        expect(tracker.isTerminalApplicationRunning, false);
        expect(tracker.currentCommand, '');
      });

      test('should not detect python REPL as requiring ESC key', () {
        tracker.updateCurrentCommand('python');
        expect(tracker.isTerminalApplicationRunning, false);
        expect(tracker.currentCommand, 'python');
      });
    });

    group('Command Management', () {
      test('should clear current command', () {
        tracker.updateCurrentCommand('vi test.txt');
        expect(tracker.isTerminalApplicationRunning, true);
        
        tracker.clearCurrentCommand();
        expect(tracker.isTerminalApplicationRunning, false);
        expect(tracker.currentCommand, null);
      });

      test('should update command state correctly', () {
        // Start with non-ESC command
        tracker.updateCurrentCommand('ls');
        expect(tracker.isTerminalApplicationRunning, false);
        
        // Switch to ESC command
        tracker.updateCurrentCommand('vim');
        expect(tracker.isTerminalApplicationRunning, true);
        
        // Switch back to non-ESC command
        tracker.updateCurrentCommand('cat file.txt');
        expect(tracker.isTerminalApplicationRunning, false);
      });

      test('should handle null command gracefully', () {
        tracker.updateCurrentCommand(null);
        expect(tracker.isTerminalApplicationRunning, false);
        expect(tracker.currentCommand, null);
      });

      test('should trim whitespace from commands', () {
        tracker.updateCurrentCommand('  vim test.txt  ');
        expect(tracker.isTerminalApplicationRunning, true);
        expect(tracker.currentCommand, 'vim test.txt');
      });
    });

    group('State Information', () {
      test('should provide correct state information', () {
        tracker.updateCurrentCommand('vi test.txt');
        final state = tracker.getState();
        
        expect(state['currentCommand'], 'vi test.txt');
        expect(state['isApplicationRunning'], true);
        expect(state['executable'], 'vi');
        expect(state['timestamp'], isA<String>());
      });

      test('should provide state for cleared command', () {
        tracker.clearCurrentCommand();
        final state = tracker.getState();
        
        expect(state['currentCommand'], null);
        expect(state['isApplicationRunning'], false);
        expect(state['executable'], null);
        expect(state['timestamp'], isA<String>());
      });
    });

    group('Command Prediction', () {
      test('should predict ESC key requirement correctly', () {
        expect(tracker.wouldRequireEscKey('vi test.txt'), true);
        expect(tracker.wouldRequireEscKey('vim ~/.vimrc'), true);
        expect(tracker.wouldRequireEscKey('nano file.txt'), true);
        expect(tracker.wouldRequireEscKey('less README.md'), true);
        expect(tracker.wouldRequireEscKey('emacs file.c'), true);
        
        expect(tracker.wouldRequireEscKey('ls -la'), false);
        expect(tracker.wouldRequireEscKey('cat file.txt'), false);
        expect(tracker.wouldRequireEscKey('python script.py'), false);
        expect(tracker.wouldRequireEscKey('grep pattern file.txt'), false);
      });
    });

    group('Force State Setting', () {
      test('should allow forcing application running state', () {
        tracker.updateCurrentCommand('ls');
        expect(tracker.isTerminalApplicationRunning, false);
        
        tracker.setApplicationRunning(true);
        expect(tracker.isTerminalApplicationRunning, true);
        
        tracker.setApplicationRunning(false);
        expect(tracker.isTerminalApplicationRunning, false);
      });
    });
  });
}