import 'ssh_security_enums.dart';

/// Enhanced SSH Key model with comprehensive security
class SecureSSHKey {
  final String id;
  final String name;
  final String type; // rsa, ed25519, ecdsa
  final String publicKey;
  final String? encryptedPrivateKeyData; // Encrypted private key
  final String? passphraseHash;
  final int? keySize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? description;
  final List<String> hostIds; // Associated host IDs
  final String fingerprint;
  final String? comment;
  final DateTime? expirationDate;
  final bool isHardwareKey; // Hardware security key
  final SecurityLevel securityLevel;
  final bool requiresBiometric;
  final DateTime? lastUsed;
  final Map<String, dynamic> metadata;

  const SecureSSHKey({
    required this.id,
    required this.name,
    required this.type,
    required this.publicKey,
    this.encryptedPrivateKeyData,
    this.passphraseHash,
    this.keySize,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.hostIds = const [],
    required this.fingerprint,
    this.comment,
    this.expirationDate,
    this.isHardwareKey = false,
    this.securityLevel = SecurityLevel.medium,
    this.requiresBiometric = false,
    this.lastUsed,
    this.metadata = const {},
  });

  SecureSSHKey copyWith({
    String? id,
    String? name,
    String? type,
    String? publicKey,
    String? encryptedPrivateKeyData,
    String? passphraseHash,
    int? keySize,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? description,
    List<String>? hostIds,
    String? fingerprint,
    String? comment,
    DateTime? expirationDate,
    bool? isHardwareKey,
    SecurityLevel? securityLevel,
    bool? requiresBiometric,
    DateTime? lastUsed,
    Map<String, dynamic>? metadata,
  }) {
    return SecureSSHKey(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      publicKey: publicKey ?? this.publicKey,
      encryptedPrivateKeyData: encryptedPrivateKeyData ?? this.encryptedPrivateKeyData,
      passphraseHash: passphraseHash ?? this.passphraseHash,
      keySize: keySize ?? this.keySize,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      hostIds: hostIds ?? this.hostIds,
      fingerprint: fingerprint ?? this.fingerprint,
      comment: comment ?? this.comment,
      expirationDate: expirationDate ?? this.expirationDate,
      isHardwareKey: isHardwareKey ?? this.isHardwareKey,
      securityLevel: securityLevel ?? this.securityLevel,
      requiresBiometric: requiresBiometric ?? this.requiresBiometric,
      lastUsed: lastUsed ?? this.lastUsed,
      metadata: metadata ?? this.metadata,
    );
  }

  factory SecureSSHKey.fromJson(Map<String, dynamic> json) {
    return SecureSSHKey(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      publicKey: json['public_key'],
      encryptedPrivateKeyData: json['encrypted_private_key_data'],
      passphraseHash: json['passphrase_hash'],
      keySize: json['key_size'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      description: json['description'],
      hostIds: List<String>.from(json['host_ids'] ?? []),
      fingerprint: json['fingerprint'],
      comment: json['comment'],
      expirationDate: json['expiration_date'] != null
          ? DateTime.parse(json['expiration_date'])
          : null,
      isHardwareKey: json['is_hardware_key'] ?? false,
      securityLevel: SecurityLevel.values.firstWhere(
        (e) => e.name == json['security_level'],
        orElse: () => SecurityLevel.medium,
      ),
      requiresBiometric: json['requires_biometric'] ?? false,
      lastUsed: json['last_used'] != null
          ? DateTime.parse(json['last_used'])
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'public_key': publicKey,
      'encrypted_private_key_data': encryptedPrivateKeyData,
      'passphrase_hash': passphraseHash,
      'key_size': keySize,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'description': description,
      'host_ids': hostIds,
      'fingerprint': fingerprint,
      'comment': comment,
      'expiration_date': expirationDate?.toIso8601String(),
      'is_hardware_key': isHardwareKey,
      'security_level': securityLevel.name,
      'requires_biometric': requiresBiometric,
      'last_used': lastUsed?.toIso8601String(),
      'metadata': metadata,
    };
  }

  String get displayType => type.toUpperCase();
  String get shortFingerprint => fingerprint.length > 16 
      ? '${fingerprint.substring(0, 16)}...' 
      : fingerprint;

  bool get hasPassphrase => passphraseHash != null && passphraseHash!.isNotEmpty;
  bool get isExpired => expirationDate != null && DateTime.now().isAfter(expirationDate!);
  bool get isExpiringSoon => expirationDate != null && 
      DateTime.now().add(const Duration(days: 30)).isAfter(expirationDate!);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SecureSSHKey && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SecureSSHKey{id: $id, name: $name, type: $type, fingerprint: $shortFingerprint}';
  }
}