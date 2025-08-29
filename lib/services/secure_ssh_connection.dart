import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

import '../models/enhanced_ssh_models.dart';
import 'crypto_service.dart' as local_crypto;
import 'secure_storage_service.dart';
import 'command_validator.dart';
import 'audit_service.dart';
import 'ssh_service_models.dart';

/// Secure SSH connection wrapper with command validation and auditing
class SecureSSHConnection {
  final String id;
  final SecureHost host;
  final SSHClient client;
  final SecureHost? jumpHost;
  final SecureSSHConnection? jumpConnection;
  final bool validateCommands;
  final ValidationLevel commandValidationLevel;
  final AuditService _auditService;
  
  final DateTime connectedAt = DateTime.now();
  int commandCount = 0;
  
  SecureSSHConnection({
    required this.id,
    required this.host,
    required this.client,
    this.jumpHost,
    this.jumpConnection,
    this.validateCommands = true,
    this.commandValidationLevel = ValidationLevel.strict,
    required SecureStorageService secureStorage,
    required local_crypto.CryptoService cryptoService,
    required AuditService auditService,
  }) : _auditService = auditService;

  /// Execute command with validation and auditing
  Future<SSHCommandResult> executeCommand(
    String command, {
    bool pty = false,
    Map<String, String>? environment,
  }) async {
    final startTime = DateTime.now();
    
    // Validate command if enabled
    if (validateCommands) {
      final validation = CommandValidator.validateCommand(
        command,
        level: commandValidationLevel,
        allowFileOperations: host.securityLevel != SecurityLevel.critical,
        allowNetworkOperations: true,
        allowSystemCommands: host.securityLevel == SecurityLevel.low,
      );
      
      if (!validation.isAllowed) {
        final error = 'Command blocked by security policy: ${validation.message}';
        
        await _auditService.logCommandExecution(
          hostId: host.id,
          command: command,
          success: false,
          error: error,
          validationResult: validation,
        );
        
        throw SSHSecurityException(error);
      }
      
      if (validation.isWarning) {
        await _auditService.logSecurityWarning(
          hostId: host.id,
          command: command,
          warning: validation.message,
        );
      }
    }
    
    try {
      final session = await client.execute(
        command,
        environment: environment,
      );
      
      final stdout = await utf8.decoder.bind(session.stdout).join();
      final stderr = await utf8.decoder.bind(session.stderr).join();
      final exitCode = session.exitCode;
      
      commandCount++;
      
      final result = SSHCommandResult(
        command: command,
        stdout: stdout,
        stderr: stderr,
        exitCode: exitCode,
        duration: DateTime.now().difference(startTime),
        timestamp: startTime,
      );
      
      // Log successful command execution
      await _auditService.logCommandExecution(
        hostId: host.id,
        command: command,
        success: exitCode == 0,
        stdout: stdout,
        stderr: stderr,
        exitCode: exitCode,
        duration: result.duration,
      );
      
      return result;
    } catch (e) {
      // Log failed command execution
      await _auditService.logCommandExecution(
        hostId: host.id,
        command: command,
        success: false,
        error: e.toString(),
      );
      
      rethrow;
    }
  }

  /// Execute interactive shell command
  Stream<String> executeInteractive(String command) async* {
    if (validateCommands) {
      final validation = CommandValidator.validateCommand(
        command,
        level: commandValidationLevel,
      );
      
      if (!validation.isAllowed) {
        throw SSHSecurityException('Command blocked: ${validation.message}');
      }
    }
    
    final session = await client.shell();
    session.stdin.add(utf8.encode('$command\n'));
    
    await for (final chunk in utf8.decoder.bind(session.stdout)) {
      yield chunk;
    }
  }

  /// Upload file with security checks
  Future<void> uploadFile({
    required String localPath,
    required String remotePath,
    int? mode,
    bool createDirectories = false,
  }) async {
    // Security check for critical hosts
    if (host.securityLevel == SecurityLevel.critical) {
      throw const SSHSecurityException('File upload not allowed for critical security level');
    }
    
    final file = File(localPath);
    if (!file.existsSync()) {
      throw SSHException('Local file does not exist: $localPath');
    }
    
    // Validate file path
    if (_isRestrictedPath(remotePath)) {
      throw SSHSecurityException('Upload to restricted path blocked: $remotePath');
    }
    
    try {
      final sftp = await client.sftp();
      final remoteFile = await sftp.open(
        remotePath,
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );
      
      await remoteFile.write(file.openRead().cast<Uint8List>());
      await remoteFile.close();
      
      if (mode != null) {
        await sftp.setStat(remotePath, SftpFileAttrs(mode: SftpFileMode(userRead: true, userWrite: true)));
      }
      
      await _auditService.logFileTransfer(
        hostId: host.id,
        operation: 'upload',
        localPath: localPath,
        remotePath: remotePath,
        success: true,
      );
    } catch (e) {
      await _auditService.logFileTransfer(
        hostId: host.id,
        operation: 'upload',
        localPath: localPath,
        remotePath: remotePath,
        success: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Download file with security checks
  Future<void> downloadFile({
    required String remotePath,
    required String localPath,
  }) async {
    try {
      final sftp = await client.sftp();
      final remoteFile = await sftp.open(remotePath);
      
      final localFile = File(localPath);
      final sink = localFile.openWrite();
      
      await for (final chunk in remoteFile.read()) {
        sink.add(chunk);
      }
      
      await sink.close();
      await remoteFile.close();
      
      await _auditService.logFileTransfer(
        hostId: host.id,
        operation: 'download',
        localPath: localPath,
        remotePath: remotePath,
        success: true,
      );
    } catch (e) {
      await _auditService.logFileTransfer(
        hostId: host.id,
        operation: 'download',
        localPath: localPath,
        remotePath: remotePath,
        success: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  /// Check connection status
  bool get isConnected => !client.isClosed;

  /// Close connection
  Future<void> close() async {
    client.close();
    jumpConnection?.close();
  }

  bool _isRestrictedPath(String path) {
    const restrictedPaths = [
      '/etc/',
      '/sys/',
      '/proc/',
      '/boot/',
      '/dev/',
    ];
    
    return restrictedPaths.any((restricted) => 
        path.toLowerCase().startsWith(restricted));
  }
}