import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../models/ssh_profile_models.dart';
import '../api_client.dart';

/// SSH Profile API service for backend integration
class SshProfileApiService {
  static SshProfileApiService? _instance;
  static SshProfileApiService get instance => _instance ??= SshProfileApiService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  
  SshProfileApiService._();
  
  /// Get all SSH profiles for the authenticated user
  Future<ApiResponse<List<SshProfile>>> getProfiles() async {
    try {
      debugPrint('Fetching SSH profiles from API');
      
      final response = await _apiClient.get<List<dynamic>>(
        '/ssh/profiles',
      );
      
      if (response.isSuccess && response.data != null) {
        final profiles = response.data!
            .map((json) => SshProfile.fromJson(json as Map<String, dynamic>))
            .toList();
        
        debugPrint('Successfully fetched ${profiles.length} SSH profiles');
        return ApiResponse.success(profiles);
      }
      
      debugPrint('Failed to fetch SSH profiles: ${response.errorMessage}');
      return ApiResponse.error(
        response.errorMessage ?? 'Failed to fetch SSH profiles',
        response.statusCode,
      );
      
    } on DioException catch (e) {
      debugPrint('Network error fetching SSH profiles: ${e.message}');
      return _handleDioError<List<SshProfile>>(e);
    } catch (e) {
      debugPrint('Unexpected error fetching SSH profiles: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }
  
  /// Get a specific SSH profile by ID
  Future<ApiResponse<SshProfile>> getProfile(String id) async {
    try {
      debugPrint('Fetching SSH profile: $id');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/ssh/profiles/$id',
      );
      
      if (response.isSuccess && response.data != null) {
        final profile = SshProfile.fromJson(response.data!);
        debugPrint('Successfully fetched SSH profile: ${profile.name}');
        return ApiResponse.success(profile);
      }
      
      debugPrint('Failed to fetch SSH profile: ${response.errorMessage}');
      return ApiResponse.error(
        response.errorMessage ?? 'Profile not found',
        response.statusCode,
      );
      
    } on DioException catch (e) {
      debugPrint('Network error fetching SSH profile: ${e.message}');
      return _handleDioError<SshProfile>(e);
    } catch (e) {
      debugPrint('Unexpected error fetching SSH profile: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }
  
  /// Create a new SSH profile
  Future<ApiResponse<SshProfile>> createProfile(SshProfile profile) async {
    try {
      debugPrint('Creating SSH profile: ${profile.name}');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/ssh/profiles',
        data: profile.toApiJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final createdProfile = SshProfile.fromJson(response.data!);
        debugPrint('Successfully created SSH profile: ${createdProfile.id}');
        return ApiResponse.success(createdProfile);
      }
      
      debugPrint('Failed to create SSH profile: ${response.errorMessage}');
      return ApiResponse.error(
        response.errorMessage ?? 'Failed to create profile',
        response.statusCode,
      );
      
    } on DioException catch (e) {
      debugPrint('Network error creating SSH profile: ${e.message}');
      return _handleDioError<SshProfile>(e);
    } catch (e) {
      debugPrint('Unexpected error creating SSH profile: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }
  
  /// Update an existing SSH profile
  Future<ApiResponse<SshProfile>> updateProfile(String id, SshProfile profile) async {
    try {
      debugPrint('Updating SSH profile: $id');
      
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/ssh/profiles/$id',
        data: profile.toApiJson(),
      );
      
      if (response.isSuccess && response.data != null) {
        final updatedProfile = SshProfile.fromJson(response.data!);
        debugPrint('Successfully updated SSH profile: ${updatedProfile.id}');
        return ApiResponse.success(updatedProfile);
      }
      
      debugPrint('Failed to update SSH profile: ${response.errorMessage}');
      return ApiResponse.error(
        response.errorMessage ?? 'Failed to update profile',
        response.statusCode,
      );
      
    } on DioException catch (e) {
      debugPrint('Network error updating SSH profile: ${e.message}');
      return _handleDioError<SshProfile>(e);
    } catch (e) {
      debugPrint('Unexpected error updating SSH profile: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }
  
  /// Delete an SSH profile
  Future<ApiResponse<bool>> deleteProfile(String id) async {
    try {
      debugPrint('Deleting SSH profile: $id');
      
      final response = await _apiClient.delete('/ssh/profiles/$id');
      
      if (response.isSuccess) {
        debugPrint('Successfully deleted SSH profile: $id');
        return ApiResponse.success(true);
      }
      
      debugPrint('Failed to delete SSH profile: ${response.errorMessage}');
      return ApiResponse.error(
        response.errorMessage ?? 'Failed to delete profile',
        response.statusCode,
      );
      
    } on DioException catch (e) {
      debugPrint('Network error deleting SSH profile: ${e.message}');
      return _handleDioError<bool>(e);
    } catch (e) {
      debugPrint('Unexpected error deleting SSH profile: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }
  
  /// Test SSH connection to a profile
  Future<ApiResponse<SshConnectionTestResult>> testConnection(SshProfile profile) async {
    try {
      debugPrint('Testing SSH connection: ${profile.host}');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/ssh/test-connection',
        data: profile.toApiJson(),
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      if (response.isSuccess && response.data != null) {
        final result = SshConnectionTestResult.fromJson(response.data!);
        debugPrint('SSH connection test completed: success=${result.success}');
        return ApiResponse.success(result);
      }
      
      debugPrint('SSH connection test failed: ${response.errorMessage}');
      return ApiResponse.success(
        SshConnectionTestResult(
          success: false,
          error: response.errorMessage ?? 'Connection test failed',
          timestamp: DateTime.now(),
        ),
      );
      
    } on DioException catch (e) {
      debugPrint('Network error testing SSH connection: ${e.message}');
      return ApiResponse.success(
        SshConnectionTestResult(
          success: false,
          error: _getDioErrorMessage(e),
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('Unexpected error testing SSH connection: $e');
      return ApiResponse.success(
        SshConnectionTestResult(
          success: false,
          error: 'Unexpected error: $e',
          timestamp: DateTime.now(),
        ),
      );
    }
  }
  
  /// Validate SSH private key
  Future<ApiResponse<SshKeyValidationResult>> validateKey(
    String privateKey, {
    String? passphrase,
  }) async {
    try {
      debugPrint('Validating SSH private key');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/ssh/validate-key',
        data: {
          'private_key': privateKey,
          if (passphrase != null) 'passphrase': passphrase,
        },
      );
      
      if (response.isSuccess && response.data != null) {
        final result = SshKeyValidationResult.fromJson(response.data!);
        debugPrint('SSH key validation completed: valid=${result.isValid}');
        return ApiResponse.success(result);
      }
      
      debugPrint('SSH key validation failed: ${response.errorMessage}');
      return ApiResponse.success(
        SshKeyValidationResult(
          isValid: false,
          error: response.errorMessage ?? 'Key validation failed',
        ),
      );
      
    } on DioException catch (e) {
      debugPrint('Network error validating SSH key: ${e.message}');
      return ApiResponse.success(
        SshKeyValidationResult(
          isValid: false,
          error: _getDioErrorMessage(e),
        ),
      );
    } catch (e) {
      debugPrint('Unexpected error validating SSH key: $e');
      return ApiResponse.success(
        SshKeyValidationResult(
          isValid: false,
          error: 'Unexpected error: $e',
        ),
      );
    }
  }
  
  /// Get SSH profile statistics for the current user
  Future<ApiResponse<Map<String, dynamic>>> getProfileStats() async {
    try {
      debugPrint('Fetching SSH profile statistics');
      
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/ssh/profiles/stats',
      );
      
      if (response.isSuccess && response.data != null) {
        debugPrint('Successfully fetched SSH profile statistics');
        return ApiResponse.success(response.data!);
      }
      
      debugPrint('Failed to fetch SSH profile statistics: ${response.errorMessage}');
      return ApiResponse.error(
        response.errorMessage ?? 'Failed to fetch statistics',
        response.statusCode,
      );
      
    } on DioException catch (e) {
      debugPrint('Network error fetching SSH profile statistics: ${e.message}');
      return _handleDioError<Map<String, dynamic>>(e);
    } catch (e) {
      debugPrint('Unexpected error fetching SSH profile statistics: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }
  
  /// Sync SSH profiles with server (for offline support)
  Future<ApiResponse<SyncResult>> syncProfiles(List<SshProfile> localProfiles) async {
    try {
      debugPrint('Syncing ${localProfiles.length} SSH profiles with server');
      
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/ssh/profiles/sync',
        data: {
          'profiles': localProfiles.map((p) => p.toJson()).toList(),
          'last_sync': DateTime.now().toIso8601String(),
        },
      );
      
      if (response.isSuccess && response.data != null) {
        final result = SyncResult.fromJson(response.data!);
        debugPrint('Successfully synced SSH profiles: ${result.syncedCount} updated');
        return ApiResponse.success(result);
      }
      
      debugPrint('Failed to sync SSH profiles: ${response.errorMessage}');
      return ApiResponse.error(
        response.errorMessage ?? 'Failed to sync profiles',
        response.statusCode,
      );
      
    } on DioException catch (e) {
      debugPrint('Network error syncing SSH profiles: ${e.message}');
      return _handleDioError<SyncResult>(e);
    } catch (e) {
      debugPrint('Unexpected error syncing SSH profiles: $e');
      return ApiResponse.error('Unexpected error: $e');
    }
  }
  
  /// Handle Dio exceptions and convert to ApiResponse
  ApiResponse<T> _handleDioError<T>(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiResponse.error('Connection timeout', 408);
      
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 500;
        String message = 'Server error';
        
        try {
          final data = e.response?.data;
          if (data is Map<String, dynamic> && data.containsKey('message')) {
            message = data['message'] as String;
          } else if (data is String) {
            message = data;
          }
        } catch (_) {
          // Use default message if parsing fails
        }
        
        return ApiResponse.error(message, statusCode);
      
      case DioExceptionType.cancel:
        return ApiResponse.error('Request cancelled', 499);
      
      case DioExceptionType.connectionError:
        return ApiResponse.error('No internet connection', 0);
      
      default:
        return ApiResponse.error(e.message ?? 'Network error');
    }
  }
  
  /// Get user-friendly error message from DioException
  String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout';
      
      case DioExceptionType.badResponse:
        try {
          final data = e.response?.data;
          if (data is Map<String, dynamic> && data.containsKey('message')) {
            return data['message'] as String;
          }
        } catch (_) {}
        return 'Server error (${e.response?.statusCode ?? 'unknown'})';
      
      case DioExceptionType.cancel:
        return 'Request cancelled';
      
      case DioExceptionType.connectionError:
        return 'No internet connection';
      
      default:
        return e.message ?? 'Network error';
    }
  }
}

/// API Response wrapper
class ApiResponse<T> {
  final T? data;
  final String? error;
  final int? statusCode;
  final bool isSuccess;
  
  const ApiResponse._({
    this.data,
    this.error,
    this.statusCode,
    required this.isSuccess,
  });
  
  factory ApiResponse.success(T data) {
    return ApiResponse._(
      data: data,
      isSuccess: true,
    );
  }
  
  factory ApiResponse.error(String error, [int? statusCode]) {
    return ApiResponse._(
      error: error,
      statusCode: statusCode,
      isSuccess: false,
    );
  }
}

/// Sync result model
class SyncResult {
  final int syncedCount;
  final int conflictCount;
  final List<String> errors;
  final DateTime lastSync;
  
  const SyncResult({
    required this.syncedCount,
    required this.conflictCount,
    required this.errors,
    required this.lastSync,
  });
  
  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      syncedCount: json['synced_count'] ?? json['syncedCount'] ?? 0,
      conflictCount: json['conflict_count'] ?? json['conflictCount'] ?? 0,
      errors: List<String>.from(json['errors'] ?? []),
      lastSync: DateTime.parse(json['last_sync'] ?? json['lastSync']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'synced_count': syncedCount,
      'conflict_count': conflictCount,
      'errors': errors,
      'last_sync': lastSync.toIso8601String(),
    };
  }
}