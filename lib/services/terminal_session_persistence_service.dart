import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';

import '../models/ssh_profile_models.dart';
import '../widgets/terminal/terminal_block.dart';
import 'enhanced_terminal_session_manager.dart';
import 'secure_storage_service.dart';
import 'ssh_connection_manager.dart';

/// Terminal session persistence service for managing session state across app lifecycle
class TerminalSessionPersistenceService with WidgetsBindingObserver {
  static TerminalSessionPersistenceService? _instance;
  static TerminalSessionPersistenceService get instance => _instance ??= TerminalSessionPersistenceService._();

  TerminalSessionPersistenceService._();

  final SecureStorageService _secureStorage = SecureStorageService.instance;
  final EnhancedTerminalSessionManager _sessionManager = EnhancedTerminalSessionManager.instance;
  final SshConnectionManager _connectionManager = SshConnectionManager.instance;

  static const String _sessionStateKey = 'terminal_session_state';
  static const String _connectionStateKey = 'ssh_connection_state';
  static const String _blocksStateKey = 'terminal_blocks_state';
  static const Duration _persistenceInterval = Duration(seconds: 30);

  Timer? _persistenceTimer;
  bool _isInitialized = false;
  bool _isRestoringSession = false;
  DateTime? _lastPersistenceTime;

  /// Initialize the persistence service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('Initializing terminal session persistence service');
      
      // Register as lifecycle observer
      WidgetsBinding.instance.addObserver(this);
      
      // Start periodic persistence
      _startPeriodicPersistence();
      
