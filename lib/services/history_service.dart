import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/api_response.dart';
import '../models/command_history_models.dart';
import 'api_client.dart';

/// Command history API service
class HistoryService {
  static HistoryService? _instance;
  static HistoryService get instance => _instance ??= HistoryService._();
  
  final ApiClient _apiClient = ApiClient.instance;
  
  HistoryService._();
  
  /// Get command history with filters
  Future<ApiResponse<List<CommandHistoryEntry>>> getHistory({
    CommandHistoryFilter? filter,
  }) async {
    try {
      final queryParams = filter?.toQueryParams() ?? {};
      
      final response = await _apiClient.get('/history/commands', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final historyData = response.data['commands'] as List;
        final history = historyData
            .map((entry) => CommandHistoryEntry.fromJson(entry))
            .toList();
        
        return ApiResponse.success(data: history);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to fetch command history',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting command history: $e');
      return ApiResponse.error(message: 'Failed to fetch command history: $e');
    }
  }
  
  /// Get command history entry by ID
  Future<ApiResponse<CommandHistoryEntry>> getHistoryEntry(String entryId) async {
    try {
      final response = await _apiClient.get('/history/commands/$entryId');
      
      if (response.statusCode == 200) {
        final entry = CommandHistoryEntry.fromJson(response.data);
        return ApiResponse.success(data: entry);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to fetch command entry',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting command entry: $e');
      return ApiResponse.error(message: 'Failed to fetch command entry: $e');
    }
  }
  
  /// Add command to history
  Future<ApiResponse<CommandHistoryEntry>> addHistoryEntry(CommandHistoryEntry entry) async {
    try {
      final response = await _apiClient.post('/history/commands', data: entry.toJson());
      
      if (response.statusCode == 201) {
        final createdEntry = CommandHistoryEntry.fromJson(response.data);
        return ApiResponse.success(data: createdEntry);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to add command to history',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error adding command to history: $e');
      return ApiResponse.error(message: 'Failed to add command to history: $e');
    }
  }
  
  /// Update command history entry
  Future<ApiResponse<CommandHistoryEntry>> updateHistoryEntry(
    String entryId, 
    CommandHistoryEntry entry,
  ) async {
    try {
      final response = await _apiClient.put('/history/commands/$entryId', data: entry.toJson());
      
      if (response.statusCode == 200) {
        final updatedEntry = CommandHistoryEntry.fromJson(response.data);
        return ApiResponse.success(data: updatedEntry);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to update command entry',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error updating command entry: $e');
      return ApiResponse.error(message: 'Failed to update command entry: $e');
    }
  }
  
