/// Basic SSH-related enums for standard SSH operations

/// SSH Key types supported for generation
enum SshKeyType {
  rsa2048('rsa', 2048),
  rsa4096('rsa', 4096),
  ed25519('ed25519', 256),
  ecdsa256('ecdsa', 256),
  ecdsa384('ecdsa', 384),
  ecdsa521('ecdsa', 521);

  const SshKeyType(this.algorithm, this.keySize);
  
  final String algorithm;
  final int keySize;
  
  String get displayName {
    switch (this) {
      case SshKeyType.rsa2048:
        return 'RSA 2048-bit';
      case SshKeyType.rsa4096:
        return 'RSA 4096-bit (Recommended)';
      case SshKeyType.ed25519:
        return 'Ed25519 (Most Secure)';
      case SshKeyType.ecdsa256:
        return 'ECDSA P-256';
      case SshKeyType.ecdsa384:
        return 'ECDSA P-384';
      case SshKeyType.ecdsa521:
        return 'ECDSA P-521';
    }
  }
  
  String get description {
    switch (this) {
      case SshKeyType.rsa2048:
        return 'Standard RSA key, widely compatible';
      case SshKeyType.rsa4096:
        return 'High security RSA key, recommended for most use cases';
      case SshKeyType.ed25519:
        return 'Modern, fastest and most secure option';
      case SshKeyType.ecdsa256:
        return 'Elliptic curve key, good performance';
      case SshKeyType.ecdsa384:
        return 'Higher security elliptic curve key';
      case SshKeyType.ecdsa521:
        return 'Highest security elliptic curve key';
    }
  }
}

/// Basic host connection status
enum HostStatus {
  unknown,
  online,
  offline,
  connecting,
  error,
}

/// Basic SSH authentication methods  
enum AuthMethod {
  password,
  publicKey,
  keyboardInteractive,
}

/// SSH key event types for auditing
enum SshKeyEventType {
  generating,
  created,
  importing,
  imported,
  updated,
  deleted,
  exported,
  copied,
  cleanup,
  error,
}