      _isInitialized = true;
      debugPrint('Terminal session persistence service initialized');
      
    } catch (e) {
      debugPrint('Failed to initialize terminal session persistence service: $e');
      rethrow;
    }
  }

  /// Start periodic persistence of session state
  void _startPeriodicPersistence() {
    _persistenceTimer?.cancel();
    _persistenceTimer = Timer.periodic(_persistenceInterval, (_) {
      if (!_isRestoringSession) {
        _persistActiveSessions();
      }
    });
  }

  /// Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        _handleAppPaused();
        break;
      case AppLifecycleState.resumed:
        _handleAppResumed();
        break;
      case AppLifecycleState.detached:
        _handleAppDetached();
        break;
      case AppLifecycleState.inactive:
        // Handle inactive state if needed
        break;
      case AppLifecycleState.hidden:
        // Handle hidden state if needed
        break;
    }
  }

  /// Handle app being paused (backgrounded)
  void _handleAppPaused() {
    debugPrint('App paused - persisting terminal session state');
    try {
      _persistActiveSessions();
      _persistConnectionStates();
    } catch (e) {
      debugPrint('Failed to persist session state on app pause: $e');
    }
  }

  /// Handle app being resumed (foregrounded)
  void _handleAppResumed() {
    debugPrint('App resumed - checking for session restoration');
    try {
      _attemptSessionRestoration();
    } catch (e) {
      debugPrint('Failed to restore session state on app resume: $e');
    }
  }

  /// Handle app being detached (terminated)
  void _handleAppDetached() {
    debugPrint('App detached - final persistence cleanup');
    try {
      _persistActiveSessions();
      _persistConnectionStates();
      _cleanup();
    } catch (e) {
      debugPrint('Failed to cleanup on app detach: $e');
    }
  }

  /// Persist active terminal sessions
  Future<void> _persistActiveSessions() async {
    try {
      final sessions = _sessionManager.getAllEnhancedSessions();
      final sessionData = <String, dynamic>{};
      
      for (final session in sessions) {
        sessionData[session.id] = _serializeSession(session);
      }
      
      if (sessionData.isNotEmpty) {
        await _secureStorage.write(key: _sessionStateKey, value: jsonEncode(sessionData));
        _lastPersistenceTime = DateTime.now();
        debugPrint('Persisted ${sessions.length} terminal sessions');
      }
      
    } catch (e) {
      debugPrint('Failed to persist active sessions: $e');
    }
  }

  /// Persist SSH connection states
  Future<void> _persistConnectionStates() async {
    try {
      final connectionStates = <String, dynamic>{};
      
      // Get all active SSH sessions and their connection info
      final sessions = _sessionManager.getAllEnhancedSessions()
          .where((s) => s.sessionType == TerminalSessionType.ssh && s.profile != null);
      
      for (final session in sessions) {
        if (session.profile != null) {
          connectionStates[session.id] = {
            'profile': session.profile!.toJson(),
            'sessionId': session.id,
            'createdAt': session.createdAt.toIso8601String(),
            'lastActivity': session.lastActivity?.toIso8601String(),
          };
        }
      }
      
      if (connectionStates.isNotEmpty) {
        await _secureStorage.write(key: _connectionStateKey, value: jsonEncode(connectionStates));
        debugPrint('Persisted ${connectionStates.length} SSH connection states');
      }
      
    } catch (e) {
      debugPrint('Failed to persist connection states: $e');
    }
  }

  /// Serialize terminal session for persistence
  Map<String, dynamic> _serializeSession(EnhancedTerminalSession session) {
    return {
      'id': session.id,
      'profileId': session.profileId,
      'sessionType': session.sessionType.name,
      'createdAt': session.createdAt.toIso8601String(),
      'lastActivity': session.lastActivity?.toIso8601String(),
      'isInteractiveMode': session.isInteractiveMode,
      'currentInteractiveBlockId': session.currentInteractiveBlockId,
      'blocks': session.blocks.map((block) => _serializeTerminalBlock(block)).toList(),
      'profile': session.profile?.toJson(),
    };
  }

  /// Serialize terminal block for persistence
  Map<String, dynamic> _serializeTerminalBlock(TerminalBlockData block) {
    return {
      'id': block.id,
      'command': block.command,
      'output': block.output,
      'status': block.status.name,
      'timestamp': block.timestamp.toIso8601String(),
      'exitCode': block.exitCode,
      'isInteractive': block.isInteractive,
      'index': block.index,
      'duration': block.duration?.inMilliseconds,
      'errorMessage': block.errorMessage,
    };
  }

  /// Attempt to restore terminal sessions
  Future<void> _attemptSessionRestoration() async {
    if (_isRestoringSession) return;
    
    _isRestoringSession = true;
    
    try {
      debugPrint('Attempting terminal session restoration');
      
      // Check if we have persisted session data
      final sessionDataJson = await _secureStorage.read(_sessionStateKey);
      final connectionDataJson = await _secureStorage.read(_connectionStateKey);
      
      if (sessionDataJson != null) {
        await _restoreTerminalSessions(sessionDataJson);
      }
      
      if (connectionDataJson != null) {
        await _restoreConnectionStates(connectionDataJson);
      }
      
      // Clear persisted data after successful restoration
      await _clearPersistedData();
      
    } catch (e) {
      debugPrint('Session restoration failed: $e');
    } finally {
      _isRestoringSession = false;
    }
  }

  /// Restore terminal sessions from persisted data
  Future<void> _restoreTerminalSessions(String sessionDataJson) async {
    try {
      final sessionData = jsonDecode(sessionDataJson) as Map<String, dynamic>;
      
      for (final entry in sessionData.entries) {
        final sessionId = entry.key;
        final sessionInfo = entry.value as Map<String, dynamic>;
        
        await _restoreIndividualSession(sessionId, sessionInfo);
      }
      
      debugPrint('Restored ${sessionData.length} terminal sessions');
      
    } catch (e) {
      debugPrint('Failed to restore terminal sessions: $e');
    }
  }

  /// Restore individual terminal session
  Future<void> _restoreIndividualSession(String sessionId, Map<String, dynamic> sessionInfo) async {
    try {
      final sessionType = TerminalSessionType.values
          .firstWhere((type) => type.name == sessionInfo['sessionType']);
      
      // Create session based on type
      if (sessionType == TerminalSessionType.ssh && sessionInfo['profile'] != null) {
        final profile = SshProfile.fromJson(sessionInfo['profile'] as Map<String, dynamic>);
        await _restoreSshSession(sessionId, profile, sessionInfo);
      } else if (sessionType == TerminalSessionType.local) {
        await _restoreLocalSession(sessionId, sessionInfo);
      }
      
    } catch (e) {
      debugPrint('Failed to restore session $sessionId: $e');
    }
  }

  /// Restore SSH session
  Future<void> _restoreSshSession(String sessionId, SshProfile profile, Map<String, dynamic> sessionInfo) async {
    try {
      // Note: We don't automatically reconnect SSH sessions on restore
      // Instead, we restore the session structure and let user reconnect manually
      debugPrint('SSH session restoration prepared for profile: ${profile.name}');
      
      // Could implement auto-reconnect here if desired:
      // final newSessionId = await _sessionManager.createEnhancedSshSession(profile);
      // await _restoreTerminalBlocks(newSessionId, sessionInfo['blocks']);
      
    } catch (e) {
      debugPrint('Failed to restore SSH session: $e');
    }
  }

  /// Restore local session
  Future<void> _restoreLocalSession(String sessionId, Map<String, dynamic> sessionInfo) async {
    try {
      final newSessionId = await _sessionManager.createEnhancedLocalSession();
      
      // Restore terminal blocks
      if (sessionInfo['blocks'] != null) {
        await _restoreTerminalBlocks(newSessionId, sessionInfo['blocks'] as List);
      }
      
      debugPrint('Restored local terminal session: $newSessionId');
      
    } catch (e) {
      debugPrint('Failed to restore local session: $e');
    }
  }

  /// Restore terminal blocks for a session
  Future<void> _restoreTerminalBlocks(String sessionId, List<dynamic> blocksData) async {
    try {
      final session = _sessionManager.getEnhancedSession(sessionId);
      if (session == null) return;
      
      for (final blockData in blocksData) {
        final block = _deserializeTerminalBlock(blockData as Map<String, dynamic>);
        session.addBlock(block);
      }
      
      debugPrint('Restored ${blocksData.length} terminal blocks for session $sessionId');
      
    } catch (e) {
      debugPrint('Failed to restore terminal blocks: $e');
    }
  }

  /// Deserialize terminal block from persistence data
  TerminalBlockData _deserializeTerminalBlock(Map<String, dynamic> data) {
    final status = TerminalBlockStatus.values
        .firstWhere((s) => s.name == data['status'], orElse: () => TerminalBlockStatus.completed);
    
    return TerminalBlockData(
      id: data['id'] as String,
      command: data['command'] as String,
      output: data['output'] as String? ?? '',
      status: status,
      timestamp: DateTime.parse(data['timestamp'] as String),
      exitCode: data['exitCode'] as int?,
      isInteractive: data['isInteractive'] as bool? ?? false,
      index: data['index'] as int? ?? 0,
      duration: data['duration'] != null ? Duration(milliseconds: data['duration'] as int) : null,
      errorMessage: data['errorMessage'] as String?,
    );
  }

  /// Restore SSH connection states
  Future<void> _restoreConnectionStates(String connectionDataJson) async {
    try {
      final connectionData = jsonDecode(connectionDataJson) as Map<String, dynamic>;
      
      // For now, we just log the available connections for manual restoration
      // Auto-reconnect could be implemented based on user preferences
      
      for (final entry in connectionData.entries) {
        final sessionId = entry.key;
        final connectionInfo = entry.value as Map<String, dynamic>;
        final profileData = connectionInfo['profile'] as Map<String, dynamic>;
        final profile = SshProfile.fromJson(profileData);
        
        debugPrint('SSH connection available for restoration: ${profile.name} (session: $sessionId)');
      }
      
    } catch (e) {
      debugPrint('Failed to restore connection states: $e');
    }
  }

  /// Clear persisted data after successful restoration
  Future<void> _clearPersistedData() async {
    try {
      await _secureStorage.delete(_sessionStateKey);
      await _secureStorage.delete(_connectionStateKey);
      await _secureStorage.delete(_blocksStateKey);
      debugPrint('Cleared persisted session data');
    } catch (e) {
      debugPrint('Failed to clear persisted data: $e');
    }
  }

  /// Manually persist specific session
  Future<void> persistSession(String sessionId) async {
    try {
      final session = _sessionManager.getEnhancedSession(sessionId);
      if (session == null) return;
      
      final sessionData = {sessionId: _serializeSession(session)};
      await _secureStorage.write(key: '${_sessionStateKey}_$sessionId', value: jsonEncode(sessionData));
      
      debugPrint('Manually persisted session: $sessionId');
      
    } catch (e) {
      debugPrint('Failed to manually persist session $sessionId: $e');
    }
  }

  /// Manually restore specific session
  Future<bool> restoreSession(String sessionId) async {
    try {
      final sessionDataJson = await _secureStorage.read('${_sessionStateKey}_$sessionId');
      if (sessionDataJson == null) return false;
      
      final sessionData = jsonDecode(sessionDataJson) as Map<String, dynamic>;
      final sessionInfo = sessionData[sessionId] as Map<String, dynamic>;
      
      await _restoreIndividualSession(sessionId, sessionInfo);
      await _secureStorage.delete('${_sessionStateKey}_$sessionId');
      
      debugPrint('Manually restored session: $sessionId');
      return true;
      
    } catch (e) {
      debugPrint('Failed to manually restore session $sessionId: $e');
      return false;
    }
  }

  /// Check if session persistence data exists
  Future<bool> hasPersistedSessions() async {
    try {
      final sessionData = await _secureStorage.read(_sessionStateKey);
      return sessionData != null;
    } catch (e) {
      debugPrint('Failed to check for persisted sessions: $e');
      return false;
    }
  }

  /// Get persistence statistics
  Map<String, dynamic> getPersistenceStats() {
    return {
      'isInitialized': _isInitialized,
      'isRestoringSession': _isRestoringSession,
      'lastPersistenceTime': _lastPersistenceTime?.toIso8601String(),
      'persistenceInterval': _persistenceInterval.inSeconds,
    };
  }

  /// Cleanup persistence service
  void _cleanup() {
    _persistenceTimer?.cancel();
    _persistenceTimer = null;
  }

  /// Dispose persistence service
  void dispose() {
    debugPrint('Disposing terminal session persistence service');
    
    _cleanup();
    WidgetsBinding.instance.removeObserver(this);
    
    _isInitialized = false;
    _instance = null;
  }
}

/// Extension to add persistence capabilities to terminal sessions
extension TerminalSessionPersistence on EnhancedTerminalSession {
  /// Check if session can be persisted
  bool get canBePersisted {
    // Don't persist sessions that are too old or have no activity
    final now = DateTime.now();
    final timeSinceCreation = now.difference(createdAt);
    final timeSinceActivity = lastActivity != null ? now.difference(lastActivity!) : timeSinceCreation;
    
    // Don't persist sessions older than 24 hours or inactive for more than 2 hours
    return timeSinceCreation < const Duration(hours: 24) &&
           timeSinceActivity < const Duration(hours: 2);
  }
  
  /// Get session size for persistence optimization
  int get persistenceSize {
    int totalSize = 0;
    
    // Calculate approximate size of session data
    totalSize += id.length * 2; // Unicode characters
    totalSize += (profileId?.length ?? 0) * 2;
    
    for (final block in blocks) {
      totalSize += block.command.length * 2;
      totalSize += block.output.length * 2;
      totalSize += 100; // Metadata overhead
    }
    
    return totalSize;
  }
}