import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

import '../models/enhanced_ssh_models.dart';
import 'audit_service.dart';

/// Comprehensive biometric authentication service
/// Provides secure biometric authentication for sensitive operations
class BiometricService {
  final LocalAuthentication _localAuth;
  final AuditService _auditService;
  
  // Authentication state
  bool _isAuthenticated = false;
  DateTime? _lastAuthenticationTime;
  Timer? _authenticationTimeoutTimer;
  
  // Configuration
  static const Duration _authenticationTimeout = Duration(minutes: 15);
  // TODO: Implement cooldown period for failed attempts
  // static const Duration _cooldownPeriod = Duration(seconds: 30);
  static const int _maxFailedAttempts = 3;
  
  // Failed attempts tracking
  int _failedAttempts = 0;
  // TODO: Implement lockout logic using these fields
  // DateTime? _lastFailedAttempt;
  DateTime? _lockoutUntil;

  BiometricService({
    LocalAuthentication? localAuth,
    required AuditService auditService,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _auditService = auditService;

  /// Check if biometric authentication is available on device
  Future<bool> isAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      
      return isAvailable && isDeviceSupported;
    } catch (e) {
      debugPrint('Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get list of available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      if (!await isAvailable()) return [];
      
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Get device biometric capabilities
  Future<BiometricCapabilities> getCapabilities() async {
    final availableBiometrics = await getAvailableBiometrics();
    final isAvailable = await _localAuth.isDeviceSupported();
    
    return BiometricCapabilities(
      isAvailable: isAvailable,
      availableBiometrics: availableBiometrics,
      supportsFaceID: availableBiometrics.contains(BiometricType.face),
      supportsTouchID: availableBiometrics.contains(BiometricType.fingerprint),
      supportsIris: availableBiometrics.contains(BiometricType.iris),
      supportsStrongBiometrics: availableBiometrics.contains(BiometricType.strong),
      supportsWeakBiometrics: availableBiometrics.contains(BiometricType.weak),
    );
  }

  /// Authenticate user with biometrics
  Future<BiometricAuthResult> authenticate({
    required String reason,
    BiometricAuthLevel level = BiometricAuthLevel.standard,
    bool allowFallback = true,
    bool stickyAuth = true,
    Duration? customTimeout,
  }) async {
    // Check if service is locked out
    if (_isLockedOut()) {
      final remainingLockout = _lockoutUntil!.difference(DateTime.now());
      
      await _auditService.logAuthentication(
        userId: 'current_user',
        method: AuthMethod.multiFactor,
        success: false,
        error: 'Account locked due to failed attempts',
        biometricUsed: true,
      );
      
      return BiometricAuthResult.failure(
        error: BiometricAuthError.temporarilyLocked,
        message: 'Too many failed attempts. Try again in ${remainingLockout.inSeconds} seconds.',
        remainingLockoutTime: remainingLockout,
      );
    }
    
    // Check if already authenticated and within timeout
    if (_isAuthenticated && !_isAuthenticationExpired()) {
      return BiometricAuthResult.success(
        biometricType: BiometricType.fingerprint, // Default, would be actual type
        authenticationTime: _lastAuthenticationTime!,
        isReused: true,
      );
    }
    
    try {
      // Check availability
      if (!await isAvailable()) {
        return BiometricAuthResult.failure(
          error: BiometricAuthError.notAvailable,
          message: 'Biometric authentication is not available on this device',
        );
      }
      
      // Configure authentication options based on level
      final authOptions = _getAuthenticationOptions(level, allowFallback, stickyAuth);
      
      // Set up timeout
      final timeout = customTimeout ?? _authenticationTimeout;
      
      // Perform authentication
      final result = await _performAuthentication(
        reason: reason,
        options: authOptions,
        timeout: timeout,
      );
      
      if (result.success) {
        if (result.biometricType != null) {
          _onAuthenticationSuccess(result.biometricType!);
        }
        
        await _auditService.logAuthentication(
          userId: 'current_user',
          method: AuthMethod.multiFactor,
          success: true,
          biometricUsed: true,
        );
      } else {
        _onAuthenticationFailure();
        
        await _auditService.logAuthentication(
          userId: 'current_user',
          method: AuthMethod.multiFactor,
          success: false,
          error: result.message,
          biometricUsed: true,
        );
      }
      
      return result;
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      
      await _auditService.logAuthentication(
        userId: 'current_user',
        method: AuthMethod.multiFactor,
        success: false,
        error: e.toString(),
        biometricUsed: true,
      );
      
      return BiometricAuthResult.failure(
        error: BiometricAuthError.unknown,
        message: 'Authentication failed: $e',
      );
    }
  }

  /// Authenticate for specific SSH host
  Future<BiometricAuthResult> authenticateForHost(SecureHost host) async {
    final reason = host.securityLevel == SecurityLevel.critical
        ? 'Critical security access required for ${host.displayName}'
        : 'Biometric authentication required for ${host.displayName}';
    
    final level = host.securityLevel == SecurityLevel.critical
        ? BiometricAuthLevel.high
        : BiometricAuthLevel.standard;
    
    return await authenticate(
      reason: reason,
      level: level,
      allowFallback: host.securityLevel != SecurityLevel.critical,
    );
  }

  /// Authenticate for SSH key access
  Future<BiometricAuthResult> authenticateForKey(SecureSSHKey key) async {
    final reason = key.securityLevel == SecurityLevel.critical
        ? 'Critical key access required for ${key.name}'
        : 'Biometric authentication required to access SSH key';
    
    final level = key.securityLevel == SecurityLevel.critical
        ? BiometricAuthLevel.high
        : BiometricAuthLevel.standard;
    
    return await authenticate(
      reason: reason,
      level: level,
      allowFallback: key.securityLevel != SecurityLevel.critical,
    );
  }

  /// Check if currently authenticated
  bool get isAuthenticated => _isAuthenticated && !_isAuthenticationExpired();

  /// Get time until authentication expires
  Duration? get timeUntilExpiration {
    if (!_isAuthenticated || _lastAuthenticationTime == null) return null;
    
    final expirationTime = _lastAuthenticationTime!.add(_authenticationTimeout);
    final now = DateTime.now();
    
    return expirationTime.isAfter(now) ? expirationTime.difference(now) : Duration.zero;
  }

  /// Invalidate current authentication
  void invalidateAuthentication() {
    _isAuthenticated = false;
    _lastAuthenticationTime = null;
    _authenticationTimeoutTimer?.cancel();
    _authenticationTimeoutTimer = null;
  }

  /// Reset failed attempts counter (admin function)
  void resetFailedAttempts() {
    _failedAttempts = 0;
    // _lastFailedAttempt = null;
    _lockoutUntil = null;
  }

  /// Get authentication status
  BiometricAuthStatus getStatus() {
    return BiometricAuthStatus(
      isAuthenticated: isAuthenticated,
      lastAuthenticationTime: _lastAuthenticationTime,
      timeUntilExpiration: timeUntilExpiration,
      failedAttempts: _failedAttempts,
      isLockedOut: _isLockedOut(),
      lockoutEndTime: _lockoutUntil,
    );
  }

  /// Enable/disable biometric authentication
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      // This would typically involve storing the preference securely
      // and potentially clearing stored biometric templates
      
      await _auditService.logSystemEvent(
        event: 'biometric_setting_changed',
        data: {'enabled': enabled},
      );
      
      if (!enabled) {
        invalidateAuthentication();
      }
      
      return true;
    } catch (e) {
      debugPrint('Failed to change biometric setting: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _authenticationTimeoutTimer?.cancel();
    invalidateAuthentication();
  }

  // Private helper methods

  bool _isAuthenticationExpired() {
    if (_lastAuthenticationTime == null) return true;
    
    final expirationTime = _lastAuthenticationTime!.add(_authenticationTimeout);
    return DateTime.now().isAfter(expirationTime);
  }

  bool _isLockedOut() {
    return _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  }

  AuthenticationOptions _getAuthenticationOptions(
    BiometricAuthLevel level,
    bool allowFallback,
    bool stickyAuth,
  ) {
    switch (level) {
      case BiometricAuthLevel.low:
        return AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: stickyAuth,
          useErrorDialogs: true,
          sensitiveTransaction: false,
        );
      
      case BiometricAuthLevel.standard:
        return AuthenticationOptions(
          biometricOnly: !allowFallback,
          stickyAuth: stickyAuth,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        );
      
      case BiometricAuthLevel.high:
        return AuthenticationOptions(
          biometricOnly: true, // No fallback for high security
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        );
    }
  }

  Future<BiometricAuthResult> _performAuthentication({
    required String reason,
    required AuthenticationOptions options,
    required Duration timeout,
  }) async {
    final startTime = DateTime.now();
    
    try {
      // Create a completer for timeout handling
      final completer = Completer<bool>();
      final timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
      
      // Start authentication
      final authFuture = _localAuth.authenticate(
        localizedReason: reason,
        options: options,
      );
      
      // Race between authentication and timeout
      final result = await Future.any([
        authFuture.then((value) {
          timeoutTimer.cancel();
          return value;
        }),
        completer.future,
      ]);
      
      timeoutTimer.cancel();
      
      if (result) {
        // Get the biometric type used (simplified - would need platform-specific implementation)
        final availableBiometrics = await getAvailableBiometrics();
        final primaryBiometric = availableBiometrics.isNotEmpty 
            ? availableBiometrics.first
            : BiometricType.fingerprint;
        
        return BiometricAuthResult.success(
          biometricType: primaryBiometric,
          authenticationTime: startTime,
        );
      } else {
        return BiometricAuthResult.failure(
          error: BiometricAuthError.timeout,
          message: 'Authentication timed out',
        );
      }
    } on PlatformException catch (e) {
      return _handlePlatformException(e);
    }
  }

  BiometricAuthResult _handlePlatformException(PlatformException e) {
    BiometricAuthError error;
    String message;
    
    switch (e.code) {
      case auth_error.notEnrolled:
        error = BiometricAuthError.notEnrolled;
        message = 'No biometrics enrolled. Please set up biometric authentication in device settings.';
        break;
      
      case auth_error.lockedOut:
        error = BiometricAuthError.temporarilyLocked;
        message = 'Biometric authentication is temporarily locked. Try again later.';
        break;
      
      case auth_error.permanentlyLockedOut:
        error = BiometricAuthError.permanentlyLocked;
        message = 'Biometric authentication is permanently locked. Use device passcode.';
        break;
      
      case auth_error.biometricOnlyNotSupported:
        error = BiometricAuthError.biometricOnlyNotSupported;
        message = 'Device does not support biometric-only authentication.';
        break;
      
      case auth_error.notAvailable:
        error = BiometricAuthError.notAvailable;
        message = 'Biometric authentication is not available.';
        break;
      
      default:
        if (e.code == 'UserCancel' || e.code == 'user_cancel') {
          error = BiometricAuthError.userCancel;
          message = 'Authentication was cancelled by user.';
        } else {
          error = BiometricAuthError.unknown;
          message = 'Biometric authentication failed: ${e.message}';
        }
        break;
    }
    
    return BiometricAuthResult.failure(
      error: error,
      message: message,
      platformError: e,
    );
  }

  void _onAuthenticationSuccess(BiometricType biometricType) {
    _isAuthenticated = true;
    _lastAuthenticationTime = DateTime.now();
    _failedAttempts = 0;
    // _lastFailedAttempt = null;
    _lockoutUntil = null;
    
    // Set up automatic timeout
    _authenticationTimeoutTimer?.cancel();
    _authenticationTimeoutTimer = Timer(_authenticationTimeout, () {
      invalidateAuthentication();
    });
  }

  void _onAuthenticationFailure() {
    _failedAttempts++;
    // _lastFailedAttempt = DateTime.now();
    
    // Implement progressive lockout
    if (_failedAttempts >= _maxFailedAttempts) {
      final lockoutDuration = Duration(
        minutes: _failedAttempts - _maxFailedAttempts + 1,
      );
      _lockoutUntil = DateTime.now().add(lockoutDuration);
    }
  }
}

/// Biometric authentication levels
enum BiometricAuthLevel {
  low,      // Allow fallback to PIN/Password
  standard, // Standard security, some fallback allowed
  high,     // High security, biometric only
}

/// Biometric authentication errors
enum BiometricAuthError {
  notAvailable,
  notEnrolled,
  temporarilyLocked,
  permanentlyLocked,
  biometricOnlyNotSupported,
  userCancel,
  timeout,
  unknown,
}

/// Biometric authentication result
class BiometricAuthResult {
  final bool success;
  final BiometricType? biometricType;
  final DateTime? authenticationTime;
  final BiometricAuthError? error;
  final String? message;
  final Duration? remainingLockoutTime;
  final PlatformException? platformError;
  final bool isReused;

  const BiometricAuthResult._({
    required this.success,
    this.biometricType,
    this.authenticationTime,
    this.error,
    this.message,
    this.remainingLockoutTime,
    this.platformError,
    this.isReused = false,
  });

  factory BiometricAuthResult.success({
    required BiometricType biometricType,
    required DateTime authenticationTime,
    bool isReused = false,
  }) {
    return BiometricAuthResult._(
      success: true,
      biometricType: biometricType,
      authenticationTime: authenticationTime,
      isReused: isReused,
    );
  }

  factory BiometricAuthResult.failure({
    required BiometricAuthError error,
    required String message,
    Duration? remainingLockoutTime,
    PlatformException? platformError,
  }) {
    return BiometricAuthResult._(
      success: false,
      error: error,
      message: message,
      remainingLockoutTime: remainingLockoutTime,
      platformError: platformError,
    );
  }

  bool get isUserCancelled => error == BiometricAuthError.userCancel;
  bool get isTemporarilyLocked => error == BiometricAuthError.temporarilyLocked;
  bool get isPermanentlyLocked => error == BiometricAuthError.permanentlyLocked;
  bool get needsEnrollment => error == BiometricAuthError.notEnrolled;
  bool get isTimeout => error == BiometricAuthError.timeout;
}

/// Device biometric capabilities
class BiometricCapabilities {
  final bool isAvailable;
  final List<BiometricType> availableBiometrics;
  final bool supportsFaceID;
  final bool supportsTouchID;
  final bool supportsIris;
  final bool supportsStrongBiometrics;
  final bool supportsWeakBiometrics;

  const BiometricCapabilities({
    required this.isAvailable,
    required this.availableBiometrics,
    required this.supportsFaceID,
    required this.supportsTouchID,
    required this.supportsIris,
    required this.supportsStrongBiometrics,
    required this.supportsWeakBiometrics,
  });

  bool get hasStrongBiometrics => supportsFaceID || supportsTouchID || supportsIris;
  
  String get primaryBiometricName {
    if (supportsFaceID) return 'Face ID';
    if (supportsTouchID) return 'Touch ID';
    if (supportsIris) return 'Iris';
    if (supportsStrongBiometrics) return 'Biometric';
    return 'Authentication';
  }

  List<String> get biometricNames {
    final names = <String>[];
    if (supportsFaceID) names.add('Face ID');
    if (supportsTouchID) names.add('Touch ID');
    if (supportsIris) names.add('Iris');
    if (supportsStrongBiometrics && names.isEmpty) names.add('Biometric');
    return names;
  }
}

/// Current biometric authentication status
class BiometricAuthStatus {
  final bool isAuthenticated;
  final DateTime? lastAuthenticationTime;
  final Duration? timeUntilExpiration;
  final int failedAttempts;
  final bool isLockedOut;
  final DateTime? lockoutEndTime;

  const BiometricAuthStatus({
    required this.isAuthenticated,
    this.lastAuthenticationTime,
    this.timeUntilExpiration,
    required this.failedAttempts,
    required this.isLockedOut,
    this.lockoutEndTime,
  });

  bool get isExpired => timeUntilExpiration?.inSeconds == 0;
  bool get isExpiringSoon => timeUntilExpiration != null && 
      timeUntilExpiration!.inMinutes <= 2;
  
  String get statusDescription {
    if (isLockedOut) return 'Locked out due to failed attempts';
    if (isAuthenticated) {
      if (isExpiringSoon) return 'Authentication expires soon';
      return 'Authenticated';
    }
    return 'Not authenticated';
  }
}