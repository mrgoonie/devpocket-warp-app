import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/api_response.dart';
import '../models/user_models.dart';
import 'api_client.dart';
import '../main.dart';

/// User profile management service
class UserService {
  static UserService? _instance;
  static UserService get instance => _instance ??= UserService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  final FlutterSecureStorage _secureStorage = AppConstants.secureStorage;
  
  UserService._();
  
  /// Get current user profile
  Future<ApiResponse<UserProfile>> getUserProfile() async {
    try {
      final response = await _apiClient.get('/users/profile');
      
      if (response.statusCode == 200) {
        final profile = UserProfile.fromJson(response.data);
        return ApiResponse.success(data: profile);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to fetch user profile',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return ApiResponse.error(message: 'Failed to fetch user profile: $e');
    }
  }
  
  /// Update user profile
  Future<ApiResponse<UserProfile>> updateUserProfile(UserProfile profile) async {
    try {
      final response = await _apiClient.put(
        '/users/profile',
        data: profile.toJson(),
      );
      
      if (response.statusCode == 200) {
        final updatedProfile = UserProfile.fromJson(response.data);
        return ApiResponse.success(data: updatedProfile);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to update profile',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return ApiResponse.error(message: 'Failed to update profile: $e');
    }
  }
  
  /// Update avatar
  Future<ApiResponse<String>> updateAvatar(List<int> imageBytes, String fileName) async {
    try {
      final response = await _apiClient.uploadFile(
        '/users/avatar',
        imageBytes,
        fileName,
        fieldName: 'avatar',
      );
      
      if (response.statusCode == 200) {
        final avatarUrl = response.data['avatar_url'] as String;
        return ApiResponse.success(data: avatarUrl);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to upload avatar',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error uploading avatar: $e');
      return ApiResponse.error(message: 'Failed to upload avatar: $e');
    }
  }
  
  /// Delete avatar
  Future<ApiResponse<void>> deleteAvatar() async {
    try {
      final response = await _apiClient.delete('/users/avatar', data: {});
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data: null);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to delete avatar',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error deleting avatar: $e');
      return ApiResponse.error(message: 'Failed to delete avatar: $e');
    }
  }
  
  /// Change password
  Future<ApiResponse<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.post('/users/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data: null);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to change password',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error changing password: $e');
      return ApiResponse.error(message: 'Failed to change password: $e');
    }
  }
  
  /// Get user preferences
  Future<ApiResponse<UserPreferences>> getUserPreferences() async {
    try {
      final response = await _apiClient.get('/users/preferences');
      
      if (response.statusCode == 200) {
        final preferences = UserPreferences.fromJson(response.data);
        return ApiResponse.success(data: preferences);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to fetch preferences',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting user preferences: $e');
      return ApiResponse.error(message: 'Failed to fetch preferences: $e');
    }
  }
  
  /// Update user preferences
  Future<ApiResponse<UserPreferences>> updateUserPreferences(UserPreferences preferences) async {
    try {
      final response = await _apiClient.put(
        '/users/preferences',
        data: preferences.toJson(),
      );
      
      if (response.statusCode == 200) {
        final updatedPreferences = UserPreferences.fromJson(response.data);
        return ApiResponse.success(data: updatedPreferences);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to update preferences',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error updating user preferences: $e');
      return ApiResponse.error(message: 'Failed to update preferences: $e');
    }
  }
  
  /// Get user device info
  Future<ApiResponse<List<UserDevice>>> getUserDevices() async {
    try {
      final response = await _apiClient.get('/users/devices');
      
      if (response.statusCode == 200) {
        final devices = (response.data['devices'] as List)
            .map((device) => UserDevice.fromJson(device))
            .toList();
        return ApiResponse.success(data: devices);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to fetch devices',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting user devices: $e');
      return ApiResponse.error(message: 'Failed to fetch devices: $e');
    }
  }
  
  /// Register current device
  Future<ApiResponse<UserDevice>> registerDevice(UserDevice device) async {
    try {
      final response = await _apiClient.post(
        '/users/devices',
        data: device.toJson(),
      );
      
      if (response.statusCode == 201) {
        final registeredDevice = UserDevice.fromJson(response.data);
        return ApiResponse.success(data: registeredDevice);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to register device',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error registering device: $e');
      return ApiResponse.error(message: 'Failed to register device: $e');
    }
  }
  
  /// Remove device
  Future<ApiResponse<void>> removeDevice(String deviceId) async {
    try {
      final response = await _apiClient.delete('/users/devices/$deviceId', data: {});
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data: null);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to remove device',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error removing device: $e');
      return ApiResponse.error(message: 'Failed to remove device: $e');
    }
  }
  
  /// Delete user account
  Future<ApiResponse<void>> deleteAccount({
    required String password,
    required String confirmationText,
  }) async {
    try {
      final response = await _apiClient.delete('/users/account', data: {
        'password': password,
        'confirmation': confirmationText,
      });
      
      if (response.statusCode == 200) {
        // Clear all local data
        await _secureStorage.deleteAll();
        return ApiResponse.success(data: null);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to delete account',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error deleting account: $e');
      return ApiResponse.error(message: 'Failed to delete account: $e');
    }
  }
}