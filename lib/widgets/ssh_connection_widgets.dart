import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ssh_connection_error.dart';
import '../services/network_monitor.dart';
import '../themes/app_theme.dart';

/// Comprehensive connection status widget with health indicators
class SshConnectionStatusWidget extends ConsumerWidget {
  final String? sessionId;
  final SshConnectionStep? currentStep;
  final double? progress; // 0.0 to 1.0
  final SshHealthMetrics? healthMetrics;
  final VoidCallback? onDisconnect;
  final VoidCallback? onReconnect;
  final bool showDetails;

  const SshConnectionStatusWidget({
    super.key,
    this.sessionId,
    this.currentStep,
    this.progress,
    this.healthMetrics,
    this.onDisconnect,
    this.onReconnect,
    this.showDetails = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with connection status
          _buildStatusHeader(context),
          
          if (currentStep != null || progress != null) ...[
            const SizedBox(height: 12),
            _buildProgressSection(context),
          ],
          
          if (healthMetrics != null) ...[
            const SizedBox(height: 12),
            _buildHealthSection(context),
          ],
          
          if (showDetails && sessionId != null) ...[
            const SizedBox(height: 12),
            _buildDetailsSection(context),
          ],
          
          if (onDisconnect != null || onReconnect != null) ...[
            const SizedBox(height: 12),
            _buildActionButtons(context),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context) {
    final isConnected = currentStep == SshConnectionStep.connected;
    final isConnecting = currentStep != null && currentStep != SshConnectionStep.connected;
    
    return Row(
      children: [
        // Status icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(isConnected, isConnecting).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getStatusIcon(isConnected, isConnecting),
            color: _getStatusColor(isConnected, isConnecting),
            size: 20,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Status text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStatusTitle(isConnected, isConnecting),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (currentStep != null) ...[
                const SizedBox(height: 2),
                Text(
                  currentStep!.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Health indicator
        if (healthMetrics != null)
          _buildHealthIndicator(context, healthMetrics!),
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (progress != null) ...[
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              _getStatusColor(false, true),
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        if (currentStep != null) ...[
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getStatusColor(false, true),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currentStep!.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildHealthSection(BuildContext context) {
    final metrics = healthMetrics!;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_heart, size: 16),
              const SizedBox(width: 8),
              Text(
                'Connection Health',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildHealthMetric(
                  context,
                  'Quality',
                  metrics.quality.displayName,
                  metrics.quality.emoji,
                ),
              ),
              Expanded(
                child: _buildHealthMetric(
                  context,
                  'Latency',
                  '${metrics.latencyMs.round()}ms',
                  '⚡',
                ),
              ),
              Expanded(
                child: _buildHealthMetric(
                  context,
                  'Score',
                  '${metrics.healthScore}%',
                  metrics.isHealthy ? '✅' : '⚠️',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(BuildContext context, String label, String value, String emoji) {
    return Column(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).hintColor,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return ExpansionTile(
      title: const Text('Connection Details'),
      children: [
        ListTile(
          leading: const Icon(Icons.fingerprint),
          title: const Text('Session ID'),
          subtitle: Text(sessionId!),
          trailing: IconButton(
            onPressed: () => _copyToClipboard(context, sessionId!),
            icon: const Icon(Icons.copy),
          ),
        ),
        if (healthMetrics != null) ...[
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Last Health Check'),
            subtitle: Text(_formatDateTime(healthMetrics!.lastHealthCheck)),
          ),
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Consecutive Failures'),
            subtitle: Text('${healthMetrics!.consecutiveFailures}'),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        if (onReconnect != null) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onReconnect,
              icon: const Icon(Icons.refresh),
              label: const Text('Reconnect'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (onDisconnect != null) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onDisconnect,
              icon: const Icon(Icons.close),
              label: const Text('Disconnect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHealthIndicator(BuildContext context, SshHealthMetrics metrics) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getHealthColor(metrics.quality).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getHealthColor(metrics.quality).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metrics.quality.emoji,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 4),
          Text(
            '${metrics.latencyMs.round()}ms',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _getHealthColor(metrics.quality),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(bool isConnected, bool isConnecting) {
    if (isConnected) return Colors.green;
    if (isConnecting) return AppTheme.primaryColor;
    return Colors.grey;
  }

  IconData _getStatusIcon(bool isConnected, bool isConnecting) {
    if (isConnected) return Icons.check_circle;
    if (isConnecting) return Icons.access_time;
    return Icons.error_outline;
  }

  String _getStatusTitle(bool isConnected, bool isConnecting) {
    if (isConnected) return 'Connected';
    if (isConnecting) return 'Connecting';
    return 'Disconnected';
  }

  Color _getHealthColor(SshConnectionQuality quality) {
    switch (quality) {
      case SshConnectionQuality.excellent:
        return Colors.green;
      case SshConnectionQuality.good:
        return Colors.lightGreen;
      case SshConnectionQuality.fair:
        return Colors.orange;
      case SshConnectionQuality.poor:
        return Colors.red;
      case SshConnectionQuality.critical:
        return Colors.red.shade900;
      case SshConnectionQuality.unknown:
        return Colors.grey;
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard')),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }
}

/// Enhanced error dialog with actionable suggestions
class SshConnectionErrorDialog extends StatelessWidget {
  final SshConnectionError error;
  final VoidCallback? onRetry;
  final VoidCallback? onEditSettings;
  final VoidCallback? onTestConnection;
  final VoidCallback? onClose;

  const SshConnectionErrorDialog({
    super.key,
    required this.error,
    this.onRetry,
    this.onEditSettings,
    this.onTestConnection,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
          ),
          SizedBox(width: 8),
          Text('Connection Failed'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // User-friendly error message
            Text(
              error.userFriendlyMessage,
              style: const TextStyle(fontSize: 16),
            ),
            
            const SizedBox(height: 16),
            
            // Suggested actions
            if (error.suggestedActions.isNotEmpty) ...[
              const Text(
                'Suggested Actions:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              ...error.suggestedActions.map(
                (action) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(action)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Technical details (expandable)
            ExpansionTile(
              title: const Text(
                'Technical Details',
                style: TextStyle(fontSize: 14),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Error Type: ${error.type.toString().split('.').last}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Message: ${error.technicalMessage}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Time: ${error.timestamp.toString()}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _copyErrorDetails(context),
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Details'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        // Close button
        TextButton(
          onPressed: onClose ?? () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        
        // Action buttons based on error type
        if (onEditSettings != null && _shouldShowEditSettings()) ...[
          TextButton(
            onPressed: onEditSettings,
            child: const Text('Edit Settings'),
          ),
        ],
        
        if (onTestConnection != null) ...[
          TextButton(
            onPressed: onTestConnection,
            child: const Text('Test Connection'),
          ),
        ],
        
        if (onRetry != null && error.isRetryable) ...[
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ],
    );
  }

  bool _shouldShowEditSettings() {
    return error.type == SshErrorType.invalidCredentials ||
           error.type == SshErrorType.authenticationFailed ||
           error.type == SshErrorType.invalidConfiguration ||
           error.type == SshErrorType.missingCredentials ||
           error.type == SshErrorType.invalidPrivateKey;
  }

  void _copyErrorDetails(BuildContext context) {
    final details = '''
Error Type: ${error.type.toString().split('.').last}
Message: ${error.technicalMessage}
Time: ${error.timestamp}
Retryable: ${error.isRetryable}
${error.debugInfo != null ? 'Debug Info: ${error.debugInfo}' : ''}
''';
    
    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Error details copied to clipboard')),
    );
  }
}

/// Connection progress indicator with step visualization
class SshConnectionProgressIndicator extends StatelessWidget {
  final SshConnectionStep currentStep;
  final double? progress; // 0.0 to 1.0
  final bool showCancel;
  final VoidCallback? onCancel;

  const SshConnectionProgressIndicator({
    super.key,
    required this.currentStep,
    this.progress,
    this.showCancel = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final steps = SshConnectionStep.values.where(
      (step) => step != SshConnectionStep.connected,
    ).toList();
    
    final currentIndex = steps.indexOf(currentStep);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.sync, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Connecting...',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (showCancel && onCancel != null)
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel'),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Progress bar
          if (progress != null) ...[
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
          ],
          
          // Step indicators
          Column(
            children: steps.map((step) {
              final stepIndex = steps.indexOf(step);
              final isCompleted = stepIndex < currentIndex;
              final isCurrent = stepIndex == currentIndex;
              final isUpcoming = stepIndex > currentIndex;
              
              return _buildStepIndicator(
                context,
                step,
                isCompleted: isCompleted,
                isCurrent: isCurrent,
                isUpcoming: isUpcoming,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(
    BuildContext context,
    SshConnectionStep step, {
    required bool isCompleted,
    required bool isCurrent,
    required bool isUpcoming,
  }) {
    Color color;
    IconData icon;
    
    if (isCompleted) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (isCurrent) {
      color = AppTheme.primaryColor;
      icon = Icons.radio_button_checked;
    } else {
      color = Colors.grey;
      icon = Icons.radio_button_unchecked;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step.description,
              style: TextStyle(
                color: isCurrent ? color : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          if (isCurrent) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Network status indicator widget
class NetworkStatusIndicator extends ConsumerWidget {
  final bool showLabel;

  const NetworkStatusIndicator({
    super.key,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This would be connected to a network state provider in a real implementation
    final networkState = NetworkState.connected(
      connectionType: NetworkConnectionType.wifi,
      quality: NetworkQuality.good,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getNetworkColor(networkState).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getNetworkColor(networkState).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            networkState.connectionType.emoji,
            style: const TextStyle(fontSize: 12),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              networkState.qualityEmoji,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  Color _getNetworkColor(NetworkState state) {
    switch (state.quality) {
      case NetworkQuality.excellent:
        return Colors.green;
      case NetworkQuality.good:
        return Colors.lightGreen;
      case NetworkQuality.fair:
        return Colors.orange;
      case NetworkQuality.poor:
        return Colors.red;
      case NetworkQuality.unknown:
        return Colors.grey;
    }
  }
}