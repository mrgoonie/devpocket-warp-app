import 'package:flutter/foundation.dart';

/// Comprehensive SSH error classification for better user experience
enum SshErrorType {
  // Network-related errors
  networkUnreachable,
  hostUnreachable,
  connectionTimeout,
  networkTimeout,
  portClosed,
  
  // Authentication errors
  authenticationFailed,
  invalidCredentials,
  keyAuthenticationFailed,
  invalidPrivateKey,
  keyPermissionDenied,
  passphraseRequired,
  
  // Server-related errors
  serverRefused,
  protocolError,
  sshServiceUnavailable,
  hostKeyVerificationFailed,
  
  // Client-related errors
  invalidConfiguration,
  missingCredentials,
  localResourceError,
  
  // General errors
  unknown,
  cancelled,
}

/// Comprehensive SSH connection error with user-friendly messaging
@immutable
class SshConnectionError {
  final SshErrorType type;
  final String technicalMessage;
  final String userFriendlyMessage;
  final List<String> suggestedActions;
  final bool isRetryable;
  final int? retryAfterSeconds;
  final Map<String, dynamic>? debugInfo;
  final DateTime timestamp;

  const SshConnectionError({
    required this.type,
    required this.technicalMessage,
    required this.userFriendlyMessage,
    required this.suggestedActions,
    required this.isRetryable,
    this.retryAfterSeconds,
    this.debugInfo,
    required this.timestamp,
  });

  /// Factory constructor to create error from exception
  factory SshConnectionError.fromException(
    Exception exception, {
    Map<String, dynamic>? debugInfo,
  }) {
    final errorMessage = exception.toString().toLowerCase();
    final type = _classifyError(errorMessage);
    
    return SshConnectionError(
      type: type,
      technicalMessage: exception.toString(),
      userFriendlyMessage: _getUserFriendlyMessage(type),
      suggestedActions: _getSuggestedActions(type),
      isRetryable: _isRetryable(type),
      retryAfterSeconds: _getRetryDelay(type),
      debugInfo: debugInfo,
      timestamp: DateTime.now(),
    );
  }

  /// Factory constructor to create specific error type
  factory SshConnectionError.create(
    SshErrorType type, {
    String? technicalMessage,
    Map<String, dynamic>? debugInfo,
  }) {
    return SshConnectionError(
      type: type,
      technicalMessage: technicalMessage ?? type.toString(),
      userFriendlyMessage: _getUserFriendlyMessage(type),
      suggestedActions: _getSuggestedActions(type),
      isRetryable: _isRetryable(type),
      retryAfterSeconds: _getRetryDelay(type),
      debugInfo: debugInfo,
      timestamp: DateTime.now(),
    );
  }

  /// Check if error indicates connection should be retried automatically
  bool get shouldAutoRetry => isRetryable && _isAutoRetryable(type);

  /// Get retry strategy for this error type
  SshRetryStrategy get retryStrategy => _getRetryStrategy(type);

