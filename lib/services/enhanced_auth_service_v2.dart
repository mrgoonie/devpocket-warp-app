import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import 'api_client.dart';

/// Enhanced authentication service using the new API client
class EnhancedAuthServiceV2 {
  static EnhancedAuthServiceV2? _instance;
  static EnhancedAuthServiceV2 get instance => _instance ??= EnhancedAuthServiceV2._();
  
  final ApiClient _apiClient = ApiClient.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  
  EnhancedAuthServiceV2._();
  
  /// Check if the API server is healthy
  Future<bool> isServerHealthy() async {
    return await _apiClient.healthCheck();
  }
  
  /// Get current authenticated user
  Future<User?> getCurrentUser() async {
    try {
      final response = await _apiClient.get<User>(
        '/auth/me',
        fromJson: (json) => User.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Get current user failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }
  
  /// Register a new user
  Future<AuthResult> register({
    required String email,
    required String username,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'email': email,
          'username': username,
          'password': password,
        },
      );
      
      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final user = User.fromJson(data['user']);
        
        return AuthResult.success(
          user: user,
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );
      } else {
        return AuthResult.failure(
          error: response.errorMessage,
        );
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      return AuthResult.failure(
        error: 'Network error. Please check your connection.',
      );
    }
  }
  
  /// Login with email/username and password
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
        },
      );
      
      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final user = User.fromJson(data['user']);
        
        return AuthResult.success(
          user: user,
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );
      } else {
        return AuthResult.failure(
          error: response.errorMessage,
        );
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return AuthResult.failure(
        error: 'Network error. Please check your connection.',
      );
    }
  }
  
  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure(error: 'Google sign-in cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/auth/google',
        data: {
          'idToken': googleAuth.idToken,
          'accessToken': googleAuth.accessToken,
        },
      );
      
      if (response.isSuccess && response.data != null) {
        final data = response.data!;
        final user = User.fromJson(data['user']);
        
        return AuthResult.success(
          user: user,
          accessToken: data['accessToken'],
          refreshToken: data['refreshToken'],
        );
      } else {
        return AuthResult.failure(
          error: response.errorMessage,
        );
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return AuthResult.failure(
        error: 'Google sign-in failed. Please try again.',
      );
    }
  }
  
  /// Logout current user
  Future<bool> logout() async {
    try {
      final response = await _apiClient.post('/auth/logout');
      
      // Clear Google sign-in
      await _googleSignIn.signOut();
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Logout error: $e');
      // Still try to clear Google sign-in
      await _googleSignIn.signOut();
      return false;
    }
  }
  
  /// Request password reset
  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await _apiClient.post(
        '/auth/forgot-password',
        data: {'email': email},
      );
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Password reset request error: $e');
      return false;
    }
  }
  
  /// Reset password with token
  Future<bool> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/reset-password',
        data: {
          'token': token,
          'password': newPassword,
        },
      );
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Password reset error: $e');
      return false;
    }
  }
  
  /// Change password for authenticated user
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Change password error: $e');
      return false;
    }
  }
  
  /// Verify email with token
  Future<bool> verifyEmail(String token) async {
    try {
      final response = await _apiClient.get(
        '/auth/verify-email',
        queryParameters: {'token': token},
      );
      
      return response.isSuccess;
    } catch (e) {
      debugPrint('Email verification error: $e');
      return false;
    }
  }
  
  /// Resend email verification
  Future<bool> resendEmailVerification() async {
    try {
      final response = await _apiClient.post('/auth/resend-verification');
      return response.isSuccess;
    } catch (e) {
      debugPrint('Resend email verification error: $e');
      return false;
    }
  }
  
  /// Update user profile
  Future<User?> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? company,
    String? location,
  }) async {
    try {
      final response = await _apiClient.put<User>(
        '/auth/profile',
        data: {
          if (firstName != null) 'firstName': firstName,
          if (lastName != null) 'lastName': lastName,
          if (bio != null) 'bio': bio,
          if (company != null) 'company': company,
          if (location != null) 'location': location,
        },
        fromJson: (json) => User.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Update profile failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return null;
    }
  }
}

/// Authentication result wrapper
class AuthResult {
  final bool success;
  final User? user;
  final String? error;
  final String? accessToken;
  final String? refreshToken;

  AuthResult({
    required this.success,
    this.user,
    this.error,
    this.accessToken,
    this.refreshToken,
  });

  AuthResult.success({
    required this.user,
    this.accessToken,
    this.refreshToken,
  }) : success = true, error = null;

  AuthResult.failure({
    required this.error,
  }) : success = false, user = null, accessToken = null, refreshToken = null;
  
  @override
  String toString() {
    if (success) {
      return 'AuthResult.success(user: ${user?.username})';
    } else {
      return 'AuthResult.failure(error: $error)';
    }
  }
}