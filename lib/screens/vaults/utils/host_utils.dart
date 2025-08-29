import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../themes/app_theme.dart';
import '../../../models/ssh_profile_models.dart';
import '../../../providers/ssh_host_providers.dart';
import '../../main/main_tab_screen.dart';
import '../host_edit_screen.dart';

/// Utility functions for host management operations
class HostUtils {
  HostUtils._();

  /// Navigate to terminal with selected SSH host
  static void connectToHost(WidgetRef ref, BuildContext context, SshProfile host) {
    // Set the SSH profile in the provider for the Terminal screen to use
    ref.read(currentSshProfileProvider.notifier).state = host;
    
    // Navigate to the Terminal tab instead of creating a new route
    TabNavigationHelper.navigateToTab(context, TabNavigationHelper.terminalTab);
  }

  /// Test SSH connection to a host
  static Future<void> testConnection(WidgetRef ref, BuildContext context, SshProfile host) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text(
              'Testing connection...',
              style: TextStyle(color: AppTheme.darkTextPrimary),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await ref.read(sshHostsProvider.notifier).testConnection(host);
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show result dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.darkSurface,
            title: Text(
              result.success ? 'Connection Successful' : 'Connection Failed',
              style: TextStyle(
                color: result.success ? AppTheme.terminalGreen : AppTheme.terminalRed,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.responseTime != null)
                  Text(
                    'Response time: ${result.responseTime!.inMilliseconds}ms',
                    style: const TextStyle(color: AppTheme.darkTextSecondary),
                  ),
                if (result.message != null)
                  Text(
                    result.message!,
                    style: const TextStyle(color: AppTheme.darkTextPrimary),
                  ),
                if (result.error != null)
                  Text(
                    result.error!,
                    style: const TextStyle(color: AppTheme.terminalRed),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'OK',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: AppTheme.terminalRed,
          ),
        );
      }
    }
  }

  /// Edit SSH host configuration
  static void editHost(BuildContext context, SshProfile host, VoidCallback onRefresh) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostEditScreen(host: host),
      ),
    ).then((_) => onRefresh());
  }

  /// Delete SSH host with confirmation dialog
  static void deleteHost(WidgetRef ref, BuildContext context, SshProfile host) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Delete SSH Host',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${host.name}"?\n\nThis action cannot be undone.',
          style: const TextStyle(color: AppTheme.darkTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.darkTextSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Store context before async operation
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              
              try {
                final success = await ref.read(sshHostsProvider.notifier).deleteHost(host.id);
                
                // No need for mounted check with stored messenger
                if (success) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Host deleted successfully'),
                      backgroundColor: AppTheme.terminalGreen,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete host. It may not exist on the server.'),
                      backgroundColor: AppTheme.terminalRed,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error deleting host: $e');
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: AppTheme.terminalRed,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terminalRed,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Show add host screen
  static void showAddHostScreen(BuildContext context, VoidCallback onRefresh) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HostEditScreen(),
      ),
    ).then((_) => onRefresh());
  }

  /// Format timestamp for display
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

  /// Handle popup menu actions
  static void handleMenuAction(
    String action,
    SshProfile host,
    WidgetRef ref,
    BuildContext context,
    VoidCallback onRefresh,
  ) {
    switch (action) {
      case 'connect':
        connectToHost(ref, context, host);
        break;
      case 'test':
        testConnection(ref, context, host);
        break;
      case 'edit':
        editHost(context, host, onRefresh);
        break;
      case 'delete':
        deleteHost(ref, context, host);
        break;
    }
  }

  /// Refresh hosts data
  static Future<void> refreshHosts(WidgetRef ref) async {
    await ref.read(sshHostsProvider.notifier).refresh();
  }
}