  /// Delete command history entry
  Future<ApiResponse<void>> deleteHistoryEntry(String entryId) async {
    try {
      final response = await _apiClient.delete('/history/commands/$entryId');
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data: null);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to delete command entry',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error deleting command entry: $e');
      return ApiResponse.error(message: 'Failed to delete command entry: $e');
    }
  }
  
  /// Toggle favorite status
  Future<ApiResponse<CommandHistoryEntry>> toggleFavorite(String entryId, bool isFavorite) async {
    try {
      final response = await _apiClient.put('/history/commands/$entryId/favorite', data: {
        'is_favorite': isFavorite,
      });
      
      if (response.statusCode == 200) {
        final updatedEntry = CommandHistoryEntry.fromJson(response.data);
        return ApiResponse.success(data: updatedEntry);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to update favorite status',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      return ApiResponse.error(message: 'Failed to update favorite status: $e');
    }
  }
  
  /// Add tags to command
  Future<ApiResponse<CommandHistoryEntry>> addTags(String entryId, List<String> tags) async {
    try {
      final response = await _apiClient.put('/history/commands/$entryId/tags', data: {
        'tags': tags,
      });
      
      if (response.statusCode == 200) {
        final updatedEntry = CommandHistoryEntry.fromJson(response.data);
        return ApiResponse.success(data: updatedEntry);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to add tags',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error adding tags: $e');
      return ApiResponse.error(message: 'Failed to add tags: $e');
    }
  }
  
  /// Remove tags from command
  Future<ApiResponse<CommandHistoryEntry>> removeTags(String entryId, List<String> tags) async {
    try {
      final response = await _apiClient.delete('/history/commands/$entryId/tags', data: {
        'tags': tags,
      });
      
      if (response.statusCode == 200) {
        final updatedEntry = CommandHistoryEntry.fromJson(response.data);
        return ApiResponse.success(data: updatedEntry);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to remove tags',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error removing tags: $e');
      return ApiResponse.error(message: 'Failed to remove tags: $e');
    }
  }
  
  /// Get command history statistics
  Future<ApiResponse<CommandHistoryStats>> getHistoryStats({
    DateTime? startDate,
    DateTime? endDate,
    String? deviceId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }
      
      if (deviceId != null) {
        queryParams['device_id'] = deviceId;
      }
      
      final response = await _apiClient.get('/history/stats', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final stats = CommandHistoryStats.fromJson(response.data);
        return ApiResponse.success(data: stats);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to fetch history statistics',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting history stats: $e');
      return ApiResponse.error(message: 'Failed to fetch history statistics: $e');
    }
  }
  
  /// Search command history
  Future<ApiResponse<List<CommandHistoryEntry>>> searchHistory({
    required String query,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get('/history/search', queryParameters: {
        'query': query,
        'limit': limit.toString(),
      });
      
      if (response.statusCode == 200) {
        final historyData = response.data['commands'] as List;
        final history = historyData
            .map((entry) => CommandHistoryEntry.fromJson(entry))
            .toList();
        
        return ApiResponse.success(data: history);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to search command history',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error searching command history: $e');
      return ApiResponse.error(message: 'Failed to search command history: $e');
    }
  }
  
  /// Get recent commands
  Future<ApiResponse<List<CommandHistoryEntry>>> getRecentCommands({
    int limit = 10,
    String? sessionId,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit.toString(),
        'sort_by': 'executed_at',
        'sort_desc': 'true',
      };
      
      if (sessionId != null) {
        queryParams['session_id'] = sessionId;
      }
      
      final response = await _apiClient.get('/history/recent', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        final historyData = response.data['commands'] as List;
        final history = historyData
            .map((entry) => CommandHistoryEntry.fromJson(entry))
            .toList();
        
        return ApiResponse.success(data: history);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to fetch recent commands',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting recent commands: $e');
      return ApiResponse.error(message: 'Failed to fetch recent commands: $e');
    }
  }
  
  /// Get favorite commands
  Future<ApiResponse<List<CommandHistoryEntry>>> getFavoriteCommands({
    int limit = 20,
  }) async {
    try {
      final filter = CommandHistoryFilter(
        favoritesOnly: true,
        limit: limit,
        sortBy: 'executed_at',
        sortDescending: true,
      );
      
      return await getHistory(filter: filter);
    } catch (e) {
      debugPrint('Error getting favorite commands: $e');
      return ApiResponse.error(message: 'Failed to fetch favorite commands: $e');
    }
  }
  
  /// Bulk delete history entries
  Future<ApiResponse<void>> bulkDeleteHistory(List<String> entryIds) async {
    try {
      final response = await _apiClient.delete('/history/commands/bulk', data: {
        'entry_ids': entryIds,
      });
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data: null);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to delete history entries',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error bulk deleting history: $e');
      return ApiResponse.error(message: 'Failed to delete history entries: $e');
    }
  }
  
  /// Clear all history
  Future<ApiResponse<void>> clearHistory({
    DateTime? beforeDate,
    String? sessionId,
  }) async {
    try {
      final data = <String, dynamic>{};
      
      if (beforeDate != null) {
        data['before_date'] = beforeDate.toIso8601String();
      }
      
      if (sessionId != null) {
        data['session_id'] = sessionId;
      }
      
      final response = await _apiClient.delete('/history/commands', data: data);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data: null);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to clear command history',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error clearing history: $e');
      return ApiResponse.error(message: 'Failed to clear command history: $e');
    }
  }
  
  /// Export history
  Future<ApiResponse<Map<String, dynamic>>> exportHistory({
    String format = 'json',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'format': format,
      };
      
      if (startDate != null) {
        queryParams['start_date'] = startDate.toIso8601String();
      }
      
      if (endDate != null) {
        queryParams['end_date'] = endDate.toIso8601String();
      }
      
      final response = await _apiClient.get('/history/export', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data: response.data);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to export history',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error exporting history: $e');
      return ApiResponse.error(message: 'Failed to export history: $e');
    }
  }
  
  /// Get history sync status
  Future<ApiResponse<CommandHistorySyncStatus>> getSyncStatus() async {
    try {
      final response = await _apiClient.get('/history/sync/status');
      
      if (response.statusCode == 200) {
        final status = CommandHistorySyncStatus.fromJson(response.data);
        return ApiResponse.success(data: status);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to fetch sync status',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error getting sync status: $e');
      return ApiResponse.error(message: 'Failed to fetch sync status: $e');
    }
  }
  
  /// Trigger history sync
  Future<ApiResponse<void>> triggerSync() async {
    try {
      final response = await _apiClient.post('/history/sync/trigger', data: {});
      
      if (response.statusCode == 200) {
        return ApiResponse.success(data: null);
      } else {
        return ApiResponse.error(
          message: response.data?['message'] ?? 'Failed to trigger sync',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('Error triggering sync: $e');
      return ApiResponse.error(message: 'Failed to trigger sync: $e');
    }
  }
}