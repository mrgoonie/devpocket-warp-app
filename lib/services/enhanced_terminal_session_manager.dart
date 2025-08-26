import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

import '../models/ssh_profile_models.dart';
import '../widgets/terminal/terminal_block.dart';
import 'terminal_session_handler.dart';
import 'ssh_connection_manager.dart';

/// Enhanced terminal session manager for comprehensive terminal functionality
class EnhancedTerminalSessionManager {
  static EnhancedTerminalSessionManager? _instance;
  static EnhancedTerminalSessionManager get instance => _instance ??= EnhancedTerminalSessionManager._();

  EnhancedTerminalSessionManager._();

  final TerminalSessionHandler _sessionHandler = TerminalSessionHandler.instance;
  final SshConnectionManager _connectionManager = SshConnectionManager.instance;
  final Uuid _uuid = const Uuid();
  
  final Map<String, EnhancedTerminalSession> _sessions = {};
  final StreamController<EnhancedSessionEvent> _eventController = StreamController.broadcast();

  /// Stream of enhanced session events
  Stream<EnhancedSessionEvent> get events => _eventController.stream;

  /// Create enhanced SSH terminal session
  Future<String> createEnhancedSshSession(SshProfile profile) async {
    try {
      debugPrint('Creating enhanced SSH terminal session for: ${profile.name}');
      
      // Create underlying session
      final sessionId = await _sessionHandler.createSshSession(profile);
      
      // Create enhanced session wrapper
      final enhancedSession = EnhancedTerminalSession(
        id: sessionId,
        profileId: profile.id,
        sessionType: TerminalSessionType.ssh,
        profile: profile,
        createdAt: DateTime.now(),
      );
      
      _sessions[sessionId] = enhancedSession;
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.created,
        sessionId: sessionId,
        profileId: profile.id,
        message: 'Enhanced SSH terminal session created',
        timestamp: DateTime.now(),
      ));
      
