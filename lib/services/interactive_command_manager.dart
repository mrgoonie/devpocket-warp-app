import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import '../services/fullscreen_command_detector.dart';
import '../widgets/terminal/fullscreen_terminal_modal.dart';
import 'modal_session_models.dart';

/// Manages fullscreen interactive command sessions
class InteractiveCommandManager {
  static InteractiveCommandManager? _instance;
  static InteractiveCommandManager get instance => _instance ??= InteractiveCommandManager._();
  
  InteractiveCommandManager._();

  ModalSession? _currentSession;
  Process? _currentProcess;
  StreamSubscription? _outputSubscription;
  StreamSubscription? _errorSubscription;
  final StreamController<String> _inputController = StreamController<String>.broadcast();
  
  bool get isActive => _currentSession != null && _currentProcess != null;
  ModalSession? get currentSession => _currentSession;

  /// Launch fullscreen modal for interactive command
  static Future<void> launchFullscreenModal({
    required BuildContext context,
    required String command,
    SSHClient? sshClient,
    Map<String, String>? environment,
    required Function(String) onOutput,
    Function(String)? onError,
    Function(int)? onExit,
  }) async {
    final detector = FullscreenCommandDetector.instance;
    
    // Verify command should trigger fullscreen
    if (!detector.shouldTriggerFullscreen(command)) {
      debugPrint('Command "$command" should not trigger fullscreen modal');
      return;
    }
    
    // Create the modal
    final modal = _createModal(
      context: context,
      command: command,
      sshClient: sshClient,
      environment: environment,
      onOutput: onOutput,
      onError: onError,
      onExit: onExit,
    );
    
    if (context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => modal,
        ),
      );
    }
  }

  static Widget _createModal({
    required BuildContext context,
    required String command,
    SSHClient? sshClient,
    Map<String, String>? environment,
    required Function(String) onOutput,
    Function(String)? onError,
    Function(int)? onExit,
  }) {
    return FullscreenTerminalModal(
      command: command,
      sshClient: sshClient,
      environment: environment,
      onClose: () {
        Navigator.of(context).pop();
      },
    );
  }

  /// Execute command in fullscreen terminal
  Future<void> executeFullscreenCommand({
    required String command,
    required Terminal terminal,
    SSHClient? sshClient,
    Map<String, String>? environment,
    Function(String)? onOutput,
    Function(String)? onError,
    Function(int)? onExit,
  }) async {
    try {
      // Create session
      _currentSession = ModalSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        command: command,
        startTime: DateTime.now(),
        sshClient: sshClient,
        environment: environment ?? {},
      );

      if (sshClient != null) {
        await _executeSSHCommand(
          command: command,
          sshClient: sshClient,
          terminal: terminal,
          onOutput: onOutput,
          onError: onError,
          onExit: onExit,
        );
      } else {
        await _executeLocalCommand(
          command: command,
          terminal: terminal,
          environment: environment,
          onOutput: onOutput,
          onError: onError,
          onExit: onExit,
        );
      }
      
    } catch (e) {
      onError?.call('Failed to execute command: $e');
    }
  }

  /// Execute command via SSH
  Future<void> _executeSSHCommand({
    required String command,
    required SSHClient sshClient,
    required Terminal terminal,
    Function(String)? onOutput,
    Function(String)? onError,
    Function(int)? onExit,
  }) async {
    try {
      // For interactive commands, we need a PTY session
      final session = await sshClient.shell(
        pty: SSHPtyConfig(
          width: terminal.viewWidth,
          height: terminal.viewHeight,
          type: 'xterm-256color',
        ),
      );
      
      // Send the command to the shell
      session.write(Uint8List.fromList('$command\r\n'.codeUnits));
      
      // Stream SSH output to terminal
      _outputSubscription = session.stdout.listen(
        (data) {
          final text = utf8.decode(data);
          terminal.write(text);
          onOutput?.call(text);
        },
        onError: (error) {
          final errorText = 'SSH Error: $error';
          terminal.write(errorText);
          onError?.call(errorText);
        },
        onDone: () {
          onExit?.call(0); // SSH shell sessions don't have direct exit codes
          cleanup();
        },
      );

      // Handle SSH errors
      _errorSubscription = session.stderr.listen((data) {
        final text = utf8.decode(data);
        terminal.write(text);
        onError?.call(text);
      });

      // Handle input from terminal to SSH
      _inputController.stream.listen((input) {
        try {
          session.write(Uint8List.fromList(input.codeUnits));
        } catch (e) {
          onError?.call('Failed to send input: $e');
        }
      });
      
      // Store the session for cleanup
      _currentSession?.sshSession = session;

    } catch (e) {
      onError?.call('SSH execution failed: $e');
    }
  }

  /// Execute command locally
  Future<void> _executeLocalCommand({
    required String command,
    required Terminal terminal,
    Map<String, String>? environment,
    Function(String)? onOutput,
    Function(String)? onError,
    Function(int)? onExit,
  }) async {
    try {
      // Parse command into executable and arguments
      final parts = command.split(' ');
      final executable = parts.first;
      final arguments = parts.length > 1 ? parts.sublist(1) : <String>[];
      
      // Check if command is supported locally (iOS/Android restrictions)
      if (!_isCommandSupportedLocally(executable)) {
        onError?.call('Command "$executable" is not available locally. Use SSH connection to access this command.');
        onExit?.call(1);
        return;
      }
      
      // Set up environment
      final env = <String, String>{};
      env.addAll(Platform.environment);
      if (environment != null) {
        env.addAll(environment);
      }
      
      // Configure terminal environment variables
      env['TERM'] = 'xterm-256color';
      env['COLUMNS'] = terminal.viewWidth.toString();
      env['LINES'] = terminal.viewHeight.toString();
      
      // Start process with proper error handling
      try {
        _currentProcess = await Process.start(
          executable,
          arguments,
          environment: env,
          mode: ProcessStartMode.normal,
          runInShell: Platform.isAndroid || Platform.isIOS ? true : false, // Use shell on mobile for better compatibility
        );
      } catch (e) {
        // If process start fails, provide helpful error message
        final errorMessage = 'Failed to start "$executable": ${e.toString()}\n'
            'This command may not be available on mobile platforms.\n'
            'Consider using an SSH connection to access full terminal commands.';
        onError?.call(errorMessage);
        onExit?.call(1);
        return;
      }

      if (_currentProcess == null) {
        onError?.call('Failed to start process');
        return;
      }

      // Handle process output
      _outputSubscription = _currentProcess!.stdout
          .transform(utf8.decoder)
          .listen(
            (data) {
              terminal.write(data);
              onOutput?.call(data);
            },
            onError: (error) {
              final errorText = 'Process output error: $error';
              terminal.write(errorText);
              onError?.call(errorText);
            },
          );

      // Handle process errors
      _errorSubscription = _currentProcess!.stderr
          .transform(utf8.decoder)
          .listen(
            (data) {
              terminal.write(data);
              onError?.call(data);
            },
          );

      // Handle input from terminal to process
      _inputController.stream.listen((input) {
        _currentProcess?.stdin.write(input);
      });

      // Handle process completion
      _currentProcess!.exitCode.then((exitCode) {
        onExit?.call(exitCode);
        cleanup();
      });

    } catch (e) {
      onError?.call('Local execution failed: $e');
    }
  }

  /// Send input to the running command
  void sendInput(String input) {
    if (isActive) {
      _inputController.add(input);
    }
  }

  /// Terminate the running command
  Future<void> terminate() async {
    if (_currentProcess != null) {
      // Try graceful termination first
      _currentProcess!.kill(ProcessSignal.sigterm);
      
      // Wait a bit for graceful shutdown
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Force kill if still running
      if (!_currentProcess!.kill(ProcessSignal.sigkill)) {
        debugPrint('Failed to kill process');
      }
    }
    
    // Send Ctrl+C to SSH session if active
    if (_currentSession?.sshSession != null) {
      try {
        // Send interrupt signal (Ctrl+C)
        _currentSession!.sshSession!.write(Uint8List.fromList([0x03]));
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        debugPrint('Failed to send interrupt to SSH session: $e');
      }
    }
    
    cleanup();
  }

  /// Send signal to the running command
  void sendSignal(ProcessSignal signal) {
    _currentProcess?.kill(signal);
  }

  /// Send common control signals
  void sendInterrupt() => sendSignal(ProcessSignal.sigint);    // Ctrl+C
  void sendTerminate() => sendSignal(ProcessSignal.sigterm);   // Terminate
  void sendSuspend() => sendSignal(ProcessSignal.sigtstp);     // Ctrl+Z
  void sendQuit() => sendSignal(ProcessSignal.sigquit);        // Ctrl+\

  /// Resize terminal and notify process
  void resizeTerminal(int cols, int rows) {
    if (_currentProcess != null && _currentSession != null) {
      // Update environment for next commands
      _currentSession!.environment['COLUMNS'] = cols.toString();
      _currentSession!.environment['LINES'] = rows.toString();
      
      // Send SIGWINCH to notify process of size change
      sendSignal(ProcessSignal.sigwinch);
    }
  }

  /// Check if command is supported for local execution on mobile platforms
  bool _isCommandSupportedLocally(String executable) {
    // Commands that definitely don't work on mobile platforms
    final unsupportedCommands = {
      // Text editors requiring full terminal
      'vi', 'vim', 'nvim', 'neovim', 'emacs', 'nano', 'pico', 'micro',
      
      // System monitors
      'top', 'htop', 'btop', 'atop', 'iotop', 'iftop', 'nethogs',
      
      // Pagers
      'less', 'more', 'most',
      
      // Terminal multiplexers
      'tmux', 'screen', 'byobu',
      
      // File managers
      'mc', 'ranger', 'nnn', 'lf', 'vifm',
      
      // System utilities typically not available on mobile
      'sudo', 'su', 'systemctl', 'service', 'mount', 'umount',
      'apt', 'yum', 'pacman', 'brew',
    };
    
    // Check if on mobile platform - most interactive commands won't work
    if (Platform.isAndroid || Platform.isIOS) {
      return !unsupportedCommands.contains(executable.toLowerCase());
    }
    
    // On desktop platforms, most commands should work
    return true;
  }

  /// Clean up resources
  void cleanup() {
    _outputSubscription?.cancel();
    _errorSubscription?.cancel();
    
    _currentProcess?.kill();
    _currentProcess = null;
    
    if (_currentSession != null) {
      // Close SSH session if exists
      _currentSession!.sshSession?.close();
      _currentSession!.endTime = DateTime.now();
      _currentSession = null;
    }
    
    debugPrint('InteractiveCommandManager: Cleaned up session');
  }

  /// Get session statistics
  Map<String, dynamic> getSessionStats() {
    if (_currentSession == null) {
      return {'active': false};
    }

    final duration = DateTime.now().difference(_currentSession!.startTime);
    
    return {
      'active': isActive,
      'sessionId': _currentSession!.id,
      'command': _currentSession!.command,
      'startTime': _currentSession!.startTime.toIso8601String(),
      'duration': duration.inSeconds,
      'isSSH': _currentSession!.sshClient != null,
      'environment': _currentSession!.environment,
    };
  }

  /// Dispose manager
  void dispose() {
    cleanup();
    _inputController.close();
  }
}