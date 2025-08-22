import 'package:flutter/foundation.dart';

import '../models/ssh_profile_models.dart';
import 'api_client.dart';

/// SSH profile management service
class SshProfileService {
  static SshProfileService? _instance;
  static SshProfileService get instance => _instance ??= SshProfileService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  
  SshProfileService._();
  
  /// Get all SSH profiles for the current user
  Future<List<SshProfile>> getProfiles() async {
    try {
      final response = await _apiClient.get<List<dynamic>>(
        '/ssh/profiles',
      );
      
      if (response.isSuccess && response.data != null) {
        return response.data!
            .map((json) => SshProfile.fromJson(json))
            .toList();
      }
      
      debugPrint('Get SSH profiles failed: ${response.errorMessage}');
      return [];
    } catch (e) {
      debugPrint('Error getting SSH profiles: $e');
      return [];
    }
  }
  
  /// Get a specific SSH profile by ID
  Future<SshProfile?> getProfile(String id) async {
    try {
      final response = await _apiClient.get<SshProfile>(
        '/ssh/profiles/$id',
        fromJson: (json) => SshProfile.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Get SSH profile failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error getting SSH profile: $e');
      return null;
    }
  }
  
  /// Create a new SSH profile
  Future<SshProfile?> createProfile(SshProfile profile) async {
    try {
      final response = await _apiClient.post<SshProfile>(
        '/ssh/profiles',
        data: profile.toApiJson(),
        fromJson: (json) => SshProfile.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Create SSH profile failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error creating SSH profile: $e');
      return null;
    }
  }
  
  /// Update an existing SSH profile
  Future<SshProfile?> updateProfile(String id, SshProfile profile) async {
    try {
      final response = await _apiClient.put<SshProfile>(
        '/ssh/profiles/$id',
        data: profile.toApiJson(),
        fromJson: (json) => SshProfile.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Update SSH profile failed: ${response.errorMessage}');
      return null;
    } catch (e) {
      debugPrint('Error updating SSH profile: $e');
      return null;
    }
  }
  
  /// Delete an SSH profile
  Future<bool> deleteProfile(String id) async {
    try {
      final response = await _apiClient.delete('/ssh/profiles/$id');
      
      if (response.isSuccess) {
        return true;
      }
      
      debugPrint('Delete SSH profile failed: ${response.errorMessage}');
      return false;
    } catch (e) {
      debugPrint('Error deleting SSH profile: $e');
      return false;
    }
  }
  
  /// Test SSH connection to a profile
  Future<SshConnectionTestResult?> testConnection(SshProfile profile) async {
    try {
      final response = await _apiClient.post<SshConnectionTestResult>(
        '/ssh/test-connection',
        data: profile.toApiJson(),
        fromJson: (json) => SshConnectionTestResult.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Test SSH connection failed: ${response.errorMessage}');
      return SshConnectionTestResult(
        success: false,
        error: response.errorMessage,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error testing SSH connection: $e');
      return SshConnectionTestResult(
        success: false,
        error: 'Network error: $e',
        timestamp: DateTime.now(),
      );
    }
  }
  
  /// Validate an SSH private key
  Future<SshKeyValidationResult?> validateKey(String privateKey, {String? passphrase}) async {
    try {
      final response = await _apiClient.post<SshKeyValidationResult>(
        '/ssh/validate-key',
        data: {
          'privateKey': privateKey,
          if (passphrase != null) 'passphrase': passphrase,
        },
        fromJson: (json) => SshKeyValidationResult.fromJson(json),
      );
      
      if (response.isSuccess) {
        return response.data;
      }
      
      debugPrint('Validate SSH key failed: ${response.errorMessage}');
      return SshKeyValidationResult(
        isValid: false,
        error: response.errorMessage,
      );
    } catch (e) {
      debugPrint('Error validating SSH key: $e');
      return SshKeyValidationResult(
        isValid: false,
        error: 'Network error: $e',
      );
    }
  }
}