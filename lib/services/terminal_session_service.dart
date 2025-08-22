import 'package:flutter/foundation.dart';

import '../models/ssh_profile_models.dart';
import 'api_client.dart';

/// Terminal session management service
class TerminalSessionService {
  static TerminalSessionService? _instance;
  static TerminalSessionService get instance => _instance ??= TerminalSessionService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  
  TerminalSessionService._();
  
  /// Get all active terminal sessions
  Future<List<TerminalSession>> getSessions() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/terminal/sessions',
      );
      
      if (response.isSuccess && response.data != null) {
        return response.data!
            .map((json) => TerminalSession.fromJson(json))
            .toList();
      }
      
      debugPrint('Get terminal sessions failed: ${response.errorMessage}');
      return [];
    } catch (e) {
      debugPrint('Error getting terminal sessions: $e');
      return [];
    }
  }
  
  /// Create a new terminal session
  Future<TerminalSession?> createSession(CreateTerminalSessionRequest request) async {
    try {
      final response = await _apiClient.post<TerminalSession>(
        '/terminal/sessions',
        data: request.toJson(),
        fromJson: (json) => TerminalSession.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Create terminal session failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error creating terminal session: $e');
      return null;
    }
  }
  
  /// Create a local terminal session
  Future<TerminalSession?> createLocalSession({String shell = '/bin/bash'}) async {
    final request = CreateTerminalSessionRequest.local(shell: shell);
    return createSession(request);
  }
  
  /// Create an SSH terminal session
  Future<TerminalSession?> createSshSession(String sshProfileId) async {
    final request = CreateTerminalSessionRequest.ssh(sshProfileId: sshProfileId);
    return createSession(request);
  }
  
  /// Terminate a terminal session
  Future<bool> terminateSession(String sessionId) async {
    try {
      final response = await _apiClient.delete('/terminal/sessions/$sessionId');
      
      if (response.isSuccess) {
        return true;
      }
      
      debugPrint('Terminate terminal session failed: ${response.errorMessage}');
      return false;
    } catch (e) {
      debugPrint('Error terminating terminal session: $e');
      return false;
    }
  }
  
  /// Get command history for a terminal session
  Future<List<String>> getSessionHistory(String sessionId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/terminal/sessions/$sessionId/history',
      );
      
      if (response.isSuccess && response.data != null) {
        return response.data!.cast<String>();
      }
      
      debugPrint('Get session history failed: ${response.errorMessage}');
      return [];
    } catch (e) {
      debugPrint('Error getting session history: $e');
      return [];
    }
  }
  
  /// Get terminal usage statistics
  Future<TerminalStats?> getTerminalStats() async {
    try {
      final response = await _apiClient.get<TerminalStats>(
        '/terminal/stats',
        fromJson: (json) => TerminalStats.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Get terminal stats failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error getting terminal stats: $e');
      return null;
    }
  }
}