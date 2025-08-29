import 'dart:async';
import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/enhanced_ssh_models.dart';
import 'crypto_service.dart' as local_crypto;
import 'secure_storage_service.dart';
import 'command_validator.dart';
import 'audit_service.dart';
import 'ssh_service_models.dart';
import 'secure_ssh_connection.dart';

/// Comprehensive SSH service with production-grade security features
class SecureSSHService {
  final SecureStorageService _secureStorage;
  final local_crypto.CryptoService _cryptoService;
  // TODO: Implement global command validation using this validator
  // final CommandValidator _commandValidator;
  final AuditService _auditService;
  
  // Active connections
  final Map<String, SecureSSHConnection> _activeConnections = {};
  
  // Connection pool for jump hosts
  final Map<String, SSHClient> _jumpHostPool = {};
  
  // Security monitoring
  final StreamController<SecurityEvent> _securityEventsController = 
      StreamController<SecurityEvent>.broadcast();
  
  SecureSSHService({
    required SecureStorageService secureStorage,
    required local_crypto.CryptoService cryptoService,
    required CommandValidator commandValidator,
    required AuditService auditService,
  })  : _secureStorage = secureStorage,
        _cryptoService = cryptoService,
        // _commandValidator = commandValidator,
        _auditService = auditService;

  /// Stream of security events
  Stream<SecurityEvent> get securityEvents => _securityEventsController.stream;

  /// Connect to SSH host with comprehensive security checks
  Future<SecureSSHConnection> connect(
    SecureHost host, {
    String? passphrase,
    bool validateCommands = true,
    ValidationLevel commandValidationLevel = ValidationLevel.strict,
  }) async {
    final connectionId = _generateConnectionId(host);
    
    try {
      // Security pre-checks
      await _performSecurityChecks(host);
      
      // Create connection
      final connection = await _createConnection(
        host,
        passphrase: passphrase,
        validateCommands: validateCommands,
        commandValidationLevel: commandValidationLevel,
      );
      
      // Store active connection
      _activeConnections[connectionId] = connection;
      
      // Log successful connection
      await _auditService.logConnectionAttempt(
        host: host,
        success: true,
        authMethod: host.authMethod,
      );
      
      // Emit security event
      _securityEventsController.add(SecurityEvent.connectionEstablished(
        hostId: host.id,
        hostname: host.hostname,
        securityLevel: host.securityLevel,
      ));
      
      return connection;
    } catch (e) {
      // Log failed connection
      await _auditService.logConnectionAttempt(
        host: host,
        success: false,
        error: e.toString(),
        authMethod: host.authMethod,
      );
      
      // Emit security event
      _securityEventsController.add(SecurityEvent.connectionFailed(
        hostId: host.id,
        hostname: host.hostname,
        error: e.toString(),
      ));
      
      rethrow;
    }
  }

  /// Connect through jump host (bastion)
  Future<SecureSSHConnection> connectWithJumpHost(
    SecureHost target,
    SecureHost jumpHost, {
    String? targetPassphrase,
    String? jumpPassphrase,
    bool validateCommands = true,
    ValidationLevel commandValidationLevel = ValidationLevel.strict,
  }) async {
    try {
      // Security checks for both hosts
      await _performSecurityChecks(jumpHost);
      await _performSecurityChecks(target);
      
      // Connect to jump host first
      final jumpConnection = await _getOrCreateJumpHostConnection(
        jumpHost,
        passphrase: jumpPassphrase,
      );
      
      // Create tunneled connection to target
      final socket = await jumpConnection.client.forwardLocal(
        target.hostname,
        target.port,
      );
      
      // Create SSH client through tunnel
      List<SSHKeyPair> identities = [];
      if (target.privateKeyId != null) {
        final privateKey = await _getPrivateKey(target, targetPassphrase);
        identities = [SSHKeyPair.fromPem(privateKey)].expand((x) => x).toList();
      }
      
      final targetClient = SSHClient(
        socket,
        username: target.username,
        onPasswordRequest: target.passwordHash != null 
            ? () => _getPassword(target)
            : null,
        identities: identities,
      );
      
      // Authenticate with target
      await targetClient.authenticated;
      
      final connection = SecureSSHConnection(
        id: _generateConnectionId(target),
        host: target,
        client: targetClient,
        jumpHost: jumpHost,
        jumpConnection: jumpConnection,
        validateCommands: validateCommands,
        commandValidationLevel: commandValidationLevel,
        secureStorage: _secureStorage,
        cryptoService: _cryptoService,
        auditService: _auditService,
      );
      
      _activeConnections[connection.id] = connection;
      
      // Log successful connection
      await _auditService.logConnectionAttempt(
        host: target,
        success: true,
        authMethod: target.authMethod,
        jumpHost: jumpHost,
      );
      
      return connection;
    } catch (e) {
      await _auditService.logConnectionAttempt(
        host: target,
        success: false,
        error: e.toString(),
        authMethod: target.authMethod,
        jumpHost: jumpHost,
      );
      
      rethrow;
    }
  }