  /// Create a copy with updated information
  SshConnectionError copyWith({
    SshErrorType? type,
    String? technicalMessage,
    String? userFriendlyMessage,
    List<String>? suggestedActions,
    bool? isRetryable,
    int? retryAfterSeconds,
    Map<String, dynamic>? debugInfo,
    DateTime? timestamp,
  }) {
    return SshConnectionError(
      type: type ?? this.type,
      technicalMessage: technicalMessage ?? this.technicalMessage,
      userFriendlyMessage: userFriendlyMessage ?? this.userFriendlyMessage,
      suggestedActions: suggestedActions ?? this.suggestedActions,
      isRetryable: isRetryable ?? this.isRetryable,
      retryAfterSeconds: retryAfterSeconds ?? this.retryAfterSeconds,
      debugInfo: debugInfo ?? this.debugInfo,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'SshConnectionError(type: $type, message: $userFriendlyMessage)';
  }

  /// Convert error to Map for logging/debugging
  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'technicalMessage': technicalMessage,
      'userFriendlyMessage': userFriendlyMessage,
      'suggestedActions': suggestedActions,
      'isRetryable': isRetryable,
      'retryAfterSeconds': retryAfterSeconds,
      'debugInfo': debugInfo,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // Private helper methods for error classification and messaging

  static SshErrorType _classifyError(String errorMessage) {
    // Network-related patterns
    if (errorMessage.contains('network unreachable') || 
        errorMessage.contains('no route to host')) {
      return SshErrorType.networkUnreachable;
    }
    if (errorMessage.contains('host unreachable') || 
        errorMessage.contains('connection refused')) {
      return SshErrorType.hostUnreachable;
    }
    if (errorMessage.contains('timeout') || errorMessage.contains('timed out')) {
      return SshErrorType.connectionTimeout;
    }
    if (errorMessage.contains('connection refused')) {
      return SshErrorType.portClosed;
    }

    // Authentication-related patterns
    if (errorMessage.contains('auth') || errorMessage.contains('authentication')) {
      if (errorMessage.contains('key')) {
        return SshErrorType.keyAuthenticationFailed;
      }
      if (errorMessage.contains('password')) {
        return SshErrorType.invalidCredentials;
      }
      return SshErrorType.authenticationFailed;
    }
    if (errorMessage.contains('permission denied')) {
      return SshErrorType.keyPermissionDenied;
    }
    if (errorMessage.contains('invalid private key') || 
        errorMessage.contains('invalid key format')) {
      return SshErrorType.invalidPrivateKey;
    }
    if (errorMessage.contains('passphrase')) {
      return SshErrorType.passphraseRequired;
    }

    // Server-related patterns
    if (errorMessage.contains('refused') || errorMessage.contains('rejected')) {
      return SshErrorType.serverRefused;
    }
    if (errorMessage.contains('protocol')) {
      return SshErrorType.protocolError;
    }
    if (errorMessage.contains('service unavailable') || 
        errorMessage.contains('ssh service')) {
      return SshErrorType.sshServiceUnavailable;
    }
    if (errorMessage.contains('host key')) {
      return SshErrorType.hostKeyVerificationFailed;
    }

    // Client-related patterns
    if (errorMessage.contains('configuration') || errorMessage.contains('config')) {
      return SshErrorType.invalidConfiguration;
    }
    if (errorMessage.contains('missing') || errorMessage.contains('required')) {
      return SshErrorType.missingCredentials;
    }

    // General patterns
    if (errorMessage.contains('cancelled') || errorMessage.contains('abort')) {
      return SshErrorType.cancelled;
    }

    return SshErrorType.unknown;
  }

  static String _getUserFriendlyMessage(SshErrorType type) {
    switch (type) {
      case SshErrorType.networkUnreachable:
        return 'No internet connection available. Please check your network connection.';
      case SshErrorType.hostUnreachable:
        return 'Cannot reach the server. Please check the hostname and your internet connection.';
      case SshErrorType.connectionTimeout:
        return 'Connection timed out. The server may be slow to respond or temporarily unavailable.';
      case SshErrorType.networkTimeout:
        return 'Network request timed out. Please check your internet connection.';
      case SshErrorType.portClosed:
        return 'Connection refused. The SSH service may not be running on the server.';
      
      case SshErrorType.authenticationFailed:
        return 'Login failed. Please check your username and password.';
      case SshErrorType.invalidCredentials:
        return 'Username or password is incorrect. Please check your credentials.';
      case SshErrorType.keyAuthenticationFailed:
        return 'SSH key authentication failed. Please check your private key.';
      case SshErrorType.invalidPrivateKey:
        return 'The private key format is invalid or corrupted.';
      case SshErrorType.keyPermissionDenied:
        return 'Permission denied. The SSH key may not be authorized for this account.';
      case SshErrorType.passphraseRequired:
        return 'Private key passphrase is required but not provided.';
      
      case SshErrorType.serverRefused:
        return 'Server refused the connection. You may not be authorized to access this server.';
      case SshErrorType.protocolError:
        return 'SSH protocol error occurred. The server may not support this client.';
      case SshErrorType.sshServiceUnavailable:
        return 'SSH service is not available on the server. Please contact your administrator.';
      case SshErrorType.hostKeyVerificationFailed:
        return 'Host key verification failed. The server identity cannot be verified.';
      
      case SshErrorType.invalidConfiguration:
        return 'SSH configuration is invalid. Please check your connection settings.';
      case SshErrorType.missingCredentials:
        return 'Required connection information is missing. Please check your profile settings.';
      case SshErrorType.localResourceError:
        return 'Local system error occurred. Please try again or restart the app.';
      
      case SshErrorType.cancelled:
        return 'Connection was cancelled by user.';
      case SshErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  static List<String> _getSuggestedActions(SshErrorType type) {
    switch (type) {
      case SshErrorType.networkUnreachable:
        return [
          'Check your WiFi or mobile data connection',
          'Try connecting to a different network',
          'Restart your device\'s network connection',
        ];
      case SshErrorType.hostUnreachable:
        return [
          'Verify the server hostname or IP address',
          'Check your internet connection',
          'Contact your network administrator',
          'Try again in a few minutes',
        ];
      case SshErrorType.connectionTimeout:
        return [
          'Try connecting again',
          'Check your internet connection speed',
          'Contact the server administrator',
          'Try connecting from a different network',
        ];
      case SshErrorType.networkTimeout:
        return [
          'Check your internet connection',
          'Try connecting again',
          'Switch to a different network if possible',
        ];
      case SshErrorType.portClosed:
        return [
          'Verify the SSH port number (usually 22)',
          'Contact your server administrator',
          'Check if SSH service is running on the server',
          'Try a different port if configured',
        ];
      
      case SshErrorType.authenticationFailed:
      case SshErrorType.invalidCredentials:
        return [
          'Double-check your username and password',
          'Reset your password if necessary',
          'Contact your administrator for account status',
          'Try using SSH key authentication instead',
        ];
      case SshErrorType.keyAuthenticationFailed:
        return [
          'Check if your SSH key is properly formatted',
          'Verify the key is registered with the server',
          'Try regenerating your SSH key pair',
          'Contact your administrator about key permissions',
        ];
      case SshErrorType.invalidPrivateKey:
        return [
          'Check the private key file format',
          'Try generating a new SSH key pair',
          'Verify the key was copied correctly',
          'Check if the key requires a passphrase',
        ];
      case SshErrorType.keyPermissionDenied:
        return [
          'Contact your administrator to authorize your key',
          'Check if your key is in the server\'s authorized_keys',
          'Try using password authentication instead',
          'Verify your account has SSH access',
        ];
      case SshErrorType.passphraseRequired:
        return [
          'Enter the correct passphrase for your private key',
          'Generate a key without passphrase if allowed',
          'Check the passphrase spelling and case',
        ];
      
      case SshErrorType.serverRefused:
        return [
          'Contact your server administrator',
          'Check if your account is active',
          'Verify SSH access is enabled for your account',
          'Try connecting later',
        ];
      case SshErrorType.protocolError:
        return [
          'Update your SSH client',
          'Contact the server administrator',
          'Try using a different SSH client',
          'Check server SSH version compatibility',
        ];
      case SshErrorType.sshServiceUnavailable:
        return [
          'Contact your server administrator',
          'Check if SSH service is running',
          'Try connecting later',
          'Verify the correct server address',
        ];
      case SshErrorType.hostKeyVerificationFailed:
        return [
          'Contact your administrator to verify server identity',
          'Check if the server was recently updated',
          'Remove old host key from known_hosts if safe',
          'Verify you\'re connecting to the correct server',
        ];
      
      case SshErrorType.invalidConfiguration:
        return [
          'Check all connection settings',
          'Verify hostname, port, and credentials',
          'Reset to default settings if needed',
          'Contact support for configuration help',
        ];
      case SshErrorType.missingCredentials:
        return [
          'Fill in all required connection fields',
          'Choose either password or SSH key authentication',
          'Contact your administrator for connection details',
        ];
      case SshErrorType.localResourceError:
        return [
          'Restart the app and try again',
          'Check available device storage',
          'Update the app if available',
          'Contact support if problem persists',
        ];
      
      case SshErrorType.cancelled:
        return [
          'Try connecting again if needed',
        ];
      case SshErrorType.unknown:
        return [
          'Try connecting again',
          'Check your internet connection',
          'Contact support with error details',
          'Update the app if available',
        ];
    }
  }

  static bool _isRetryable(SshErrorType type) {
    switch (type) {
      case SshErrorType.networkUnreachable:
      case SshErrorType.hostUnreachable:
      case SshErrorType.connectionTimeout:
      case SshErrorType.networkTimeout:
      case SshErrorType.localResourceError:
        return true;
      
      case SshErrorType.authenticationFailed:
      case SshErrorType.invalidCredentials:
      case SshErrorType.keyAuthenticationFailed:
      case SshErrorType.invalidPrivateKey:
      case SshErrorType.keyPermissionDenied:
      case SshErrorType.passphraseRequired:
      case SshErrorType.invalidConfiguration:
      case SshErrorType.missingCredentials:
        return false;
      
      case SshErrorType.portClosed:
      case SshErrorType.serverRefused:
      case SshErrorType.protocolError:
      case SshErrorType.sshServiceUnavailable:
      case SshErrorType.hostKeyVerificationFailed:
        return false;
      
      case SshErrorType.cancelled:
        return false;
      case SshErrorType.unknown:
        return true;
    }
  }

  static bool _isAutoRetryable(SshErrorType type) {
    switch (type) {
      case SshErrorType.networkUnreachable:
      case SshErrorType.hostUnreachable:
      case SshErrorType.connectionTimeout:
      case SshErrorType.networkTimeout:
        return true;
      default:
        return false;
    }
  }

  static int? _getRetryDelay(SshErrorType type) {
    switch (type) {
      case SshErrorType.networkUnreachable:
      case SshErrorType.networkTimeout:
        return 5; // 5 seconds for network issues
      case SshErrorType.hostUnreachable:
      case SshErrorType.connectionTimeout:
        return 10; // 10 seconds for server issues
      case SshErrorType.localResourceError:
        return 3; // 3 seconds for local issues
      default:
        return null;
    }
  }

  static SshRetryStrategy _getRetryStrategy(SshErrorType type) {
    switch (type) {
      case SshErrorType.networkUnreachable:
      case SshErrorType.networkTimeout:
        return SshRetryStrategy.waitForNetwork;
      case SshErrorType.hostUnreachable:
      case SshErrorType.connectionTimeout:
        return SshRetryStrategy.exponentialBackoff;
      case SshErrorType.localResourceError:
        return SshRetryStrategy.fixedDelay;
      default:
        return SshRetryStrategy.noRetry;
    }
  }
}

/// Retry strategies for different error types
enum SshRetryStrategy {
  noRetry,
  fixedDelay,
  exponentialBackoff,
  waitForNetwork,
}

/// Connection health metrics for monitoring
@immutable
class SshHealthMetrics {
  final double latencyMs;
  final SshConnectionQuality quality;
  final DateTime lastHealthCheck;
  final int consecutiveFailures;
  final bool isHealthy;

  const SshHealthMetrics({
    required this.latencyMs,
    required this.quality,
    required this.lastHealthCheck,
    required this.consecutiveFailures,
    required this.isHealthy,
  });

  factory SshHealthMetrics.initial() {
    return SshHealthMetrics(
      latencyMs: 0.0,
      quality: SshConnectionQuality.unknown,
      lastHealthCheck: DateTime.now(),
      consecutiveFailures: 0,
      isHealthy: true,
    );
  }

  SshHealthMetrics copyWith({
    double? latencyMs,
    SshConnectionQuality? quality,
    DateTime? lastHealthCheck,
    int? consecutiveFailures,
    bool? isHealthy,
  }) {
    return SshHealthMetrics(
      latencyMs: latencyMs ?? this.latencyMs,
      quality: quality ?? this.quality,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      isHealthy: isHealthy ?? this.isHealthy,
    );
  }

  /// Get health score (0-100)
  int get healthScore {
    if (!isHealthy) return 0;
    
    int score = 100;
    
    // Reduce score based on latency
    if (latencyMs > 1000) {
      score -= 30; // Very slow
    } else if (latencyMs > 500) {
      score -= 20; // Slow
    } else if (latencyMs > 200) {
      score -= 10; // Moderate
    }
    
    // Reduce score based on consecutive failures
    score -= (consecutiveFailures * 10).clamp(0, 50);
    
    return score.clamp(0, 100);
  }

  @override
  String toString() {
    return 'SshHealthMetrics(latency: ${latencyMs}ms, quality: $quality, healthy: $isHealthy)';
  }
}

/// Connection quality levels
enum SshConnectionQuality {
  excellent,  // < 100ms, no issues
  good,       // 100-300ms, minimal issues
  fair,       // 300-800ms, some issues
  poor,       // > 800ms, frequent issues
  critical,   // Connection barely working
  unknown,    // Quality not yet determined
}

/// Extension methods for SshConnectionQuality
extension SshConnectionQualityExtension on SshConnectionQuality {
  String get displayName {
    switch (this) {
      case SshConnectionQuality.excellent:
        return 'Excellent';
      case SshConnectionQuality.good:
        return 'Good';
      case SshConnectionQuality.fair:
        return 'Fair';
      case SshConnectionQuality.poor:
        return 'Poor';
      case SshConnectionQuality.critical:
        return 'Critical';
      case SshConnectionQuality.unknown:
        return 'Unknown';
    }
  }

  String get emoji {
    switch (this) {
      case SshConnectionQuality.excellent:
        return '🟢';
      case SshConnectionQuality.good:
        return '🟡';
      case SshConnectionQuality.fair:
        return '🟠';
      case SshConnectionQuality.poor:
        return '🔴';
      case SshConnectionQuality.critical:
        return '⚫';
      case SshConnectionQuality.unknown:
        return '⚪';
    }
  }
}

/// Connection steps for progress tracking
enum SshConnectionStep {
  initializing('Initializing connection...'),
  connecting('Connecting to server...'),
  authenticating('Authenticating credentials...'),
  establishingSession('Establishing secure session...'),
  connected('Connected successfully');

  const SshConnectionStep(this.description);
  final String description;
}