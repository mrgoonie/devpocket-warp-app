import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import '../main.dart';
import '../config/api_config.dart';

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
}

class AuthService {
  static String get _baseUrl => ApiConfig.fullBaseUrl;
  static const FlutterSecureStorage _secureStorage = AppConstants.secureStorage;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // HTTP client with default headers
  Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<Map<String, String>> get _authHeaders async {
    final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
    return {
      ..._defaultHeaders,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Check if user has valid token
  Future<bool> hasValidToken() async {
    try {
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      if (token == null) return false;
      
      // TODO: Validate token with server
      // For now, assume token is valid if it exists
      return true;
    } catch (e) {
      debugPrint('Error checking token validity: $e');
      return false;
    }
  }

  // Get current user from server
  Future<User?> getCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: await _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return User.fromJson(data['user']);
      } else if (response.statusCode == 401) {
        // Token expired, try to refresh
        final refreshed = await _refreshToken();
        if (refreshed) {
          return getCurrentUser();
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Login with username/password
  Future<AuthResult> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: _defaultHeaders,
        body: json.encode({
          'username': username,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        // Store tokens securely
        await _storeTokens(accessToken, refreshToken);
        await _storeUserId(user.id);

        return AuthResult.success(
          user: user,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        return AuthResult.failure(
          error: data['message'] ?? 'Login failed',
        );
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return AuthResult.failure(
        error: 'Network error. Please check your connection.',
      );
    }
  }

  // Register new user
  Future<AuthResult> register(String email, String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: _defaultHeaders,
        body: json.encode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 201) {
        final user = User.fromJson(data['user']);
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        // Store tokens securely
        await _storeTokens(accessToken, refreshToken);
        await _storeUserId(user.id);

        return AuthResult.success(
          user: user,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        return AuthResult.failure(
          error: data['message'] ?? 'Registration failed',
        );
      }
    } catch (e) {
      debugPrint('Register error: $e');
      return AuthResult.failure(
        error: 'Network error. Please check your connection.',
      );
    }
  }

  // Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure(error: 'Google sign-in cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google'),
        headers: _defaultHeaders,
        body: json.encode({
          'id_token': googleAuth.idToken,
          'access_token': googleAuth.accessToken,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        final accessToken = data['access_token'];
        final refreshToken = data['refresh_token'];

        // Store tokens securely
        await _storeTokens(accessToken, refreshToken);
        await _storeUserId(user.id);

        return AuthResult.success(
          user: user,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        return AuthResult.failure(
          error: data['message'] ?? 'Google authentication failed',
        );
      }
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return AuthResult.failure(
        error: 'Google sign-in failed. Please try again.',
      );
    }
  }

  // Sign in with GitHub (placeholder - would require GitHub OAuth flow)
  Future<AuthResult> signInWithGitHub() async {
    // TODO: Implement GitHub OAuth flow
    return AuthResult.failure(
      error: 'GitHub sign-in not yet implemented',
    );
  }

  // Logout
  Future<void> logout() async {
    try {
      // Call logout endpoint
      await http.post(
        Uri.parse('$_baseUrl/auth/logout'),
        headers: await _authHeaders,
      );

      // Clear tokens regardless of server response
      await _clearTokens();
      await _googleSignIn.signOut();
    } catch (e) {
      // Clear tokens even if server call fails
      await _clearTokens();
      debugPrint('Logout error: $e');
    }
  }

  // Update user profile
  Future<User?> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? company,
    String? location,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/auth/profile'),
        headers: await _authHeaders,
        body: json.encode({
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (bio != null) 'bio': bio,
          if (company != null) 'company': company,
          if (location != null) 'location': location,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return User.fromJson(data['user']);
      }
      
      return null;
    } catch (e) {
      debugPrint('Update profile error: $e');
      return null;
    }
  }

  // Request password reset
  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/password-reset'),
        headers: _defaultHeaders,
        body: json.encode({
          'email': email,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Password reset request error: $e');
      return false;
    }
  }

  // Reset password with token
  Future<bool> resetPassword(String token, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/password-reset/confirm'),
        headers: _defaultHeaders,
        body: json.encode({
          'token': token,
          'password': newPassword,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Password reset error: $e');
      return false;
    }
  }

  // Private helper methods
  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    await _secureStorage.write(
      key: AppConstants.accessTokenKey,
      value: accessToken,
    );
    await _secureStorage.write(
      key: AppConstants.refreshTokenKey,
      value: refreshToken,
    );
  }

  Future<void> _storeUserId(String userId) async {
    await _secureStorage.write(
      key: AppConstants.userIdKey,
      value: userId,
    );
  }

  Future<void> _clearTokens() async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.userIdKey);
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.read(key: AppConstants.refreshTokenKey);
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/refresh'),
        headers: _defaultHeaders,
        body: json.encode({
          'refresh_token': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access_token'];
        final newRefreshToken = data['refresh_token'];

        await _storeTokens(newAccessToken, newRefreshToken);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
    }
  }
}