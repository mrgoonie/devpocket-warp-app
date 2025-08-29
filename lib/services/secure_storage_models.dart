import 'dart:typed_data';

/// Exception for secure storage operations
class SecureStorageException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const SecureStorageException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'SecureStorageException: $message';
}

/// Metadata for stored items
class StorageMetadata {
  final DateTime createdAt;
  final DateTime lastAccessed;
  final String version;
  final String? description;
  final bool requiresBiometric;

  const StorageMetadata({
    required this.createdAt,
    required this.lastAccessed,
    required this.version,
    this.description,
    this.requiresBiometric = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'createdAt': createdAt.toIso8601String(),
      'lastAccessed': lastAccessed.toIso8601String(),
      'version': version,
      'description': description,
      'requiresBiometric': requiresBiometric,
    };
  }

  factory StorageMetadata.fromJson(Map<String, dynamic> json) {
    return StorageMetadata(
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastAccessed: DateTime.parse(json['lastAccessed'] as String),
      version: json['version'] as String,
      description: json['description'] as String?,
      requiresBiometric: json['requiresBiometric'] as bool? ?? false,
    );
  }
}

/// SSH host key fingerprint for verification
class HostKeyFingerprint {
  final String hostname;
  final String fingerprint;
  final String keyType;
  final DateTime firstSeen;
  final DateTime lastVerified;
  final bool isVerified;

  const HostKeyFingerprint({
    required this.hostname,
    required this.fingerprint,
    required this.keyType,
    required this.firstSeen,
    required this.lastVerified,
    this.isVerified = false,
  });

  factory HostKeyFingerprint.fromJson(Map<String, dynamic> json) {
    return HostKeyFingerprint(
      hostname: json['hostname'] as String,
      fingerprint: json['fingerprint'] as String,
      keyType: json['keyType'] as String,
      firstSeen: DateTime.parse(json['firstSeen'] as String),
      lastVerified: DateTime.parse(json['lastVerified'] as String),
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hostname': hostname,
      'fingerprint': fingerprint,
      'keyType': keyType,
      'firstSeen': firstSeen.toIso8601String(),
      'lastVerified': lastVerified.toIso8601String(),
      'isVerified': isVerified,
    };
  }

  HostKeyFingerprint copyWith({
    String? hostname,
    String? fingerprint,
    String? keyType,
    DateTime? firstSeen,
    DateTime? lastVerified,
    bool? isVerified,
  }) {
    return HostKeyFingerprint(
      hostname: hostname ?? this.hostname,
      fingerprint: fingerprint ?? this.fingerprint,
      keyType: keyType ?? this.keyType,
      firstSeen: firstSeen ?? this.firstSeen,
      lastVerified: lastVerified ?? this.lastVerified,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

/// Device security information
class DeviceSecurityInfo {
  final String deviceId;
  final Uint8List deviceKey;
  final bool biometricsAvailable;
  final bool biometricsEnrolled;
  final DateTime keyCreatedAt;

  const DeviceSecurityInfo({
    required this.deviceId,
    required this.deviceKey,
    required this.biometricsAvailable,
    required this.biometricsEnrolled,
    required this.keyCreatedAt,
  });
}

/// Storage operation result
class StorageResult<T> {
  final T? data;
  final bool success;
  final String? error;
  final StorageMetadata? metadata;

  const StorageResult({
    this.data,
    required this.success,
    this.error,
    this.metadata,
  });

  static StorageResult<T> createSuccess<T>(T data, {StorageMetadata? metadata}) {
    return StorageResult<T>(
      data: data,
      success: true,
      metadata: metadata,
    );
  }

  static StorageResult<T> createFailure<T>(String error) {
    return StorageResult<T>(
      success: false,
      error: error,
    );
  }
}