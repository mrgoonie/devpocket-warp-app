import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user_model.dart';
import '../main.dart';
import 'auth_service.dart';

class MockAuthService extends AuthService {
  static const FlutterSecureStorage _secureStorage = AppConstants.secureStorage;
  
  // Mock user data for testing
  static final User _mockUser = User(
    id: 'mock-user-123',
    username: 'demo_user',
    email: 'demo@devpocket.app',
    avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=demo_user',
    createdAt: DateTime.now().subtract(const Duration(days: 30)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    subscriptionTier: 'pro',
    isInTrial: true,
    trialEndsAt: DateTime.now().add(const Duration(days: 14)),
    subscriptionEndsAt: DateTime.now().add(const Duration(days: 365)),
    twoFactorEnabled: false,
    emailNotifications: true,
    pushNotifications: true,
    firstName: 'Demo',
    lastName: 'User',
    bio: 'Mobile developer testing DevPocket',
    company: 'DevPocket Inc.',
    location: 'San Francisco, CA',
  );

  static final String _mockAccessToken = base64Encode(utf8.encode(json.encode({
    'user_id': _mockUser.id,
    'username': _mockUser.username,
    'exp': DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  })));

  static final String _mockRefreshToken = base64Encode(utf8.encode(json.encode({
    'user_id': _mockUser.id,
    'exp': DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000,
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  })));

  @override
  Future<bool> hasValidToken() async {
    try {
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      return token != null;
    } catch (e) {
      debugPrint('Error checking token validity: $e');
      return false;
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final token = await _secureStorage.read(key: AppConstants.accessTokenKey);
      if (token != null) {
        return _mockUser;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  @override
  Future<AuthResult> login(String username, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      // Accept any username/password combination for mock
      // But provide helpful default credentials in debug mode
      if (username.isEmpty || password.isEmpty) {
        return AuthResult.failure(
          error: 'Username and password are required',
        );
      }

      // Store mock tokens
      await _storeTokens(_mockAccessToken, _mockRefreshToken);
      await _storeUserId(_mockUser.id);

      return AuthResult.success(
        user: _mockUser,
        accessToken: _mockAccessToken,
        refreshToken: _mockRefreshToken,
      );
    } catch (e) {
      debugPrint('Mock login error: $e');
      return AuthResult.failure(
        error: 'Login failed. Please try again.',
      );
    }
  }

  @override
  Future<AuthResult> register(String email, String username, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 2000));

    try {
      if (email.isEmpty || username.isEmpty || password.isEmpty) {
        return AuthResult.failure(
          error: 'All fields are required',
        );
      }

      if (!email.contains('@')) {
        return AuthResult.failure(
          error: 'Please enter a valid email address',
        );
      }

      if (password.length < 6) {
        return AuthResult.failure(
          error: 'Password must be at least 6 characters',
        );
      }

      // Create a new user with provided details
      final newUser = _mockUser.copyWith(
        email: email,
        username: username,
        firstName: username.split('_').first,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Store mock tokens
      await _storeTokens(_mockAccessToken, _mockRefreshToken);
      await _storeUserId(newUser.id);

      return AuthResult.success(
        user: newUser,
        accessToken: _mockAccessToken,
        refreshToken: _mockRefreshToken,
      );
    } catch (e) {
      debugPrint('Mock register error: $e');
      return AuthResult.failure(
        error: 'Registration failed. Please try again.',
      );
    }
  }

  @override
  Future<AuthResult> signInWithGoogle() async {
    // Simulate Google sign-in flow
    await Future.delayed(const Duration(milliseconds: 2500));

    try {
      final googleUser = _mockUser.copyWith(
        email: 'demo.google@devpocket.app',
        username: 'demo_google_user',
        firstName: 'Google',
        lastName: 'Demo',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=google_demo',
      );

      // Store mock tokens
      await _storeTokens(_mockAccessToken, _mockRefreshToken);
      await _storeUserId(googleUser.id);

      return AuthResult.success(
        user: googleUser,
        accessToken: _mockAccessToken,
        refreshToken: _mockRefreshToken,
      );
    } catch (e) {
      debugPrint('Mock Google sign-in error: $e');
      return AuthResult.failure(
        error: 'Google sign-in failed. Please try again.',
      );
    }
  }

  @override
  Future<AuthResult> signInWithGitHub() async {
    // Simulate GitHub sign-in flow
    await Future.delayed(const Duration(milliseconds: 2500));

    try {
      final githubUser = _mockUser.copyWith(
        email: 'demo.github@devpocket.app',
        username: 'demo_github_user',
        firstName: 'GitHub',
        lastName: 'Demo',
        avatarUrl: 'https://api.dicebear.com/7.x/avataaars/svg?seed=github_demo',
        company: 'GitHub Inc.',
      );

      // Store mock tokens
      await _storeTokens(_mockAccessToken, _mockRefreshToken);
      await _storeUserId(githubUser.id);

      return AuthResult.success(
        user: githubUser,
        accessToken: _mockAccessToken,
        refreshToken: _mockRefreshToken,
      );
    } catch (e) {
      debugPrint('Mock GitHub sign-in error: $e');
      return AuthResult.failure(
        error: 'GitHub sign-in failed. Please try again.',
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Simulate server call delay
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Clear tokens
      await _clearTokens();
    } catch (e) {
      // Clear tokens even if mock server call fails
      await _clearTokens();
      debugPrint('Mock logout error: $e');
    }
  }

  @override
  Future<User?> updateProfile({
    String? firstName,
    String? lastName,
    String? bio,
    String? company,
    String? location,
  }) async {
    // Simulate server delay
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      final updatedUser = _mockUser.copyWith(
        firstName: firstName,
        lastName: lastName,
        bio: bio,
        company: company,
        location: location,
        updatedAt: DateTime.now(),
      );

      return updatedUser;
    } catch (e) {
      debugPrint('Mock update profile error: $e');
      return null;
    }
  }

  @override
  Future<bool> requestPasswordReset(String email) async {
    // Simulate server delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!email.contains('@')) {
      return false;
    }

    // Always return success for mock
    return true;
  }

  @override
  Future<bool> resetPassword(String token, String newPassword) async {
    // Simulate server delay
    await Future.delayed(const Duration(milliseconds: 1500));

    if (token.isEmpty || newPassword.length < 6) {
      return false;
    }

    // Always return success for mock
    return true;
  }

  // Private helper methods (reuse from parent class)
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

  // Utility method to get mock user for testing
  static User getMockUser() => _mockUser;
  
  // Utility method to check if we're in mock mode
  static bool get isMockMode => true;
  
  // Quick login method for testing
  Future<AuthResult> quickLogin() async {
    return login('demo', 'password123');
  }
}