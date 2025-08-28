import 'package:flutter_test/flutter_test.dart';
import 'package:devpocket_warp_app/services/command_type_detector.dart';

void main() {
  group('CommandTypeDetector', () {
    late CommandTypeDetector detector;

    setUp(() {
      detector = CommandTypeDetector.instance;
      detector.clearCache(); // Clear cache before each test
    });

    group('One-shot command detection', () {
      final oneShotCommands = [
        'ls',
        'pwd',
        'whoami',
        'date',
        'cat file.txt',
        'grep pattern file.txt',
        'mkdir test',
        'rm file.txt',
        'cp source dest',
        'mv old new',
        'curl https://api.example.com',
        'wget https://file.com/download',
      ];

      for (final command in oneShotCommands) {
        test('should detect "$command" as one-shot', () {
          final result = detector.detectCommandType(command);
          expect(result.type, CommandType.oneShot);
          expect(result.showActivityIndicator, false);
          expect(result.processInfo.isPersistent, false);
        });
      }
    });

    group('Continuous command detection', () {
      final continuousCommands = [
        'top',
        'htop',
        'watch ps',
        'tail -f /var/log/system.log',
        'npm run dev',
        'yarn start',
        'docker logs -f container',
        'journalctl -f',
        'ping google.com',
        'npm run start',
        'next dev',
        'vite',
        'webpack-dev-server',
      ];

      for (final command in continuousCommands) {
        test('should detect "$command" as continuous', () {
          final result = detector.detectCommandType(command);
          expect(result.type, CommandType.continuous);
          expect(result.showActivityIndicator, true);
          expect(result.processInfo.isPersistent, true);
        });
      }
    });

    group('Interactive command detection', () {
      final interactiveCommands = [
        'vim file.txt',
        'nano config.ini',
        'emacs',
        'ssh user@host',
        'python',
        'node',
        'mysql',
        'psql',
        'less large-file.txt',
        'man command',
        'tmux',
        'screen',
      ];

      for (final command in interactiveCommands) {
        test('should detect "$command" as interactive', () {
          final result = detector.detectCommandType(command);
          expect(result.type, CommandType.interactive);
          expect(result.processInfo.requiresInput, true);
          expect(result.processInfo.isPersistent, true);
        });
      }
    });

    group('Edge cases', () {
      test('should handle commands with pipes', () {
        final result = detector.detectCommandType('ls | grep test');
        expect(result.type, CommandType.oneShot); // Based on primary command
      });

      test('should handle commands with options', () {
        final result = detector.detectCommandType('tail -f logfile.txt');
        expect(result.type, CommandType.continuous);
        expect(result.showActivityIndicator, true);
      });

      test('should handle unknown commands as one-shot', () {
        final result = detector.detectCommandType('unknown-command');
        expect(result.type, CommandType.oneShot);
        expect(result.showActivityIndicator, false);
      });

      test('should handle complex command chains', () {
        final result = detector.detectCommandType('cd /tmp && ls -la');
        expect(result.type, CommandType.oneShot);
      });

      test('should handle empty commands', () {
        final result = detector.detectCommandType('');
        expect(result.type, CommandType.oneShot);
      });

      test('should handle commands with multiple spaces', () {
        final result = detector.detectCommandType('   ls   -la   ');
        expect(result.type, CommandType.oneShot);
      });
    });

    group('Caching', () {
      test('should cache command detection results', () {
        const command = 'ls -la';
        
        // First call
        final result1 = detector.detectCommandType(command);
        
        // Second call should return cached result
        final result2 = detector.detectCommandType(command);
        
        expect(identical(result1, result2), true);
      });

      test('should provide cache statistics', () {
        detector.detectCommandType('ls');
        detector.detectCommandType('top');
        detector.detectCommandType('vim');
        
        final stats = detector.getCacheStats();
        expect(stats['cacheSize'], 3);
        expect(stats['typeDistribution']['oneShot'], 1);
        expect(stats['typeDistribution']['continuous'], 1);
        expect(stats['typeDistribution']['interactive'], 1);
      });

      test('should clear cache when requested', () {
        detector.detectCommandType('ls');
        expect(detector.getCacheStats()['cacheSize'], 1);
        
        detector.clearCache();
        expect(detector.getCacheStats()['cacheSize'], 0);
      });
    });

    group('Performance', () {
      test('should detect commands quickly', () {
        const commands = [
          'ls', 'top', 'vim', 'npm run dev', 'python', 'tail -f log'
        ];
        
        final stopwatch = Stopwatch()..start();
        
        for (final command in commands) {
          detector.detectCommandType(command);
        }
        
        stopwatch.stop();
        
        // Should complete in under 10ms for 6 commands
        expect(stopwatch.elapsedMilliseconds, lessThan(10));
      });

      test('should benefit from caching on repeated calls', () {
        const command = 'npm run dev';
        
        // First call (no cache)
        final stopwatch1 = Stopwatch()..start();
        detector.detectCommandType(command);
        stopwatch1.stop();
        final firstCallTime = stopwatch1.elapsedMicroseconds;
        
        // Second call (cached)
        final stopwatch2 = Stopwatch()..start();
        detector.detectCommandType(command);
        stopwatch2.stop();
        final secondCallTime = stopwatch2.elapsedMicroseconds;
        
        // Cached call should be significantly faster
        expect(secondCallTime, lessThan(firstCallTime));
      });
    });

    group('Debug information', () {
      test('should provide detailed command information', () {
        final info = detector.debugCommandInfo('npm run dev');
        
        expect(info['command'], 'npm run dev');
        expect(info['type'], 'continuous');
        expect(info['processType'], 'devServer');
        expect(info['displayName'], 'Continuous');
        expect(info['showActivityIndicator'], true);
        expect(info['isPersistent'], true);
      });
    });

    group('Helper methods', () {
      test('should provide convenience methods', () {
        expect(detector.isOneShot('ls'), true);
        expect(detector.isOneShot('top'), false);
        
        expect(detector.isContinuous('top'), true);
        expect(detector.isContinuous('ls'), false);
        
        expect(detector.isInteractive('vim'), true);
        expect(detector.isInteractive('ls'), false);
      });

      test('should return correct command type enum', () {
        expect(detector.getCommandType('ls'), CommandType.oneShot);
        expect(detector.getCommandType('top'), CommandType.continuous);
        expect(detector.getCommandType('vim'), CommandType.interactive);
      });
    });

    group('Command examples', () {
      test('should provide command examples for each type', () {
        final examples = detector.getCommandExamples();
        
        expect(examples[CommandType.oneShot], isNotEmpty);
        expect(examples[CommandType.continuous], isNotEmpty);
        expect(examples[CommandType.interactive], isNotEmpty);
        
        // Check that examples are properly categorized
        for (final command in examples[CommandType.oneShot]!) {
          expect(detector.getCommandType(command), CommandType.oneShot);
        }
        
        for (final command in examples[CommandType.continuous]!) {
          expect(detector.getCommandType(command), CommandType.continuous);
        }
        
        for (final command in examples[CommandType.interactive]!) {
          expect(detector.getCommandType(command), CommandType.interactive);
        }
      });
    });
  });
}