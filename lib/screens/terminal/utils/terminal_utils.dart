import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';
import '../../../models/ssh_profile_models.dart';
import '../../vaults/host_edit_screen.dart';

/// Utility class for terminal screen operations
class TerminalUtils {
  /// Format timestamp as relative time string
  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  /// Show connection information dialog
  static void showConnectionInfo(BuildContext context, SshProfile profile) {
    showDialog(
      context: context,
      builder: (context) => ConnectionInfoDialog(profile: profile),
    );
  }

  /// Navigate to edit host screen
  static void editHost(BuildContext context, SshProfile profile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostEditScreen(host: profile),
      ),
    );
  }
}

/// Connection information dialog component
class ConnectionInfoDialog extends StatelessWidget {
  final SshProfile profile;

  const ConnectionInfoDialog({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      title: const Text(
        'Connection Information',
        style: TextStyle(color: AppTheme.darkTextPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(label: 'Name', value: profile.name),
          _InfoRow(label: 'Host', value: profile.host),
          _InfoRow(label: 'Port', value: profile.port.toString()),
          _InfoRow(label: 'Username', value: profile.username),
          _InfoRow(label: 'Auth Type', value: profile.authType.value),
          if (profile.description?.isNotEmpty ?? false)
            _InfoRow(label: 'Description', value: profile.description!),
          if (profile.lastConnectedAt != null)
            _InfoRow(
              label: 'Last Connected',
              value: TerminalUtils.formatTimestamp(profile.lastConnectedAt!),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Close',
            style: TextStyle(color: AppTheme.primaryColor),
          ),
        ),
      ],
    );
  }
}

/// Information row component for dialog display
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}