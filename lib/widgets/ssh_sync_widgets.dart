/// SSH Profile Synchronization UI Widgets
/// Provides UI components for displaying sync status, handling conflicts, and managing sync operations

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ssh_sync_models.dart';
import '../providers/ssh_host_providers.dart';
import '../themes/app_theme.dart';

/// Widget that displays the current sync status
class SyncStatusWidget extends ConsumerWidget {
  final bool showDetails;
  final bool compact;

  const SyncStatusWidget({
    super.key,
    this.showDetails = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    
    if (syncState.isIdle && !showDetails) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: _buildStatusContent(context, syncState, ref),
    );
  }

  Widget _buildStatusContent(BuildContext context, SyncState syncState, WidgetRef ref) {
    if (compact) {
      return _buildCompactStatus(context, syncState, ref);
    } else {
      return _buildFullStatus(context, syncState, ref);
    }
  }

  Widget _buildCompactStatus(BuildContext context, SyncState syncState, WidgetRef ref) {
    final color = _getStatusColor(syncState.status);
    final icon = _getStatusIcon(syncState.status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 4),
        Text(
          syncState.displayMessage,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (syncState.hasConflict)
          IconButton(
            icon: const Icon(Icons.warning, color: AppTheme.terminalYellow, size: 16),
            onPressed: () => _showConflictDialog(context, ref, syncState.pendingConflict!),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
          ),
      ],
    );
  }

  Widget _buildFullStatus(BuildContext context, SyncState syncState, WidgetRef ref) {
    final color = _getStatusColor(syncState.status);
    final icon = _getStatusIcon(syncState.status);

    return Card(
      color: AppTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    syncState.displayMessage,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (syncState.isSyncing)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  ),
              ],
            ),
            if (syncState.progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  value: syncState.progress,
                  backgroundColor: AppTheme.darkBorderColor,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            if (syncState.hasConflict) ...[
              const SizedBox(height: 12),
              _buildConflictActions(context, ref, syncState.pendingConflict!),
            ],
            if (syncState.lastResult != null && showDetails) ...[
              const SizedBox(height: 8),
              _buildLastResultSummary(syncState.lastResult!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConflictActions(BuildContext context, WidgetRef ref, DataInconsistency conflict) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.terminalYellow.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.terminalYellow.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning, color: AppTheme.terminalYellow, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  conflict.description ?? 'Sync conflict detected',
                  style: const TextStyle(
                    color: AppTheme.terminalYellow,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showConflictDialog(context, ref, conflict),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  child: const Text('Resolve', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLastResultSummary(SyncResult result) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: result.success 
            ? AppTheme.terminalGreen.withAlpha(20)
            : AppTheme.terminalRed.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error,
            color: result.success ? AppTheme.terminalGreen : AppTheme.terminalRed,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              result.success
                  ? 'Synced ${result.successful} profiles successfully'
                  : result.error ?? 'Sync failed',
              style: TextStyle(
                color: result.success ? AppTheme.terminalGreen : AppTheme.terminalRed,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return AppTheme.darkTextSecondary;
      case SyncStatus.syncing:
        return AppTheme.primaryColor;
      case SyncStatus.success:
        return AppTheme.terminalGreen;
      case SyncStatus.error:
        return AppTheme.terminalRed;
      case SyncStatus.conflict:
        return AppTheme.terminalYellow;
    }
  }

  IconData _getStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icons.sync;
      case SyncStatus.syncing:
        return Icons.sync;
      case SyncStatus.success:
        return Icons.sync_alt;
      case SyncStatus.error:
        return Icons.sync_problem;
      case SyncStatus.conflict:
        return Icons.sync_problem;
    }
  }

  void _showConflictDialog(BuildContext context, WidgetRef ref, DataInconsistency conflict) {
    showDialog(
      context: context,
      builder: (context) => ConflictResolutionDialog(
        conflict: conflict,
        onResolve: (strategy) {
          Navigator.of(context).pop();
          ref.read(syncStateProvider.notifier).resolveConflict(strategy);
        },
      ),
    );
  }
}

/// Dialog for resolving sync conflicts
class ConflictResolutionDialog extends StatelessWidget {
  final DataInconsistency conflict;
  final Function(SyncStrategy) onResolve;

  const ConflictResolutionDialog({
    super.key,
    required this.conflict,
    required this.onResolve,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      title: const Row(
        children: [
          Icon(Icons.warning, color: AppTheme.terminalYellow),
          SizedBox(width: 8),
          Text(
            'Sync Conflict Detected',
            style: TextStyle(color: AppTheme.darkTextPrimary),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            conflict.description ?? 'There are conflicts between your local and server data.',
            style: const TextStyle(color: AppTheme.darkTextSecondary),
          ),
          const SizedBox(height: 16),
          _buildConflictDetails(conflict),
          const SizedBox(height: 16),
          const Text(
            'How would you like to resolve this?',
            style: TextStyle(
              color: AppTheme.darkTextPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: AppTheme.darkTextSecondary),
          ),
        ),
        if (conflict.hasLocalOnly)
          ElevatedButton(
            onPressed: () => onResolve(SyncStrategy.uploadLocal),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terminalGreen,
            ),
            child: const Text('Upload Local'),
          ),
        if (conflict.hasServerOnly)
          ElevatedButton(
            onPressed: () => onResolve(SyncStrategy.downloadRemote),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terminalBlue,
            ),
            child: const Text('Download Server'),
          ),
        if (conflict.hasConflicts)
          ElevatedButton(
            onPressed: () => onResolve(SyncStrategy.merge),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Smart Merge'),
          ),
      ],
    );
  }

  Widget _buildConflictDetails(DataInconsistency conflict) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBorderColor.withAlpha(50),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (conflict.hasLocalOnly)
            _buildConflictDetail(
              Icons.cloud_upload,
              '${conflict.localOnly.length} profile(s) only exist locally',
              AppTheme.terminalGreen,
            ),
          if (conflict.hasServerOnly)
            _buildConflictDetail(
              Icons.cloud_download,
              '${conflict.serverOnly.length} profile(s) only exist on server',
              AppTheme.terminalBlue,
            ),
          if (conflict.hasConflicts)
            _buildConflictDetail(
              Icons.merge,
              '${conflict.conflicts.length} profile(s) have conflicting changes',
              AppTheme.terminalYellow,
            ),
        ],
      ),
    );
  }

  Widget _buildConflictDetail(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sync control buttons widget
class SyncControlsWidget extends ConsumerWidget {
  final bool showFullControls;

  const SyncControlsWidget({
    super.key,
    this.showFullControls = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final syncEnabled = ref.watch(syncButtonEnabledProvider);
    final hasPendingConflicts = ref.watch(hasPendingConflictsProvider);

    if (showFullControls) {
      return _buildFullControls(context, ref, syncState, syncEnabled, hasPendingConflicts);
    } else {
      return _buildCompactControls(context, ref, syncState, syncEnabled, hasPendingConflicts);
    }
  }

  Widget _buildFullControls(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
    bool syncEnabled,
    bool hasPendingConflicts,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: syncEnabled && !hasPendingConflicts 
                ? () => ref.read(syncStateProvider.notifier).syncToServer()
                : null,
            icon: const Icon(Icons.cloud_upload, size: 16),
            label: const Text('Upload'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.terminalGreen,
              side: const BorderSide(color: AppTheme.terminalGreen),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: syncEnabled && !hasPendingConflicts
                ? () => ref.read(syncStateProvider.notifier).syncFromServer()
                : null,
            icon: const Icon(Icons.cloud_download, size: 16),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.terminalBlue,
              side: const BorderSide(color: AppTheme.terminalBlue),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: syncEnabled
                ? () => ref.read(syncStateProvider.notifier).performFullSync()
                : null,
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Sync'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactControls(
    BuildContext context,
    WidgetRef ref,
    SyncState syncState,
    bool syncEnabled,
    bool hasPendingConflicts,
  ) {
    if (hasPendingConflicts) {
      return OutlinedButton.icon(
        onPressed: () {
          final conflict = syncState.pendingConflict;
          if (conflict != null) {
            showDialog(
              context: context,
              builder: (context) => ConflictResolutionDialog(
                conflict: conflict,
                onResolve: (strategy) {
                  Navigator.of(context).pop();
                  ref.read(syncStateProvider.notifier).resolveConflict(strategy);
                },
              ),
            );
          }
        },
        icon: const Icon(Icons.warning, size: 16),
        label: const Text('Resolve'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.terminalYellow,
          side: const BorderSide(color: AppTheme.terminalYellow),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: syncEnabled
          ? () => ref.read(syncStateProvider.notifier).performFullSync()
          : null,
      icon: Icon(
        syncState.isSyncing ? Icons.sync : Icons.sync_alt,
        size: 16,
      ),
      label: Text(syncState.isSyncing ? 'Syncing...' : 'Sync'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.black,
      ),
    );
  }
}

/// Last sync time display widget
class LastSyncTimeWidget extends ConsumerWidget {
  const LastSyncTimeWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lastSyncAsync = ref.watch(lastSyncTimeProvider);

    return lastSyncAsync.when(
      data: (lastSync) {
        if (lastSync == null) {
          return const Text(
            'Never synced',
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 11,
            ),
          );
        }

        final timeAgo = _formatTimeAgo(lastSync);
        return Text(
          'Last sync: $timeAgo',
          style: const TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 11,
          ),
        );
      },
      loading: () => const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      ),
      error: (_, __) => const Text(
        'Sync time unknown',
        style: TextStyle(
          color: AppTheme.darkTextSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    
    return '${time.month}/${time.day}/${time.year}';
  }
}