  /// Generate SSH key pair with secure defaults
  Future<SecureSSHKey> generateKeyPair({
    required String name,
    String keyType = 'ed25519',
    int? keySize,
    String? passphrase,
    String? comment,
    Duration? expirationDuration,
    SecurityLevel securityLevel = SecurityLevel.high,
    bool requiresBiometric = true,
  }) async {
    local_crypto.SSHKeyPair keyPair;
    
    switch (keyType.toLowerCase()) {
      case 'ed25519':
        keyPair = await _cryptoService.generateSSHKeyPairEd25519();
        break;
      case 'rsa':
        keyPair = await _cryptoService.generateSSHKeyPairRSA(
          keySize: keySize ?? 4096,
        );
        break;
      default:
        throw SSHException('Unsupported key type: $keyType');
    }
    
    // Calculate fingerprint
    final fingerprint = _cryptoService.calculateSSHFingerprint(keyPair.publicKey);
    if (fingerprint == null) {
      throw const SSHException('Failed to generate SSH key fingerprint');
    }
    
    // Store encrypted private key
    final keyId = const Uuid().v4();
    if (passphrase != null) {
      await _secureStorage.storeSSHKey(
        keyId: keyId,
        privateKey: keyPair.privateKey,
        passphrase: passphrase,
        requireBiometric: requiresBiometric,
      );
    }
    
    final sshKey = SecureSSHKeyFactory.create(
      name: name,
      type: keyType,
      publicKey: keyPair.publicKey,
      fingerprint: fingerprint,
      encryptedPrivateKeyData: passphrase != null ? keyId : null,
      passphraseHash: passphrase != null ? _hashPassphrase(passphrase) : null,
      keySize: keyPair.keySize,
      comment: comment,
      expirationDate: expirationDuration != null 
          ? DateTime.now().add(expirationDuration)
          : null,
      securityLevel: securityLevel,
      requiresBiometric: requiresBiometric,
    );
    
    // Log key generation
    await _auditService.logKeyGeneration(
      keyId: keyId,
      keyType: keyType,
      keySize: keyPair.keySize,
      securityLevel: securityLevel,
    );
    
    return sshKey;
  }

  /// Import existing SSH key with security validation
  Future<SecureSSHKey> importKey({
    required String name,
    required String privateKey,
    required String publicKey,
    String? passphrase,
    String? comment,
    SecurityLevel securityLevel = SecurityLevel.medium,
    bool requiresBiometric = true,
  }) async {
    // Validate key format and security
    _validateSSHKey(privateKey, publicKey);
    
    // Extract key type and size
    final keyInfo = _parseSSHKey(publicKey);
    final fingerprint = _cryptoService.calculateSSHFingerprint(publicKey);
    if (fingerprint == null) {
      throw const SSHException('Failed to calculate SSH key fingerprint for imported key');
    }
    
    // Store encrypted private key
    final keyId = const Uuid().v4();
    await _secureStorage.storeSSHKey(
      keyId: keyId,
      privateKey: privateKey,
      passphrase: passphrase ?? 'imported-key-${DateTime.now().millisecondsSinceEpoch}',
      requireBiometric: requiresBiometric,
    );
    
    final sshKey = SecureSSHKeyFactory.create(
      name: name,
      type: keyInfo['type'],
      publicKey: publicKey,
      fingerprint: fingerprint,
      encryptedPrivateKeyData: keyId,
      passphraseHash: passphrase != null ? _hashPassphrase(passphrase) : null,
      keySize: keyInfo['size'],
      comment: comment,
      securityLevel: securityLevel,
      requiresBiometric: requiresBiometric,
    );
    
    // Log key import
    await _auditService.logKeyImport(
      keyId: keyId,
      keyType: keyInfo['type'],
      keySize: keyInfo['size'],
      securityLevel: securityLevel,
    );
    
    return sshKey;
  }

  /// Get active connection by host ID
  SecureSSHConnection? getConnection(String hostId) {
    return _activeConnections.values
        .where((conn) => conn.host.id == hostId)
        .firstOrNull;
  }

  /// List all active connections
  List<SecureSSHConnection> getActiveConnections() {
    return _activeConnections.values.toList();
  }

