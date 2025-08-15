import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
// Certificate pinning removed - package not available
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../models/user_model.dart';
import '../models/enhanced_ssh_models.dart';
import 'secure_storage_service.dart';
import 'biometric_service.dart';
import 'audit_service.dart';
import 'crypto_service.dart';

/// Enhanced authentication service with comprehensive security measures
class EnhancedAuthService {
  static const String _baseUrl = 'https://api.devpocket.app';
  // TODO: Implement automatic token refresh
  // static const Duration _tokenRefreshThreshold = Duration(minutes: 5);
  static const Duration _sessionTimeout = Duration(hours: 8);
  static const int _maxLoginAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 30);

  final Dio _dio;
  final SecureStorageService _secureStorage;
  final BiometricService _biometricService;
  final AuditService _auditService;
  // TODO: Implement encryption for sensitive auth data
  // final CryptoService _cryptoService;
  final DeviceInfoPlugin _deviceInfo;
  final Connectivity _connectivity;

  // Security state
  int _failedLoginAttempts = 0;
  DateTime? _lockoutUntil;
  String? _deviceFingerprint;
  String? _sessionToken;
  DateTime? _lastActivity;

  EnhancedAuthService({
    required SecureStorageService secureStorage,
    required BiometricService biometricService,
    required AuditService auditService,
    required CryptoService cryptoService,
    DeviceInfoPlugin? deviceInfo,
    Connectivity? connectivity,
    Dio? dio,
  })  : _secureStorage = secureStorage,
        _biometricService = biometricService,
        _auditService = auditService,
        // _cryptoService = cryptoService,
        _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
        _connectivity = connectivity ?? Connectivity(),
        _dio = dio ?? Dio() {
    _initializeDio();
    _initializeDeviceFingerprint();
  }

  void _initializeDio() {
    _dio.options = BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'DevPocket/1.0.0',
      },
    );

    // Certificate pinning disabled - package not available
    // TODO: Implement alternative certificate pinning solution

    // Add request/response interceptors
    _dio.interceptors.add(_createSecurityInterceptor());
  }

  Future<void> _initializeDeviceFingerprint() async {
    _deviceFingerprint = await _generateDeviceFingerprint();
  }

  /// Enhanced login with comprehensive security checks
  Future<EnhancedAuthResult> login(
    String username,
    String password, {
    bool requireBiometric = false,
    bool rememberDevice = true,
  }) async {
    // Check if account is locked
    if (_isAccountLocked()) {
      final remainingTime = _lockoutUntil!.difference(DateTime.now());
      
      await _auditService.logAuthentication(
        userId: username,
        method: AuthMethod.password,
        success: false,
        error: 'Account locked due to failed attempts',
      );
      
      return EnhancedAuthResult.failure(
        error: 'Account temporarily locked. Try again in ${remainingTime.inMinutes} minutes.',
        lockoutRemaining: remainingTime,
        securityEvent: SecurityEventType.accountLocked,
      );
    }

    // Perform security checks
    final securityCheck = await _performPreAuthSecurityChecks();
    if (!securityCheck.passed) {
      return EnhancedAuthResult.failure(
        error: securityCheck.reason ?? 'Security check failed',
        securityEvent: SecurityEventType.securityCheckFailed,
      );
    }

    try {
      // Biometric authentication if required
      if (requireBiometric) {
        final biometricResult = await _biometricService.authenticate(
          reason: 'Authenticate to login to DevPocket',
        );
        
        if (!biometricResult.success) {
          return EnhancedAuthResult.failure(
            error: 'Biometric authentication failed',
            securityEvent: SecurityEventType.biometricFailed,
          );
        }
      }

      // Prepare login request with security context
      final loginData = await _prepareLoginRequest(username, password, rememberDevice);
      
      final response = await _dio.post(
        '/auth/login',
        data: loginData,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final result = await _processSuccessfulLogin(data, username);
        
        // Reset failed attempts
        _failedLoginAttempts = 0;
        _lockoutUntil = null;
        
        await _auditService.logAuthentication(
          userId: username,
          method: AuthMethod.password,
          success: true,
          biometricUsed: requireBiometric,
        );
        
        return result;
      } else {
        return await _processFailedLogin(username, 'Invalid credentials');
      }
    } catch (e) {
      return await _processFailedLogin(username, e.toString());
    }
  }

  /// Enhanced registration with security validation
  Future<EnhancedAuthResult> register(
    String email,
    String username,
    String password, {
    bool requireBiometric = false,
  }) async {
    // Validate password strength
    final passwordValidation = _validatePasswordStrength(password);
    if (!passwordValidation.isValid) {
      return EnhancedAuthResult.failure(
        error: passwordValidation.message ?? 'Password validation failed',
        securityEvent: SecurityEventType.weakPassword,
      );
    }

    try {
      final registrationData = await _prepareRegistrationRequest(
        email,
        username,
        password,
        requireBiometric,
      );

      final response = await _dio.post(
        '/auth/register',
        data: registrationData,
      );

      if (response.statusCode == 201) {
        final data = response.data as Map<String, dynamic>;
        final result = await _processSuccessfulLogin(data, username);
        
        await _auditService.logAuthentication(
          userId: username,
          method: AuthMethod.password,
          success: true,
          biometricUsed: requireBiometric,
        );
        
        return result;
      } else {
        return EnhancedAuthResult.failure(
          error: response.data['message'] ?? 'Registration failed',
          securityEvent: SecurityEventType.registrationFailed,
        );
      }
    } catch (e) {
      return EnhancedAuthResult.failure(
        error: 'Network error: $e',
        securityEvent: SecurityEventType.networkError,
      );
    }
  }

  /// Check if user has valid session
  Future<bool> hasValidSession() async {
    try {
      final sessionData = await _getStoredSession();
      if (sessionData == null) return false;

      // Check session timeout
      final lastActivity = DateTime.parse(sessionData['last_activity']);
      if (DateTime.now().difference(lastActivity) > _sessionTimeout) {
        await _clearSession();
        return false;
      }

      // Verify token with server
      return await _verifyTokenWithServer(sessionData['access_token']);
    } catch (e) {
      debugPrint('Session validation error: $e');
      return false;
    }
  }

  /// Get current authenticated user
  Future<User?> getCurrentUser() async {
    try {
      final sessionData = await _getStoredSession();
      if (sessionData == null) return null;

      await _updateLastActivity();

      final response = await _dio.get(
        '/auth/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${sessionData['access_token']}',
          },
        ),
      );

      if (response.statusCode == 200) {
        return User.fromJson(response.data['user']);
      }
      
      return null;
    } catch (e) {
      debugPrint('Get current user error: $e');
      return null;
    }
  }

  /// Secure logout with session cleanup
  Future<void> logout() async {
    try {
      final sessionData = await _getStoredSession();
      
      if (sessionData != null) {
        // Notify server of logout
        await _dio.post(
          '/auth/logout',
          options: Options(
            headers: {
              'Authorization': 'Bearer ${sessionData['access_token']}',
            },
          ),
        );
      }
      
      await _clearSession();
      
      await _auditService.logAuthentication(
        userId: sessionData?['user_id'] ?? 'unknown',
        method: AuthMethod.password,
        success: true,
      );
    } catch (e) {
      // Still clear session even if server call fails
      await _clearSession();
      debugPrint('Logout error: $e');
    }
  }

  /// Refresh authentication token
  Future<bool> refreshToken() async {
    try {
      final sessionData = await _getStoredSession();
      if (sessionData == null || sessionData['refresh_token'] == null) {
        return false;
      }

      final response = await _dio.post(
        '/auth/refresh',
        data: {
          'refresh_token': sessionData['refresh_token'],
          'device_fingerprint': _deviceFingerprint,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        
        await _storeSession(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          userId: sessionData['user_id'],
        );
        
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }

  /// Change password with security validation
  Future<bool> changePassword(
    String currentPassword,
    String newPassword, {
    bool requireBiometric = true,
  }) async {
    // Validate new password strength
    final passwordValidation = _validatePasswordStrength(newPassword);
    if (!passwordValidation.isValid) {
      throw AuthException(passwordValidation.message ?? 'Password validation failed');
    }

    // Require biometric authentication for password change
    if (requireBiometric) {
      final biometricResult = await _biometricService.authenticate(
        reason: 'Authenticate to change password',
      );
      
      if (!biometricResult.success) {
        throw AuthException('Biometric authentication required');
      }
    }

    try {
      final sessionData = await _getStoredSession();
      if (sessionData == null) throw AuthException('Not authenticated');

      final response = await _dio.put(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
          'device_fingerprint': _deviceFingerprint,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer ${sessionData['access_token']}',
          },
        ),
      );

      final success = response.statusCode == 200;
      
      await _auditService.logSystemEvent(
        event: 'password_change',
        success: success,
        data: {'user_id': sessionData['user_id']},
      );
      
      return success;
    } catch (e) {
      throw AuthException('Failed to change password: $e');
    }
  }

  /// Enable/disable two-factor authentication
  Future<TwoFactorSetupResult> setupTwoFactor() async {
    try {
      final sessionData = await _getStoredSession();
      if (sessionData == null) throw AuthException('Not authenticated');

      final response = await _dio.post(
        '/auth/2fa/setup',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${sessionData['access_token']}',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        
        return TwoFactorSetupResult(
          success: true,
          qrCodeData: data['qr_code'],
          backupCodes: List<String>.from(data['backup_codes'] ?? []),
          secret: data['secret'],
        );
      }
      
      return TwoFactorSetupResult(success: false);
    } catch (e) {
      throw AuthException('Failed to setup 2FA: $e');
    }
  }

  /// Get authentication security status
  AuthSecurityStatus getSecurityStatus() {
    final hasValidSession = _sessionToken != null;
    final sessionAge = _lastActivity != null 
        ? DateTime.now().difference(_lastActivity!)
        : null;
    
    return AuthSecurityStatus(
      isAuthenticated: hasValidSession,
      sessionAge: sessionAge,
      failedAttempts: _failedLoginAttempts,
      isLocked: _isAccountLocked(),
      lockoutRemaining: _isAccountLocked() 
          ? _lockoutUntil!.difference(DateTime.now())
          : null,
      biometricAvailable: true, // Would check actual availability
      deviceTrusted: _deviceFingerprint != null,
    );
  }

  // Private helper methods

  Future<SecurityCheckResult> _performPreAuthSecurityChecks() async {
    // Check network security
    final networkResult = await _checkNetworkSecurity();
    if (!networkResult.isSecure) {
      return SecurityCheckResult(
        passed: false,
        reason: 'Insecure network connection detected',
      );
    }

    // Check device integrity
    final deviceResult = await _checkDeviceIntegrity();
    if (!deviceResult.isTrusted) {
      return SecurityCheckResult(
        passed: false,
        reason: 'Device security compromise detected',
      );
    }

    return SecurityCheckResult(passed: true);
  }

  Future<NetworkSecurityResult> _checkNetworkSecurity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      final connectivityResult = connectivityResults.isNotEmpty 
          ? connectivityResults.first 
          : ConnectivityResult.none;
      
      // Warn about public networks
      final isSecure = connectivityResult != ConnectivityResult.wifi ||
          await _isPrivateNetwork();
      
      return NetworkSecurityResult(
        isSecure: isSecure,
        connectionType: connectivityResult,
      );
    } catch (e) {
      return NetworkSecurityResult(isSecure: false);
    }
  }

  Future<bool> _isPrivateNetwork() async {
    // In a real implementation, this would check if connected to a trusted network
    return true;
  }

  Future<DeviceIntegrityResult> _checkDeviceIntegrity() async {
    try {
      // Check for jailbreak/root (simplified)
      final isRooted = await _checkForRootAccess();
      final isDebugging = await _checkForDebugging();
      
      return DeviceIntegrityResult(
        isTrusted: !isRooted && !isDebugging,
        isRooted: isRooted,
        isDebugging: isDebugging,
      );
    } catch (e) {
      return DeviceIntegrityResult(isTrusted: false);
    }
  }

  Future<bool> _checkForRootAccess() async {
    // Simplified root detection
    const rootPaths = [
      '/system/app/Superuser.apk',
      '/sbin/su',
      '/system/bin/su',
      '/system/xbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
    ];
    
    for (final path in rootPaths) {
      if (await File(path).exists()) return true;
    }
    
    return false;
  }

  Future<bool> _checkForDebugging() async {
    // Check for debugging flags or tools
    return false; // Simplified implementation
  }

  Future<String> _generateDeviceFingerprint() async {
    try {
      final deviceData = <String, dynamic>{};
      
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceData.addAll({
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'id': androidInfo.id,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceData.addAll({
          'model': iosInfo.model,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'identifierForVendor': iosInfo.identifierForVendor ?? 'unknown',
        });
      }
      
      final fingerprintString = json.encode(deviceData);
      final bytes = utf8.encode(fingerprintString);
      final digest = sha256.convert(bytes);
      
      return digest.toString();
    } catch (e) {
      // Fallback fingerprint
      return 'fallback-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<Map<String, dynamic>> _prepareLoginRequest(
    String username,
    String password,
    bool rememberDevice,
  ) async {
    return {
      'username': username,
      'password': password,
      'device_fingerprint': _deviceFingerprint,
      'remember_device': rememberDevice,
      'client_info': {
        'app_version': '1.0.0',
        'platform': Platform.operatingSystem,
        'timestamp': DateTime.now().toIso8601String(),
      },
    };
  }

  Future<Map<String, dynamic>> _prepareRegistrationRequest(
    String email,
    String username,
    String password,
    bool requireBiometric,
  ) async {
    return {
      'email': email,
      'username': username,
      'password': password,
      'device_fingerprint': _deviceFingerprint,
      'biometric_enabled': requireBiometric,
      'client_info': {
        'app_version': '1.0.0',
        'platform': Platform.operatingSystem,
        'timestamp': DateTime.now().toIso8601String(),
      },
    };
  }

  Future<EnhancedAuthResult> _processSuccessfulLogin(
    Map<String, dynamic> data,
    String username,
  ) async {
    final user = User.fromJson(data['user']);
    final accessToken = data['access_token'];
    final refreshToken = data['refresh_token'];

    await _storeSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      userId: user.id,
    );

    _sessionToken = accessToken;
    _lastActivity = DateTime.now();

    return EnhancedAuthResult.success(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      securityLevel: SecurityLevel.high,
    );
  }

  Future<EnhancedAuthResult> _processFailedLogin(
    String username,
    String error,
  ) async {
    _failedLoginAttempts++;
    
    if (_failedLoginAttempts >= _maxLoginAttempts) {
      _lockoutUntil = DateTime.now().add(_lockoutDuration);
    }

    await _auditService.logAuthentication(
      userId: username,
      method: AuthMethod.password,
      success: false,
      error: error,
    );

    return EnhancedAuthResult.failure(
      error: error,
      securityEvent: SecurityEventType.loginFailed,
      lockoutRemaining: _isAccountLocked() 
          ? _lockoutUntil!.difference(DateTime.now())
          : null,
    );
  }

  PasswordValidationResult _validatePasswordStrength(String password) {
    if (password.length < 12) {
      return PasswordValidationResult(
        isValid: false,
        message: 'Password must be at least 12 characters long',
      );
    }

    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasDigit = password.contains(RegExp(r'\d'));
    final hasSymbol = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    final missingRequirements = <String>[];
    if (!hasLower) missingRequirements.add('lowercase letter');
    if (!hasUpper) missingRequirements.add('uppercase letter');
    if (!hasDigit) missingRequirements.add('number');
    if (!hasSymbol) missingRequirements.add('special character');

    if (missingRequirements.isNotEmpty) {
      return PasswordValidationResult(
        isValid: false,
        message: 'Password must contain: ${missingRequirements.join(', ')}',
      );
    }

    return PasswordValidationResult(isValid: true);
  }

  Future<void> _storeSession({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    final sessionData = {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'user_id': userId,
      'last_activity': DateTime.now().toIso8601String(),
    };

    await _secureStorage.storeSecure(
      key: 'user_session',
      value: json.encode(sessionData),
      requireBiometric: false,
    );
  }

  Future<Map<String, dynamic>?> _getStoredSession() async {
    final sessionJson = await _secureStorage.getSecure('user_session');
    if (sessionJson == null) return null;
    
    return json.decode(sessionJson);
  }

  Future<void> _updateLastActivity() async {
    final sessionData = await _getStoredSession();
    if (sessionData != null) {
      sessionData['last_activity'] = DateTime.now().toIso8601String();
      await _secureStorage.storeSecure(
        key: 'user_session',
        value: json.encode(sessionData),
        requireBiometric: false,
      );
    }
  }

  Future<void> _clearSession() async {
    await _secureStorage.deleteKey('user_session');
    _sessionToken = null;
    _lastActivity = null;
  }

  Future<bool> _verifyTokenWithServer(String token) async {
    try {
      final response = await _dio.get(
        '/auth/verify',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  bool _isAccountLocked() {
    return _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
  }

  InterceptorsWrapper _createSecurityInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add security headers
        options.headers['X-Requested-With'] = 'XMLHttpRequest';
        options.headers['X-Device-Fingerprint'] = _deviceFingerprint;
        
        handler.next(options);
      },
      onResponse: (response, handler) {
        // Log successful responses
        handler.next(response);
      },
      onError: (error, handler) {
        // Log and handle errors
        debugPrint('API Error: ${error.message}');
        handler.next(error);
      },
    );
  }
}

// Supporting classes and enums

class EnhancedAuthResult {
  final bool success;
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final String? error;
  final SecurityLevel? securityLevel;
  final SecurityEventType? securityEvent;
  final Duration? lockoutRemaining;

  const EnhancedAuthResult._({
    required this.success,
    this.user,
    this.accessToken,
    this.refreshToken,
    this.error,
    this.securityLevel,
    this.securityEvent,
    this.lockoutRemaining,
  });

  factory EnhancedAuthResult.success({
    required User user,
    required String accessToken,
    required String refreshToken,
    SecurityLevel securityLevel = SecurityLevel.medium,
  }) {
    return EnhancedAuthResult._(
      success: true,
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      securityLevel: securityLevel,
    );
  }

  factory EnhancedAuthResult.failure({
    required String error,
    SecurityEventType? securityEvent,
    Duration? lockoutRemaining,
  }) {
    return EnhancedAuthResult._(
      success: false,
      error: error,
      securityEvent: securityEvent,
      lockoutRemaining: lockoutRemaining,
    );
  }
}

enum SecurityEventType {
  loginFailed,
  accountLocked,
  biometricFailed,
  securityCheckFailed,
  networkError,
  registrationFailed,
  weakPassword,
}

class SecurityCheckResult {
  final bool passed;
  final String? reason;

  const SecurityCheckResult({
    required this.passed,
    this.reason,
  });
}

class NetworkSecurityResult {
  final bool isSecure;
  final ConnectivityResult? connectionType;

  const NetworkSecurityResult({
    required this.isSecure,
    this.connectionType,
  });
}

class DeviceIntegrityResult {
  final bool isTrusted;
  final bool isRooted;
  final bool isDebugging;

  const DeviceIntegrityResult({
    required this.isTrusted,
    this.isRooted = false,
    this.isDebugging = false,
  });
}

class PasswordValidationResult {
  final bool isValid;
  final String? message;

  const PasswordValidationResult({
    required this.isValid,
    this.message,
  });
}

class TwoFactorSetupResult {
  final bool success;
  final String? qrCodeData;
  final List<String>? backupCodes;
  final String? secret;

  const TwoFactorSetupResult({
    required this.success,
    this.qrCodeData,
    this.backupCodes,
    this.secret,
  });
}

class AuthSecurityStatus {
  final bool isAuthenticated;
  final Duration? sessionAge;
  final int failedAttempts;
  final bool isLocked;
  final Duration? lockoutRemaining;
  final bool biometricAvailable;
  final bool deviceTrusted;

  const AuthSecurityStatus({
    required this.isAuthenticated,
    this.sessionAge,
    required this.failedAttempts,
    required this.isLocked,
    this.lockoutRemaining,
    required this.biometricAvailable,
    required this.deviceTrusted,
  });

  bool get isSecure => isAuthenticated && deviceTrusted && !isLocked;
}

class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, [this.code]);

  @override
  String toString() => 'AuthException: $message';
}