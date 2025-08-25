import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';
import '../../models/ssh_models.dart';
import '../../providers/ssh_key_providers.dart';
import 'ssh_key_create_screen.dart';
import 'ssh_key_detail_screen.dart';

class SshKeysScreen extends ConsumerStatefulWidget {
  const SshKeysScreen({super.key});

  @override
  ConsumerState<SshKeysScreen> createState() => _SshKeysScreenState();
}

class _SshKeysScreenState extends ConsumerState<SshKeysScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SshKeyType? _filterType;
  bool _showOnlyRecent = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keysAsync = ref.watch(sshKeysProvider);
    final statsAsync = ref.watch(sshKeyStatsProvider);

    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          _buildStatsHeader(statsAsync),
          Expanded(
            child: _buildKeysList(keysAsync),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('SSH Keys'),
      backgroundColor: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
      foregroundColor: context.isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.read(sshKeysProvider.notifier).refreshKeys();
          },
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'cleanup',
              child: ListTile(
                leading: Icon(Icons.cleaning_services),
                title: Text('Cleanup Old Keys'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'backup',
              child: ListTile(
                leading: Icon(Icons.backup),
                title: Text('Export Backup'),
                dense: true,
              ),
            ),
          ],
          onSelected: _handleMenuAction,
        ),
      ],
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search SSH keys...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                ),
              ),
              filled: true,
              fillColor: context.isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
          
          const SizedBox(height: 12),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Type filters
                FilterChip(
                  label: const Text('All Types'),
                  selected: _filterType == null,
                  onSelected: (selected) {
                    setState(() => _filterType = null);
                  },
                ),
                const SizedBox(width: 8),
                ...SshKeyType.values.map((type) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type.algorithm.toUpperCase()),
                    selected: _filterType == type,
                    onSelected: (selected) {
                      setState(() => _filterType = selected ? type : null);
                    },
                  ),
                )),
                
                const SizedBox(width: 16),
                
                // Recent filter
                FilterChip(
                  label: const Text('Recent'),
                  selected: _showOnlyRecent,
                  onSelected: (selected) {
                    setState(() => _showOnlyRecent = selected);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(AsyncValue<Map<String, dynamic>> statsAsync) {
    return statsAsync.when(
      data: (stats) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: context.isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              icon: Icons.key,
              label: 'Total',
              value: stats['totalKeys']?.toString() ?? '0',
            ),
            _buildStatItem(
              icon: Icons.schedule,
              label: 'Recent',
              value: stats['recentlyUsed']?.toString() ?? '0',
            ),
            _buildStatItem(
              icon: Icons.lock,
              label: 'Protected',
              value: stats['withPassphrase']?.toString() ?? '0',
            ),
          ],
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildKeysList(AsyncValue<List<SshKeyRecord>> keysAsync) {
    return keysAsync.when(
      data: (keys) {
        // Apply filtering here
        final filteredKeys = _applyFilters(keys);
        
        if (filteredKeys.isEmpty) {
          return _buildEmptyState();
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredKeys.length,
          itemBuilder: (context, index) {
            return _buildKeyCard(filteredKeys[index]);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load SSH keys',
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(sshKeysProvider.notifier).refreshKeys();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            _searchQuery.isNotEmpty || _filterType != null || _showOnlyRecent
                ? 'No SSH keys match your filter'
                : 'No SSH keys found',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _filterType != null || _showOnlyRecent
                ? 'Try adjusting your search or filter criteria'
                : 'Create your first SSH key to get started',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isEmpty && _filterType == null && !_showOnlyRecent) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createNewKey,
              icon: const Icon(Icons.add),
              label: const Text('Create SSH Key'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyCard(SshKeyRecord key) {
    final isRecent = key.lastUsed != null && 
        DateTime.now().difference(key.lastUsed!).inDays <= 7;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getKeyTypeColor(key.keyType).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getKeyTypeColor(key.keyType).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            _getKeyTypeIcon(key.keyType),
            color: _getKeyTypeColor(key.keyType),
            size: 24,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                key.name,
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isRecent)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  'RECENT',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getKeyTypeColor(key.keyType).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    key.keyType.displayName,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: _getKeyTypeColor(key.keyType),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (key.hasPassphrase)
                  Icon(
                    Icons.lock,
                    size: 14,
                    color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Fingerprint: ${key.fingerprint.substring(7, 23)}...',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                fontFamily: 'monospace',
              ),
            ),
            if (key.lastUsed != null) ...[
              const SizedBox(height: 2),
              Text(
                'Last used: ${_formatLastUsed(key.lastUsed!)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.visibility),
                title: Text('View Details'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'copy',
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
                title: Text('Export'),
                dense: true,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
          onSelected: (action) => _handleKeyAction(action, key),
        ),
        onTap: () => _viewKeyDetails(key),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _createNewKey,
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: Colors.white,
      child: const Icon(Icons.add),
    );
  }

  List<SshKeyRecord> _applyFilters(List<SshKeyRecord> keys) {
    var filtered = keys;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((key) {
        return key.name.toLowerCase().contains(query) ||
               key.keyType.displayName.toLowerCase().contains(query) ||
               key.fingerprint.toLowerCase().contains(query);
      }).toList();
    }
    
    // Apply type filter
    if (_filterType != null) {
      filtered = filtered.where((key) => key.keyType == _filterType).toList();
    }
    
    // Apply recent filter
    if (_showOnlyRecent) {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      filtered = filtered.where((key) => 
          key.lastUsed != null && key.lastUsed!.isAfter(cutoffDate)
      ).toList();
    }
    
    return filtered;
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

  String _formatLastUsed(DateTime lastUsed) {
    final now = DateTime.now();
    final difference = now.difference(lastUsed);
    
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

  void _createNewKey() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SshKeyCreateScreen(),
      ),
    );
  }

  void _viewKeyDetails(SshKeyRecord key) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SshKeyDetailScreen(keyId: key.id),
      ),
    );
  }

  void _handleKeyAction(String action, SshKeyRecord key) async {
    final actions = ref.read(sshKeyActionsProvider);
    
    switch (action) {
      case 'view':
        _viewKeyDetails(key);
        break;
        
      case 'copy':
        try {
          final success = await actions.copyPublicKey(key.id);
          if (success && mounted) {
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
        break;
        
      case 'export':
        // TODO: Implement export functionality
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Export functionality coming soon'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
        
      case 'delete':
        _deleteKey(key);
        break;
    }
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
              
              final actions = ref.read(sshKeyActionsProvider);
              final deleted = await actions.deleteKey(key.id);
              
              if (mounted) {
                // ignore: use_build_context_synchronously
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
    final actions = ref.read(sshKeyActionsProvider);
    
    switch (action) {
      case 'cleanup':
        final deletedCount = await actions.cleanupOldKeys(maxAgeInDays: 365);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cleaned up $deletedCount old SSH keys'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
        
      case 'backup':
        // TODO: Implement backup functionality
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backup functionality coming soon'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
    }
  }
}