      return sessionId;
      
    } catch (e) {
      debugPrint('Failed to create enhanced SSH terminal session: $e');
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.error,
        profileId: profile.id,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
      
      rethrow;
    }
  }

  /// Create enhanced local terminal session
  Future<String> createEnhancedLocalSession() async {
    try {
      debugPrint('Creating enhanced local terminal session');
      
      final sessionId = await _sessionHandler.createLocalSession();
      
      final enhancedSession = EnhancedTerminalSession(
        id: sessionId,
        sessionType: TerminalSessionType.local,
        createdAt: DateTime.now(),
      );
      
      _sessions[sessionId] = enhancedSession;
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.created,
        sessionId: sessionId,
        message: 'Enhanced local terminal session created',
        timestamp: DateTime.now(),
      ));
      
      return sessionId;
      
    } catch (e) {
      debugPrint('Failed to create enhanced local terminal session: $e');
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.error,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
      
      rethrow;
    }
  }

  /// Execute command with enhanced block management
  Future<String> executeCommand(String sessionId, String command, {bool isAgentMode = false}) async {
    try {
      final session = _sessions[sessionId];
      if (session == null) {
        throw Exception('Session not found: $sessionId');
      }

      // Create terminal block
      final blockId = _uuid.v4();
      final block = TerminalBlockData(
        id: blockId,
        command: command,
        status: TerminalBlockStatus.pending,
        timestamp: DateTime.now(),
        isInteractive: _isInteractiveCommand(command),
        index: session.blocks.length,
      );

      // Add block to session
      session.addBlock(block);

      // Update block status to running
      session.updateBlockStatus(blockId, TerminalBlockStatus.running);

      // Check if command requires fullscreen modal
      if (_isInteractiveCommand(command)) {
        _emitEvent(EnhancedSessionEvent(
          type: EnhancedSessionEventType.interactiveCommandDetected,
          sessionId: sessionId,
          blockId: blockId,
          command: command,
          timestamp: DateTime.now(),
        ));
      }

      // Send command to underlying session
      await _sessionHandler.sendCommand(sessionId, command);
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.commandExecuted,
        sessionId: sessionId,
        blockId: blockId,
        command: command,
        isAgentMode: isAgentMode,
        timestamp: DateTime.now(),
      ));
      
      return blockId;
      
    } catch (e) {
      debugPrint('Failed to execute command in session $sessionId: $e');
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.error,
        sessionId: sessionId,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
      
      rethrow;
    }
  }

  /// Update terminal block output
  void updateBlockOutput(String sessionId, String blockId, String output, {bool append = true}) {
    final session = _sessions[sessionId];
    if (session == null) return;

    session.updateBlockOutput(blockId, output, append: append);
    
    _emitEvent(EnhancedSessionEvent(
      type: EnhancedSessionEventType.blockOutputUpdated,
      sessionId: sessionId,
      blockId: blockId,
      timestamp: DateTime.now(),
    ));
  }

  /// Complete terminal block execution
  void completeBlock(String sessionId, String blockId, {bool success = true}) {
    final session = _sessions[sessionId];
    if (session == null) return;

    final status = success ? TerminalBlockStatus.completed : TerminalBlockStatus.failed;
    session.updateBlockStatus(blockId, status);
    
    _emitEvent(EnhancedSessionEvent(
      type: EnhancedSessionEventType.blockCompleted,
      sessionId: sessionId,
      blockId: blockId,
      success: success,
      timestamp: DateTime.now(),
    ));
  }

  /// Cancel running block
  void cancelBlock(String sessionId, String blockId) {
    final session = _sessions[sessionId];
    if (session == null) return;

    session.updateBlockStatus(blockId, TerminalBlockStatus.cancelled);
    
    _emitEvent(EnhancedSessionEvent(
      type: EnhancedSessionEventType.blockCancelled,
      sessionId: sessionId,
      blockId: blockId,
      timestamp: DateTime.now(),
    ));
  }

  /// Get enhanced session
  EnhancedTerminalSession? getEnhancedSession(String sessionId) {
    return _sessions[sessionId];
  }

  /// Get all enhanced sessions
  List<EnhancedTerminalSession> getAllEnhancedSessions() {
    return _sessions.values.toList();
  }

  /// Stop enhanced session
  Future<void> stopEnhancedSession(String sessionId) async {
    try {
      debugPrint('Stopping enhanced terminal session: $sessionId');
      
      await _sessionHandler.stopSession(sessionId);
      final session = _sessions.remove(sessionId);
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.stopped,
        sessionId: sessionId,
        profileId: session?.profileId,
        message: 'Enhanced terminal session stopped',
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Failed to stop enhanced terminal session: $e');
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.error,
        sessionId: sessionId,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Check if command requires interactive modal
  bool _isInteractiveCommand(String command) {
    final interactiveCommands = [
      'vi', 'vim', 'nano', 'emacs',
      'top', 'htop', 'btop',
      'watch', 'tail -f', 'less', 'more',
      'man', 'tmux', 'screen',
      'git log', 'git diff',
    ];
    
    final cmd = command.toLowerCase().trim();
    return interactiveCommands.any((interactive) => 
        cmd.startsWith(interactive) || cmd.contains(' $interactive '));
  }

  /// Get session statistics
  Map<String, dynamic> getEnhancedSessionStats() {
    final sessions = _sessions.values.toList();
    final sshSessions = sessions.where((s) => s.sessionType == TerminalSessionType.ssh).length;
    final localSessions = sessions.where((s) => s.sessionType == TerminalSessionType.local).length;
    
    final totalBlocks = sessions.fold<int>(0, (sum, session) => sum + session.blocks.length);
    final runningBlocks = sessions.fold<int>(0, (sum, session) => 
        sum + session.blocks.where((b) => b.status == TerminalBlockStatus.running).length);
    
    return {
      'totalSessions': sessions.length,
      'sshSessions': sshSessions,
      'localSessions': localSessions,
      'totalBlocks': totalBlocks,
      'runningBlocks': runningBlocks,
      'lastActivity': DateTime.now().toIso8601String(),
    };
  }

  /// Cleanup all enhanced sessions
  Future<void> cleanupEnhanced() async {
    debugPrint('Cleaning up all enhanced terminal sessions');
    
    try {
      await _sessionHandler.stopAllSessions();
      await _connectionManager.disconnectAll();
      
      _sessions.clear();
      
      _emitEvent(EnhancedSessionEvent(
        type: EnhancedSessionEventType.cleanup,
        message: 'All enhanced sessions cleaned up',
        timestamp: DateTime.now(),
      ));
      
    } catch (e) {
      debugPrint('Error during enhanced cleanup: $e');
    }
  }

  /// Emit enhanced session event
  void _emitEvent(EnhancedSessionEvent event) {
    _eventController.add(event);
  }

  /// Dispose enhanced resources
  void dispose() {
    cleanupEnhanced();
    _eventController.close();
  }
}

/// Terminal session types
enum TerminalSessionType {
  local,
  ssh,
}

/// Enhanced terminal session model
class EnhancedTerminalSession {
  final String id;
  final String? profileId;
  final TerminalSessionType sessionType;
  final SshProfile? profile;
  final DateTime createdAt;
  final List<TerminalBlockData> blocks = [];
  
  DateTime? lastActivity;
  bool isInteractiveMode = false;
  String? currentInteractiveBlockId;

  EnhancedTerminalSession({
    required this.id,
    this.profileId,
    required this.sessionType,
    this.profile,
    required this.createdAt,
  });

  /// Add new terminal block
  void addBlock(TerminalBlockData block) {
    blocks.add(block);
    lastActivity = DateTime.now();
  }

  /// Update block status
  void updateBlockStatus(String blockId, TerminalBlockStatus status) {
    final blockIndex = blocks.indexWhere((b) => b.id == blockId);
    if (blockIndex >= 0) {
      blocks[blockIndex] = blocks[blockIndex].copyWith(status: status);
      lastActivity = DateTime.now();
      
      if (status == TerminalBlockStatus.interactive) {
        isInteractiveMode = true;
        currentInteractiveBlockId = blockId;
      } else if (currentInteractiveBlockId == blockId && 
                 (status == TerminalBlockStatus.completed || 
                  status == TerminalBlockStatus.failed || 
                  status == TerminalBlockStatus.cancelled)) {
        isInteractiveMode = false;
        currentInteractiveBlockId = null;
      }
    }
  }

  /// Update block output
  void updateBlockOutput(String blockId, String output, {bool append = true}) {
    final blockIndex = blocks.indexWhere((b) => b.id == blockId);
    if (blockIndex >= 0) {
      final currentOutput = blocks[blockIndex].output;
      final newOutput = append ? currentOutput + output : output;
      blocks[blockIndex] = blocks[blockIndex].copyWith(output: newOutput);
      lastActivity = DateTime.now();
    }
  }

  /// Get block by ID
  TerminalBlockData? getBlock(String blockId) {
    try {
      return blocks.firstWhere((b) => b.id == blockId);
    } catch (e) {
      return null;
    }
  }

  /// Get running blocks
  List<TerminalBlockData> getRunningBlocks() {
    return blocks.where((b) => b.status == TerminalBlockStatus.running).toList();
  }

  /// Check if session has running blocks
  bool get hasRunningBlocks => getRunningBlocks().isNotEmpty;

  /// Session info
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profileId': profileId,
      'sessionType': sessionType.name,
      'createdAt': createdAt.toIso8601String(),
      'lastActivity': lastActivity?.toIso8601String(),
      'blocksCount': blocks.length,
      'isInteractiveMode': isInteractiveMode,
      'currentInteractiveBlockId': currentInteractiveBlockId,
      'hasRunningBlocks': hasRunningBlocks,
    };
  }
}

/// Enhanced session event types
enum EnhancedSessionEventType {
  created,
  stopped,
  error,
  commandExecuted,
  blockOutputUpdated,
  blockCompleted,
  blockCancelled,
  interactiveCommandDetected,
  cleanup,
}

/// Enhanced session event model
class EnhancedSessionEvent {
  final EnhancedSessionEventType type;
  final String? sessionId;
  final String? profileId;
  final String? blockId;
  final String? command;
  final String? message;
  final String? error;
  final bool? success;
  final bool? isAgentMode;
  final DateTime timestamp;

  const EnhancedSessionEvent({
    required this.type,
    this.sessionId,
    this.profileId,
    this.blockId,
    this.command,
    this.message,
    this.error,
    this.success,
    this.isAgentMode,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'EnhancedSessionEvent{type: $type, sessionId: $sessionId, blockId: $blockId, message: $message}';
  }
}