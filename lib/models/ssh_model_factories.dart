import 'package:uuid/uuid.dart';

import 'secure_host_model.dart';
import 'secure_ssh_key_model.dart';
import 'secure_connection_log_model.dart';
import 'ssh_security_enums.dart';

/// Factory methods for creating secure instances
class SecureHostFactory {
  static const Uuid _uuid = Uuid();

  static SecureHost create({
    required String name,
    required String hostname,
    required String username,
    int port = 22,
    String? passwordHash,
    AuthMethod authMethod = AuthMethod.publicKey, // More secure default
    String? description,
    List<String> tags = const [],
    String? color,
    SecurityLevel securityLevel = SecurityLevel.medium,
    HostKeyVerification hostKeyVerification = HostKeyVerification.strict,
    bool requiresBiometric = false,
  }) {
    final now = DateTime.now();
    return SecureHost(
      id: _uuid.v4(),
      name: name,
      hostname: hostname,
      port: port,
      username: username,
      passwordHash: passwordHash,
      authMethod: authMethod,
      createdAt: now,
      updatedAt: now,
      description: description,
      tags: tags,
      color: color,
      securityLevel: securityLevel,
      hostKeyVerification: hostKeyVerification,
      requiresBiometric: requiresBiometric,
    );
  }
}

class SecureSSHKeyFactory {
  static const Uuid _uuid = Uuid();

  static SecureSSHKey create({
    required String name,
    required String type,
    required String publicKey,
    required String fingerprint,
    String? encryptedPrivateKeyData,
    String? passphraseHash,
    int? keySize,
    String? description,
    String? comment,
    DateTime? expirationDate,
    SecurityLevel securityLevel = SecurityLevel.medium,
    bool requiresBiometric = false,
  }) {
    final now = DateTime.now();
    return SecureSSHKey(
      id: _uuid.v4(),
      name: name,
      type: type,
      publicKey: publicKey,
      fingerprint: fingerprint,
      encryptedPrivateKeyData: encryptedPrivateKeyData,
      passphraseHash: passphraseHash,
      keySize: keySize,
      createdAt: now,
      updatedAt: now,
      description: description,
      comment: comment,
      expirationDate: expirationDate,
      securityLevel: securityLevel,
      requiresBiometric: requiresBiometric,
    );
  }
}

class SecureConnectionLogFactory {
  static const Uuid _uuid = Uuid();

  static SecureConnectionLog create({
    required String hostId,
    required String hostname,
    required String username,
    required bool success,
    required String sourceIP,
    String? error,
    String? message,
    Duration? duration,
    int commandCount = 0,
    String? lastCommand,
    String? userAgent,
    AuthMethod authMethod = AuthMethod.password,
    SecurityLevel securityLevel = SecurityLevel.medium,
    List<String> securityWarnings = const [],
    Map<String, dynamic> securityMetadata = const {},
  }) {
    return SecureConnectionLog(
      id: _uuid.v4(),
      hostId: hostId,
      hostname: hostname,
      username: username,
      timestamp: DateTime.now(),
      success: success,
      error: error,
      message: message,
      duration: duration,
      commandCount: commandCount,
      lastCommand: lastCommand,
      sourceIP: sourceIP,
      userAgent: userAgent,
      authMethod: authMethod,
      securityLevel: securityLevel,
      securityWarnings: securityWarnings,
      securityMetadata: securityMetadata,
    );
  }
}