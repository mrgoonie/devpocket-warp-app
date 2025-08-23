import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';
import '../../models/ssh_models.dart';
import '../../providers/ssh_key_providers.dart';

class SshKeyDetailScreen extends ConsumerStatefulWidget {
  final String keyId;

  const SshKeyDetailScreen({
    super.key,
    required this.keyId,
  });

  @override
  ConsumerState<SshKeyDetailScreen> createState() => _SshKeyDetailScreenState();
}

class _SshKeyDetailScreenState extends ConsumerState<SshKeyDetailScreen> {
  bool _showFullFingerprint = false;
  bool _showPublicKey = false;

  @override
  Widget build(BuildContext context) {
    final keyAsync = ref.watch(sshKeyProvider(widget.keyId));

    return Scaffold(
      appBar: _buildAppBar(),
      body: keyAsync.when(
        data: (key) {
          if (key == null) {
            return _buildNotFound();
          }
          return _buildKeyDetails(key);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => _buildError(error),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('SSH Key Details'),
      backgroundColor: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
      foregroundColor: context.isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
      elevation: 0,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy_public',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy Public Key'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Export Key'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Name'),
                dense: true,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Key', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
          onSelected: _handleMenuAction,
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.key_off,
            size: 64,
            color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'SSH Key Not Found',
            style: context.textTheme.titleLarge?.copyWith(
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The requested SSH key could not be found.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading Key',
            style: context.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: context.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyDetails(SshKeyRecord key) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKeyHeader(key),
          const SizedBox(height: 24),
          _buildKeyInfo(key),
          const SizedBox(height: 24),
          _buildSecurityInfo(key),
          const SizedBox(height: 24),
          _buildPublicKeySection(key),
          const SizedBox(height: 24),
          _buildUsageInfo(key),
          const SizedBox(height: 24),
          _buildActions(key),
        ],
      ),
    );
  }

  Widget _buildKeyHeader(SshKeyRecord key) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getKeyTypeColor(key.keyType).withValues(alpha: 0.1),
            _getKeyTypeColor(key.keyType).withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getKeyTypeColor(key.keyType).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _getKeyTypeColor(key.keyType).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getKeyTypeColor(key.keyType).withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Icon(
              _getKeyTypeIcon(key.keyType),
              color: _getKeyTypeColor(key.keyType),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  key.name,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getKeyTypeColor(key.keyType).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    key.keyType.displayName,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: _getKeyTypeColor(key.keyType),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyInfo(SshKeyRecord key) {
    return _buildSection(
      title: 'Key Information',
      icon: Icons.info,
      child: Column(
        children: [
          _buildInfoRow('Algorithm', key.keyType.algorithm.toUpperCase()),
          _buildInfoRow('Key Size', '${key.keyType.keySize} bits'),
          _buildInfoRow('Created', _formatDateTime(key.createdAt)),
          if (key.lastUsed != null)
            _buildInfoRow('Last Used', _formatDateTime(key.lastUsed!))
          else
            _buildInfoRow('Last Used', 'Never'),
          _buildInfoRow(
            'Fingerprint',
            GestureDetector(
              onTap: () {
                setState(() {
                  _showFullFingerprint = !_showFullFingerprint;
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _showFullFingerprint
                          ? key.fingerprint
                          : '${key.fingerprint.substring(0, 20)}...',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Icon(
                    _showFullFingerprint ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo(SshKeyRecord key) {
    return _buildSection(
      title: 'Security',
      icon: Icons.security,
      child: Column(
        children: [
          _buildInfoRow(
            'Passphrase Protection',
            Row(
              children: [
                Icon(
                  key.hasPassphrase ? Icons.lock : Icons.lock_open,
                  size: 16,
                  color: key.hasPassphrase ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  key.hasPassphrase ? 'Protected' : 'Not Protected',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: key.hasPassphrase ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _buildInfoRow('Storage', 'Encrypted (AES-256-GCM)'),
          _buildInfoRow('Key Format', 'OpenSSH'),
        ],
      ),
    );
  }

  Widget _buildPublicKeySection(SshKeyRecord key) {
    return _buildSection(
      title: 'Public Key',
      icon: Icons.vpn_key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Public Key Content',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showPublicKey = !_showPublicKey;
                  });
                },
                icon: Icon(
                  _showPublicKey ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                ),
                label: Text(_showPublicKey ? 'Hide' : 'Show'),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          if (_showPublicKey) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    key.publicKey,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyPublicKey(key.publicKey),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Implement export functionality
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.isDarkMode 
                    ? AppTheme.darkTextSecondary.withValues(alpha: 0.1)
                    : AppTheme.lightTextSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off,
                    color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Public key is hidden for security',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageInfo(SshKeyRecord key) {
    return _buildSection(
      title: 'Usage',
      icon: Icons.analytics,
      child: Column(
        children: [
          _buildInfoRow('Status', key.lastUsed != null ? 'Active' : 'Unused'),
          _buildInfoRow('Age', _getKeyAge(key.createdAt)),
          if (key.metadata.isNotEmpty)
            ...key.metadata.entries.map((entry) => 
              _buildInfoRow(
                _formatMetadataKey(entry.key),
                entry.value.toString(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(SshKeyRecord key) {
    return _buildSection(
      title: 'Actions',
      icon: Icons.build,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => _copyPublicKey(key.publicKey),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Public Key'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement export functionality
            },
            icon: const Icon(Icons.download),
            label: const Text('Export Key'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _editKeyName(key),
            icon: const Icon(Icons.edit),
            label: const Text('Edit Name'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _deleteKey(key),
            icon: const Icon(Icons.delete),
            label: const Text('Delete Key'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: value is Widget
                ? value
                : Text(
                    value.toString(),
                    style: context.textTheme.bodyMedium,
                  ),
          ),
        ],
      ),
    );
  }

  Color _getKeyTypeColor(SshKeyType keyType) {
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

  IconData _getKeyTypeIcon(SshKeyType keyType) {
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

  String _formatDateTime(DateTime dateTime) {
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

  String _getKeyAge(DateTime createdAt) {
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

  String _formatMetadataKey(String key) {
    return key
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  void _copyPublicKey(String publicKey) async {
    try {
      await Clipboard.setData(ClipboardData(text: publicKey));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Public key copied to clipboard'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy public key: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _editKeyName(SshKeyRecord key) {
    final controller = TextEditingController(text: key.name);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Key Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Key Name',
            hintText: 'Enter new key name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != key.name) {
                Navigator.of(context).pop();
                
                final actions = ref.read(sshKeyActionsProvider);
                final updated = await actions.updateKeyMetadata(
                  key.id,
                  name: newName,
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        updated
                            ? 'Key name updated successfully'
                            : 'Failed to update key name',
                      ),
                      backgroundColor: updated ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteKey(SshKeyRecord key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SSH Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${key.name}"?'),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: context.textTheme.bodySmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to keys list
              
              final actions = ref.read(sshKeyActionsProvider);
              final deleted = await actions.deleteKey(key.id);
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      deleted
                          ? 'SSH key deleted successfully'
                          : 'Failed to delete SSH key',
                    ),
                    backgroundColor: deleted ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) async {
    final keyAsync = ref.read(sshKeyProvider(widget.keyId));
    final key = keyAsync.value;
    if (key == null) return;

    switch (action) {
      case 'copy_public':
        _copyPublicKey(key.publicKey);
        break;
      case 'export':
        // TODO: Implement export functionality
        break;
      case 'edit':
        _editKeyName(key);
        break;
      case 'delete':
        _deleteKey(key);
        break;
    }
  }
}