  /// Disconnect specific connection
  Future<void> disconnect(String connectionId) async {
    final connection = _activeConnections[connectionId];
    if (connection != null) {
      await connection.close();
      _activeConnections.remove(connectionId);
      
      await _auditService.logDisconnection(
        hostId: connection.host.id,
        duration: DateTime.now().difference(connection.connectedAt),
        commandCount: connection.commandCount,
      );
      
      _securityEventsController.add(SecurityEvent.connectionClosed(
        hostId: connection.host.id,
        hostname: connection.host.hostname,
      ));
    }
  }

  /// Disconnect all connections
  Future<void> disconnectAll() async {
    final connections = List<SecureSSHConnection>.from(_activeConnections.values);
    
    for (final connection in connections) {
      await disconnect(connection.id);
    }
    
    // Clear jump host pool
    for (final jumpClient in _jumpHostPool.values) {
      jumpClient.close();
    }
    _jumpHostPool.clear();
  }

  /// Verify host key against known fingerprints
  Future<bool> verifyHostKey(SecureHost host, String actualFingerprint) async {
    if (host.knownHostKeyFingerprint == null) {
      // First connection to this host
      await _storeHostKey(host, actualFingerprint);
      return true;
    }
    
    return host.knownHostKeyFingerprint == actualFingerprint;
  }

  /// Update host key fingerprint
  Future<void> updateHostKey(SecureHost host, String newFingerprint) async {
    await _storeHostKey(host, newFingerprint);
    
    await _auditService.logHostKeyUpdate(
      hostId: host.id,
      hostname: host.hostname,
      oldFingerprint: host.knownHostKeyFingerprint,
      newFingerprint: newFingerprint,
    );
  }

