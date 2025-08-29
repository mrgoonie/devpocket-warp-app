import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// Handles biometric authentication for secure operations
class BiometricAuthHandler {
  final LocalAuthentication _localAuth;

  BiometricAuthHandler({
    LocalAuthentication? localAuth,
  }) : _localAuth = localAuth ?? LocalAuthentication();

  /// Check if biometric authentication is available
  Future<bool> isAvailable() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      debugPrint('❌ Failed to check biometric availability: $e');
      return false;
    }
  }

  /// Check if biometric authentication is enrolled
  Future<bool> isEnrolled() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Failed to check biometric enrollment: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('❌ Failed to get available biometrics: $e');
      return [];
    }
  }

  /// Authenticate using biometrics
  Future<bool> authenticate({
    String? localizedFallbackTitle,
    String? reason,
  }) async {
    try {
      // Check if biometrics are available
      final isAvailable = await this.isAvailable();
      if (!isAvailable) {
        debugPrint('⚠️ Biometric authentication not available');
        return false;
      }

      // Check if biometrics are enrolled
      final isEnrolled = await this.isEnrolled();
      if (!isEnrolled) {
        debugPrint('⚠️ No biometric credentials enrolled');
        return false;
      }

      // Attempt authentication
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason ?? 'Authenticate to access secure data',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );

      if (authenticated) {
        debugPrint('✅ Biometric authentication successful');
      } else {
        debugPrint('❌ Biometric authentication failed');
      }

      return authenticated;
    } catch (e) {
      debugPrint('❌ Biometric authentication error: $e');
      return false;
    }
  }

  /// Authenticate for SSH key access
  Future<bool> authenticateForSSHKey(String keyId) async {
    return await authenticate(
      reason: 'Authenticate to access SSH key: $keyId',
    );
  }

  /// Authenticate for API key access
  Future<bool> authenticateForAPIKey(String keyName) async {
    return await authenticate(
      reason: 'Authenticate to access API key: $keyName',
    );
  }

  /// Authenticate for secure data access
  Future<bool> authenticateForSecureData(String dataKey) async {
    return await authenticate(
      reason: 'Authenticate to access secure data',
    );
  }

  /// Get device biometric status
  Future<Map<String, dynamic>> getBiometricStatus() async {
    try {
      final available = await isAvailable();
      final enrolled = await isEnrolled();
      final biometrics = await getAvailableBiometrics();

      return {
        'available': available,
        'enrolled': enrolled,
        'types': biometrics.map((b) => b.name).toList(),
        'count': biometrics.length,
      };
    } catch (e) {
      debugPrint('❌ Failed to get biometric status: $e');
      return {
        'available': false,
        'enrolled': false,
        'types': <String>[],
        'count': 0,
        'error': e.toString(),
      };
    }
  }

  /// Check if biometric authentication should be required
  bool shouldRequireBiometric({
    required bool requireBiometric,
    required bool isAvailable,
    required bool isEnrolled,
  }) {
    if (!requireBiometric) return false;
    if (!isAvailable || !isEnrolled) {
      debugPrint('⚠️ Biometric required but not available/enrolled');
      return false;
    }
    return true;
  }
}