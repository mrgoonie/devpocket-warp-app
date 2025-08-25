import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:collection';

import '../models/ssh_profile_models.dart';

/// SSH connection testing service using dartssh2
class SshConnectionTestService {
  static SshConnectionTestService? _instance;
  static SshConnectionTestService get instance => _instance ??= SshConnectionTestService._();
  
  SshConnectionTestService._();
  
  /// Test SSH connection to a profile
  Future<SshConnectionTestResult> testConnection(SshProfile profile) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      debugPrint('Testing SSH connection to ${profile.host}:${profile.port}');
      
      // Create SSH client with appropriate authentication
      final client = await _createSshClient(profile);
      
      // Wait for authentication to complete
      await client.authenticated;
      
      // Test command execution
      final result = await client.run('echo "connection_test_successful"');
      final output = utf8.decode(result);
      
      client.close();
      stopwatch.stop();
      
      final success = output.trim().contains('connection_test_successful');
      
      debugPrint('SSH connection test ${success ? 'successful' : 'failed'} in ${stopwatch.elapsedMilliseconds}ms');
      
      return SshConnectionTestResult(
        success: success,
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
        message: success ? 'Connection successful' : 'Command execution failed',
      );
      
    } on SocketException catch (e) {
      stopwatch.stop();
      debugPrint('SSH connection socket error: $e');
      
      return SshConnectionTestResult(
        success: false,
        error: 'Network error: ${e.message}',
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
      
    } on Exception catch (e) {
      stopwatch.stop();
      debugPrint('SSH connection error: $e');
      
      return SshConnectionTestResult(
        success: false,
        error: 'Connection failed: $e',
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
      
      
    } catch (e) {
      stopwatch.stop();
      debugPrint('SSH connection error: $e');
      
      return SshConnectionTestResult(
        success: false,
        error: 'Connection failed: $e',
        responseTime: stopwatch.elapsed,
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// Test connection with timeout
  Future<SshConnectionTestResult> testConnectionWithTimeout(
    SshProfile profile, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      return await testConnection(profile).timeout(timeout);
    } on TimeoutException {
      return SshConnectionTestResult(
        success: false,
        error: 'Connection test timed out after ${timeout.inSeconds} seconds',
        responseTime: timeout,
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// Create SSH client with appropriate authentication
  Future<SSHClient> _createSshClient(SshProfile profile) async {
    final socket = await SSHSocket.connect(profile.host, profile.port);
    
    // Determine authentication method
    switch (profile.authType) {
      case SshAuthType.password:
        return SSHClient(
          socket,
          username: profile.username,
          onPasswordRequest: () => profile.password ?? '',
        );
        
      case SshAuthType.key:
        final keyPair = await _getPublicKeyAuth(profile);
        if (keyPair != null) {
          return SSHClient(
            socket,
            username: profile.username,
            identities: [keyPair],
          );
        } else {
          // Fallback to password if key parsing fails
          return SSHClient(
            socket,
            username: profile.username,
            onPasswordRequest: () => profile.password ?? '',
          );
        }
    }
  }

  /// Get public key authentication for SSH
  Future<SSHKeyPair?> _getPublicKeyAuth(SshProfile profile) async {
    if (profile.privateKey == null) return null;
    
    try {
      // Parse private key based on auth type
      if (profile.authType == SshAuthType.key) {
        
        final privateKey = profile.privateKey!;
        final passphrase = profile.passphrase;
        
        // Try to parse the private key using the unified fromPem method
        final keyPairs = SSHKeyPair.fromPem(privateKey, passphrase ?? '');
        if (keyPairs.isNotEmpty) {
          return keyPairs.first;
        }
        
        debugPrint('Unsupported private key format');
        return null;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error parsing private key: $e');
      return null;
    }
  }
  
  /// Validate SSH host format and reachability
  Future<HostValidationResult> validateHost(String hostname, int port) async {
    try {
      // Basic hostname validation
      if (hostname.isEmpty) {
        return const HostValidationResult(
          isValid: false,
          error: 'Hostname cannot be empty',
        );
      }
      
      // Port validation
      if (port < 1 || port > 65535) {
        return const HostValidationResult(
          isValid: false,
          error: 'Port must be between 1 and 65535',
        );
      }
      
      // Test network connectivity
      final socket = Socket.connect(hostname, port);
      final connection = await socket.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Connection timeout', const Duration(seconds: 5)),
      );
      
      await connection.close();
      
      return HostValidationResult(
        isValid: true,
        message: 'Host is reachable',
        responseTime: DateTime.now().millisecondsSinceEpoch,
      );
      
    } on SocketException catch (e) {
      return HostValidationResult(
        isValid: false,
        error: 'Host unreachable: ${e.message}',
      );
    } on TimeoutException {
      return const HostValidationResult(
        isValid: false,
        error: 'Connection timeout - host may be unreachable',
      );
    } catch (e) {
      return HostValidationResult(
        isValid: false,
        error: 'Validation error: $e',
      );
    }
  }
  
  /// Batch test multiple hosts
  Future<Map<String, SshConnectionTestResult>> testMultipleHosts(
    List<SshProfile> profiles,
  ) async {
    final results = <String, SshConnectionTestResult>{};
    
    // Test connections concurrently with limit
    const maxConcurrent = 3;
    final semaphore = Semaphore(maxConcurrent);
    
    final futures = profiles.map((profile) async {
      await semaphore.acquire();
      try {
        final result = await testConnectionWithTimeout(profile);
        results[profile.id] = result;
      } finally {
        semaphore.release();
      }
    });
    
    await Future.wait(futures);
    return results;
  }
}

/// Host validation result
class HostValidationResult {
  final bool isValid;
  final String? error;
  final String? message;
  final int? responseTime;
  
  const HostValidationResult({
    required this.isValid,
    this.error,
    this.message,
    this.responseTime,
  });
}

/// Simple semaphore implementation for limiting concurrent operations
class Semaphore {
  int _count;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();
  
  Semaphore(this._count);
  
  Future<void> acquire() async {
    if (_count > 0) {
      _count--;
      return;
    }
    
    final completer = Completer<void>();
    _waitQueue.addLast(completer);
    return completer.future;
  }
  
  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _count++;
    }
  }
}