  /// Get connection statistics
  Map<String, dynamic> getConnectionStats() {
    return {
      'active_connections': _activeConnections.length,
      'jump_host_pool_size': _jumpHostPool.length,
      'connections_by_security_level': _getConnectionsBySecurityLevel(),
      'total_commands_executed': _getTotalCommandsExecuted(),
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    await disconnectAll();
    await _securityEventsController.close();
  }

  // Private helper methods

  Future<void> _performSecurityChecks(SecureHost host) async {
    // Check if host requires biometric authentication
    if (host.requiresBiometric) {
      final biometricAvailable = await _secureStorage.biometricAuth.isAvailable();
      if (!biometricAvailable) {
        throw const SSHSecurityException('Biometric authentication required but not available');
      }
    }
    
    // Check security level compliance
    if (host.securityLevel == SecurityLevel.critical) {
      await _performCriticalSecurityChecks(host);
    }
    
    // Validate host configuration
    _validateHostSecurity(host);
  }

  Future<void> _performCriticalSecurityChecks(SecureHost host) async {
    // Critical security requirements
    if (!host.strictHostKeyChecking) {
      throw const SSHSecurityException('Critical security level requires strict host key checking');
    }
    
    if (host.authMethod == AuthMethod.password) {
      throw const SSHSecurityException('Critical security level prohibits password authentication');
    }
    
    if (host.compressionEnabled) {
      throw const SSHSecurityException('Critical security level prohibits compression');
    }
  }

  void _validateHostSecurity(SecureHost host) {
    // Validate cipher suites
    for (final cipher in host.allowedCiphers) {
      if (!_isSecureCipher(cipher)) {
        throw SSHSecurityException('Insecure cipher detected: $cipher');
      }
    }
    
    // Validate MAC algorithms
    for (final mac in host.allowedMACs) {
      if (!_isSecureMAC(mac)) {
        throw SSHSecurityException('Insecure MAC algorithm detected: $mac');
      }
    }
  }

  bool _isSecureCipher(String cipher) {
    const secureCiphers = [
      'aes256-gcm@openssh.com',
      'aes256-ctr',
      'aes192-ctr',
      'chacha20-poly1305@openssh.com',
    ];
    return secureCiphers.contains(cipher);
  }

  bool _isSecureMAC(String mac) {
    const secureMACs = [
      'hmac-sha2-256-etm@openssh.com',
      'hmac-sha2-512-etm@openssh.com',
      'hmac-sha2-256',
      'hmac-sha2-512',
    ];
    return secureMACs.contains(mac);
  }

  Future<SecureSSHConnection> _createConnection(
    SecureHost host, {
    String? passphrase,
    bool validateCommands = true,
    ValidationLevel commandValidationLevel = ValidationLevel.strict,
  }) async {
    final socket = await SSHSocket.connect(host.hostname, host.port);
    
    List<SSHKeyPair> identities = [];
    if (host.privateKeyId != null) {
      final privateKey = await _getPrivateKey(host, passphrase);
      identities = [SSHKeyPair.fromPem(privateKey)].expand((x) => x).toList();
    }
    
    final client = SSHClient(
      socket,
      username: host.username,
      onPasswordRequest: host.passwordHash != null 
          ? () => _getPassword(host)
          : null,
      identities: identities,
      onUserauthBanner: (banner) => debugPrint('SSH Banner: $banner'),
    );
    
    await client.authenticated;
    
    return SecureSSHConnection(
      id: _generateConnectionId(host),
      host: host,
      client: client,
      validateCommands: validateCommands,
      commandValidationLevel: commandValidationLevel,
      secureStorage: _secureStorage,
      cryptoService: _cryptoService,
      auditService: _auditService,
    );
  }

  Future<SecureSSHConnection> _getOrCreateJumpHostConnection(
    SecureHost jumpHost, {
    String? passphrase,
  }) async {
    final jumpHostKey = '${jumpHost.hostname}:${jumpHost.port}';
    
    if (_jumpHostPool.containsKey(jumpHostKey)) {
      final existingClient = _jumpHostPool[jumpHostKey]!;
      if (existingClient.isClosed) {
        _jumpHostPool.remove(jumpHostKey);
      } else {
        return SecureSSHConnection(
          id: _generateConnectionId(jumpHost),
          host: jumpHost,
          client: existingClient,
          validateCommands: false, // Jump host doesn't need command validation
          commandValidationLevel: ValidationLevel.permissive,
          secureStorage: _secureStorage,
          cryptoService: _cryptoService,
          auditService: _auditService,
        );
      }
    }
    
    // Create new jump host connection
    final connection = await _createConnection(
      jumpHost,
      passphrase: passphrase,
      validateCommands: false,
      commandValidationLevel: ValidationLevel.permissive,
    );
    
    _jumpHostPool[jumpHostKey] = connection.client;
    
    return connection;
  }

  Future<String> _getPassword(SecureHost host) async {
    if (host.passwordHash == null) {
      throw const SSHException('Password authentication required but no password stored');
    }
    
    // In a real implementation, you might prompt the user or use biometric auth
    throw const SSHException('Password retrieval not implemented');
  }

  Future<String> _getPrivateKey(SecureHost host, String? passphrase) async {
    if (host.privateKeyId == null) {
      throw const SSHException('Private key authentication required but no key stored');
    }
    
    if (passphrase == null) {
      throw const SSHException('Passphrase required for private key');
    }
    
    final privateKey = await _secureStorage.getSSHKey(host.privateKeyId!, passphrase);
    if (privateKey == null) {
      throw const SSHException('Failed to retrieve private key');
    }
    
    return privateKey;
  }

  /// Verify SSH host key against known fingerprints
  /// TODO: Integrate host key verification into connection process  

  Future<void> _storeHostKey(SecureHost host, String fingerprint) async {
    await _secureStorage.storeHostFingerprint(
      hostname: host.hostname,
      fingerprint: fingerprint,
      keyType: host.hostKeyType ?? 'unknown',
    );
  }


  String _generateConnectionId(SecureHost host) {
    return '${host.id}_${DateTime.now().millisecondsSinceEpoch}';
  }

  String? _hashPassphrase(String passphrase) {
    final bytes = utf8.encode(passphrase);
    final digest = _cryptoService.calculateSSHFingerprint(base64.encode(bytes));
    return digest;
  }

  void _validateSSHKey(String privateKey, String publicKey) {
    if (!privateKey.contains('BEGIN') || !privateKey.contains('PRIVATE KEY')) {
      throw const SSHException('Invalid private key format');
    }
    
    if (!publicKey.startsWith('ssh-')) {
      throw const SSHException('Invalid public key format');
    }
  }

  Map<String, dynamic> _parseSSHKey(String publicKey) {
    final parts = publicKey.split(' ');
    if (parts.length < 2) {
      throw const SSHException('Invalid SSH public key format');
    }
    
    final type = parts[0].replaceAll('ssh-', '');
    int? size;
    
    if (type == 'rsa') {
      // RSA key size estimation based on public key length
      final keyData = base64.decode(parts[1]);
      size = keyData.length * 8; // Rough estimation
    } else if (type == 'ed25519') {
      size = 256;
    }
    
    return {
      'type': type,
      'size': size,
    };
  }

  Map<String, int> _getConnectionsBySecurityLevel() {
    final stats = <String, int>{};
    
    for (final connection in _activeConnections.values) {
      final level = connection.host.securityLevel.name;
      stats[level] = (stats[level] ?? 0) + 1;
    }
    
    return stats;
  }

  int _getTotalCommandsExecuted() {
    return _activeConnections.values
        .fold(0, (total, conn) => total + conn.commandCount);
  }
}


