import 'package:flutter/foundation.dart';

import 'pty_connection_manager.dart';
import 'block_focus_manager.dart';

/// Service for collecting and analyzing statistics about active blocks
class BlockStatisticsService {
  /// Get comprehensive statistics about active blocks
  static Map<String, dynamic> getBlockStatistics(
    Map<String, PtyConnection> activeBlocks,
    BlockFocusManager focusManager,
  ) {
    final stats = <String, dynamic>{};
    
    // Basic counts
    stats['totalActiveBlocks'] = activeBlocks.length;
    stats['focusedBlock'] = focusManager.focusedBlockId;
    
    // Running vs terminated blocks
    final runningBlocks = activeBlocks.values.where((c) => c.isRunning).toList();
    final terminatedBlocks = activeBlocks.values.where((c) => c.isTerminated).toList();
    
    stats['runningBlocks'] = runningBlocks.length;
    stats['terminatedBlocks'] = terminatedBlocks.length;
    
    // Process type distribution
    final typeDistribution = <String, int>{};
    for (final connection in activeBlocks.values) {
      final typeName = connection.processInfo.type.name;
      typeDistribution[typeName] = (typeDistribution[typeName] ?? 0) + 1;
    }
    stats['typeDistribution'] = typeDistribution;
    
    // Focus information
    stats.addAll(focusManager.getFocusStats());
    
    // Process characteristics
    final interactiveCount = activeBlocks.values
        .where((c) => c.processInfo.requiresInput)
        .length;
    final persistentCount = activeBlocks.values
        .where((c) => c.processInfo.isPersistent)
        .length;
    final ptyCount = activeBlocks.values
        .where((c) => c.processInfo.needsPTY)
        .length;
        
    stats['interactiveBlocks'] = interactiveCount;
    stats['persistentBlocks'] = persistentCount;
    stats['ptyBlocks'] = ptyCount;
    
    return stats;
  }

  /// Get detailed process information for all active blocks
  static List<Map<String, dynamic>> getDetailedBlockInfo(
    Map<String, PtyConnection> activeBlocks,
  ) {
    return activeBlocks.values.map((connection) {
      return {
        'blockId': connection.blockId,
        'command': connection.command,
        'processType': connection.processInfo.type.name,
        'isRunning': connection.isRunning,
        'isTerminated': connection.isTerminated,
        'requiresInput': connection.processInfo.requiresInput,
        'isPersistent': connection.processInfo.isPersistent,
        'needsPTY': connection.processInfo.needsPTY,
        'uptime': connection.uptime.inSeconds,
        'exitCode': connection.exitCode,
        'terminatedAt': connection.terminatedAt?.toIso8601String(),
        'createdAt': connection.createdAt.toIso8601String(),
        'pid': connection.process?.pid,
      };
    }).toList();
  }

  /// Get performance metrics
  static Map<String, dynamic> getPerformanceMetrics(
    Map<String, PtyConnection> activeBlocks,
  ) {
    if (activeBlocks.isEmpty) {
      return {
        'avgUptime': 0,
        'maxUptime': 0,
        'totalUptime': 0,
        'memoryEstimate': 0,
      };
    }

    final uptimes = activeBlocks.values.map((c) => c.uptime.inSeconds).toList();
    final totalUptime = uptimes.reduce((a, b) => a + b);
    final avgUptime = totalUptime / activeBlocks.length;
    final maxUptime = uptimes.reduce((a, b) => a > b ? a : b);

    // Rough memory estimate (each active block uses ~1-5MB)
    final memoryEstimate = activeBlocks.length * 3; // MB

    return {
      'avgUptime': avgUptime.round(),
      'maxUptime': maxUptime,
      'totalUptime': totalUptime,
      'memoryEstimate': memoryEstimate,
    };
  }

  /// Get health summary
  static Map<String, dynamic> getHealthSummary(
    Map<String, PtyConnection> activeBlocks,
  ) {
    var healthyCount = 0;
    var unhealthyCount = 0;
    final issues = <String>[];

    for (final connection in activeBlocks.values) {
      final isHealthy = _checkConnectionHealth(connection);
      if (isHealthy) {
        healthyCount++;
      } else {
        unhealthyCount++;
        issues.add('Block ${connection.blockId}: Health check failed');
      }
    }

    return {
      'healthyBlocks': healthyCount,
      'unhealthyBlocks': unhealthyCount,
      'healthPercentage': activeBlocks.isEmpty 
          ? 100.0 
          : (healthyCount / activeBlocks.length * 100).round(),
      'issues': issues,
    };
  }

  /// Generate a comprehensive report
  static BlockStatisticsReport generateReport(
    Map<String, PtyConnection> activeBlocks,
    BlockFocusManager focusManager,
  ) {
    final basicStats = getBlockStatistics(activeBlocks, focusManager);
    final detailedInfo = getDetailedBlockInfo(activeBlocks);
    final performance = getPerformanceMetrics(activeBlocks);
    final health = getHealthSummary(activeBlocks);

    return BlockStatisticsReport(
      timestamp: DateTime.now(),
      totalBlocks: activeBlocks.length,
      runningBlocks: basicStats['runningBlocks'] as int,
      terminatedBlocks: basicStats['terminatedBlocks'] as int,
      focusedBlockId: basicStats['focusedBlock'] as String?,
      typeDistribution: Map<String, int>.from(basicStats['typeDistribution']),
      detailedInfo: detailedInfo,
      performanceMetrics: performance,
      healthSummary: health,
    );
  }

  /// Simple health check for a connection
  static bool _checkConnectionHealth(PtyConnection connection) {
    try {
      // Check if streams are not closed unexpectedly
      if (connection.outputController.isClosed && connection.isRunning) {
        return false;
      }

      // Check if process exists when it should
      if (connection.processInfo.needsPTY && 
          connection.process == null && 
          connection.isRunning) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Health check error for ${connection.blockId}: $e');
      return false;
    }
  }
}

/// Comprehensive statistics report for active blocks
class BlockStatisticsReport {
  final DateTime timestamp;
  final int totalBlocks;
  final int runningBlocks;
  final int terminatedBlocks;
  final String? focusedBlockId;
  final Map<String, int> typeDistribution;
  final List<Map<String, dynamic>> detailedInfo;
  final Map<String, dynamic> performanceMetrics;
  final Map<String, dynamic> healthSummary;

  const BlockStatisticsReport({
    required this.timestamp,
    required this.totalBlocks,
    required this.runningBlocks,
    required this.terminatedBlocks,
    required this.focusedBlockId,
    required this.typeDistribution,
    required this.detailedInfo,
    required this.performanceMetrics,
    required this.healthSummary,
  });

  /// Convert to JSON for logging/debugging
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'totalBlocks': totalBlocks,
      'runningBlocks': runningBlocks,
      'terminatedBlocks': terminatedBlocks,
      'focusedBlockId': focusedBlockId,
      'typeDistribution': typeDistribution,
      'detailedInfo': detailedInfo,
      'performanceMetrics': performanceMetrics,
      'healthSummary': healthSummary,
    };
  }

  @override
  String toString() {
    return 'BlockStatisticsReport{total: $totalBlocks, running: $runningBlocks, focused: $focusedBlockId}';
  }
}