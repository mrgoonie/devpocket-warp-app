import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/services/fullscreen_command_detector.dart';

void main() {
  group('FullscreenCommandDetector', () {
    late FullscreenCommandDetector detector;

    setUp(() {
      detector = FullscreenCommandDetector.instance;
    });

    group('shouldTriggerFullscreen', () {
      test('detects text editors as fullscreen commands', () {
        expect(detector.shouldTriggerFullscreen('vi test.txt'), isTrue);
        expect(detector.shouldTriggerFullscreen('vim test.txt'), isTrue);
        expect(detector.shouldTriggerFullscreen('nvim test.txt'), isTrue);
        expect(detector.shouldTriggerFullscreen('nano test.txt'), isTrue);
        expect(detector.shouldTriggerFullscreen('emacs test.txt'), isTrue);
      });

      test('detects system monitors as fullscreen commands', () {
        expect(detector.shouldTriggerFullscreen('top'), isTrue);
        expect(detector.shouldTriggerFullscreen('htop'), isTrue);
        expect(detector.shouldTriggerFullscreen('btop'), isTrue);
        expect(detector.shouldTriggerFullscreen('atop'), isTrue);
      });

      test('detects pagers as fullscreen commands', () {
        expect(detector.shouldTriggerFullscreen('less /var/log/system.log'), isTrue);
        expect(detector.shouldTriggerFullscreen('more README.md'), isTrue);
        expect(detector.shouldTriggerFullscreen('man ls'), isTrue);
      });

      test('detects git pager commands as fullscreen commands', () {
        expect(detector.shouldTriggerFullscreen('git log --oneline'), isTrue);
        expect(detector.shouldTriggerFullscreen('git diff'), isTrue);
        expect(detector.shouldTriggerFullscreen('git show HEAD'), isTrue);
        expect(detector.shouldTriggerFullscreen('git blame file.txt'), isTrue);
      });

      test('detects SSH connections as fullscreen commands', () {
        expect(detector.shouldTriggerFullscreen('ssh user@example.com'), isTrue);
      });

      test('does not trigger fullscreen for block-interactive commands', () {
        expect(detector.shouldTriggerFullscreen('python'), isFalse);
        expect(detector.shouldTriggerFullscreen('node'), isFalse);
        expect(detector.shouldTriggerFullscreen('npm run dev'), isFalse);
        expect(detector.shouldTriggerFullscreen('rails server'), isFalse);
      });

      test('does not trigger fullscreen for oneshot commands', () {
        expect(detector.shouldTriggerFullscreen('ls -la'), isFalse);
        expect(detector.shouldTriggerFullscreen('cat file.txt'), isFalse);
        expect(detector.shouldTriggerFullscreen('pwd'), isFalse);
        expect(detector.shouldTriggerFullscreen('echo hello'), isFalse);
      });
    });

    group('detectHandlingMode', () {
      test('correctly classifies fullscreen modal commands', () {
        expect(
          detector.detectHandlingMode('vi test.txt'),
          equals(CommandHandlingMode.fullscreenModal),
        );
        expect(
          detector.detectHandlingMode('top'),
          equals(CommandHandlingMode.fullscreenModal),
        );
        expect(
          detector.detectHandlingMode('less file.txt'),
          equals(CommandHandlingMode.fullscreenModal),
        );
      });

      test('correctly classifies block-interactive commands', () {
        expect(
          detector.detectHandlingMode('python'),
          equals(CommandHandlingMode.blockInteractive),
        );
        expect(
          detector.detectHandlingMode('npm run dev'),
          equals(CommandHandlingMode.blockInteractive),
        );
        expect(
          detector.detectHandlingMode('watch ls'),
          equals(CommandHandlingMode.blockInteractive),
        );
      });

      test('correctly classifies oneshot commands', () {
        expect(
          detector.detectHandlingMode('ls -la'),
          equals(CommandHandlingMode.oneshot),
        );
        expect(
          detector.detectHandlingMode('cat file.txt'),
          equals(CommandHandlingMode.oneshot),
        );
        expect(
          detector.detectHandlingMode('mkdir test'),
          equals(CommandHandlingMode.oneshot),
        );
      });
    });

    group('getCommandDetails', () {
      test('provides comprehensive command analysis', () {
        final details = detector.getCommandDetails('vi test.txt');
        
        expect(details['command'], equals('vi test.txt'));
        expect(details['handlingMode'], equals('fullscreenModal'));
        expect(details['requiresInput'], isTrue);
        expect(details['isPersistent'], isTrue);
        expect(details['needsPTY'], isTrue);
        expect(details['needsFullscreen'], isTrue);
      });

      test('correctly analyzes block-interactive commands', () {
        final details = detector.getCommandDetails('python');
        
        expect(details['command'], equals('python'));
        expect(details['handlingMode'], equals('blockInteractive'));
        expect(details['processType'], equals('repl'));
        expect(details['requiresInput'], isTrue);
        expect(details['isPersistent'], isTrue);
      });

      test('correctly analyzes oneshot commands', () {
        final details = detector.getCommandDetails('ls -la');
        
        expect(details['command'], equals('ls -la'));
        expect(details['handlingMode'], equals('oneshot'));
        expect(details['processType'], equals('oneshot'));
        expect(details['requiresInput'], isFalse);
        expect(details['isPersistent'], isFalse);
      });
    });

    group('edge cases', () {
      test('handles empty and whitespace commands', () {
        expect(detector.shouldTriggerFullscreen(''), isFalse);
        expect(detector.shouldTriggerFullscreen('   '), isFalse);
        expect(detector.shouldTriggerFullscreen('\n\t'), isFalse);
      });

      test('handles case sensitivity correctly', () {
        expect(detector.shouldTriggerFullscreen('VI test.txt'), isTrue);
        expect(detector.shouldTriggerFullscreen('Vim test.txt'), isTrue);
        expect(detector.shouldTriggerFullscreen('TOP'), isTrue);
      });

      test('handles commands with complex arguments', () {
        expect(
          detector.shouldTriggerFullscreen('vim +10 /path/to/file.txt'),
          isTrue,
        );
        expect(
          detector.shouldTriggerFullscreen('top -u username -p 1234'),
          isTrue,
        );
        expect(
          detector.shouldTriggerFullscreen('less -N +G /var/log/system.log'),
          isTrue,
        );
      });
    });

    group('pattern summary', () {
      test('getPatternSummary returns expected structure', () {
        final summary = detector.getPatternSummary();
        
        expect(summary, isA<Map<String, dynamic>>());
        expect(summary['fullscreenCommands'], isA<List>());
        expect(summary['blockInteractiveCommands'], isA<List>());
        expect(summary['fullscreenPatterns'], isA<List>());
        expect(summary['blockInteractivePatterns'], isA<List>());
      });
    });
  });
}