import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ssh_models.dart';
import '../../../providers/ssh_key_providers.dart';

/// Utility class for SSH key operations and helpers
class SshKeyUtils {
  /// Get color for SSH key type
  static Color getKeyTypeColor(SshKeyType keyType) {
    switch (keyType) {
      case SshKeyType.rsa2048:
      case SshKeyType.rsa4096:
        return Colors.blue;
      case SshKeyType.ed25519:
        return Colors.green;
      case SshKeyType.ecdsa256:
      case SshKeyType.ecdsa384:
      case SshKeyType.ecdsa521:
        return Colors.orange;
    }
  }

  /// Get icon for SSH key type
  static IconData getKeyTypeIcon(SshKeyType keyType) {
    switch (keyType) {
      case SshKeyType.rsa2048:
      case SshKeyType.rsa4096:
        return Icons.security;
      case SshKeyType.ed25519:
        return Icons.verified_user;
      case SshKeyType.ecdsa256:
      case SshKeyType.ecdsa384:
      case SshKeyType.ecdsa521:
        return Icons.shield;
    }
  }

  /// Format DateTime as relative time
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  /// Get key age as a formatted string
  static String getKeyAge(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '$years year${years > 1 ? 's' : ''} old';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''} old';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} old';
    } else {
      return 'Created today';
    }
  }

  /// Format metadata key from snake_case to Title Case
  static String formatMetadataKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Copy public key to clipboard
  static void copyPublicKey(String publicKey, BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: publicKey));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Public key copied to clipboard'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Show edit key name dialog
  static void editKeyName(
    BuildContext context,
    WidgetRef ref,
    SshKeyRecord key,
  ) {
    final controller = TextEditingController(text: key.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Key Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Key Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              ref.read(sshKeysProvider.notifier).updateKeyMetadata(key.id, name: value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(sshKeysProvider.notifier).updateKeyMetadata(key.id, name: newName);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Show delete confirmation dialog
  static void deleteKey(
    BuildContext context,
    WidgetRef ref,
    SshKeyRecord key,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SSH Key'),
        content: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              const TextSpan(text: 'Are you sure you want to delete the key '),
              TextSpan(
                text: '"${key.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: '?\n\nThis action cannot be undone. Any hosts using this key will lose access.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(sshKeysProvider.notifier).deleteKey(key.id);
              if (context.mounted) {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to keys list
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Key "${key.name}" deleted'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}