/// SSH security-related enums for enhanced security features

/// Host connection status
enum HostStatus {
  unknown,
  online,
  offline,
  connecting,
  connected,
  disconnected,
  error,
  authenticating,
  timeout,
}

/// SSH authentication methods
enum AuthMethod {
  password,
  publicKey,
  keyboardInteractive,
  certificate,
  multiFactor,
  agent,
}

/// SSH connection security level
enum SecurityLevel {
  low,     // Basic security
  medium,  // Standard security with host key verification
  high,    // Enhanced security with certificate validation
  critical, // Maximum security for production systems
}

/// Host key verification mode
enum HostKeyVerification {
  disabled,   // No verification (insecure)
  warn,       // Warn on unknown keys
  strict,     // Strict verification (recommended)
  interactive, // Ask user for unknown keys
}

/// Connection encryption level
enum EncryptionLevel {
  legacy,   // Older ciphers for compatibility
  standard, // Modern secure ciphers
  high,     // High-security cipher suites
}

/// Security risk levels for auditing
enum SecurityRisk {
  none,
  low,
  medium,
  high,
  critical,
}