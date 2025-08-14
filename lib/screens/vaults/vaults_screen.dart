import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';
import '../../models/ssh_models.dart';
import '../../providers/ssh_providers.dart';
import '../../widgets/host_card.dart';
import '../../widgets/add_host_sheet.dart';
import '../../widgets/ssh_key_card.dart';

class VaultsScreen extends ConsumerStatefulWidget {
  const VaultsScreen({super.key});

  @override
  ConsumerState<VaultsScreen> createState() => _VaultsScreenState();
}

class _VaultsScreenState extends ConsumerState<VaultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddHostDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddHostSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaults'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.darkTextSecondary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Hosts', icon: Icon(Icons.computer, size: 20)),
            Tab(text: 'Keys', icon: Icon(Icons.key, size: 20)),
            Tab(text: 'Logs', icon: Icon(Icons.history, size: 20)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _showAddHostDialog,
            tooltip: 'Add New Host',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHostsTab(),
          _buildKeysTab(),
          _buildLogsTab(),
        ],
      ),
    );
  }

  Widget _buildHostsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final hostsAsync = ref.watch(hostsProvider);
        
        return hostsAsync.when(
          data: (hosts) {
            if (hosts.isEmpty) {
              return _buildEmptyHostsState();
            }
            
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(hostsProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: hosts.length,
                itemBuilder: (context, index) {
                  final host = hosts[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: HostCard(
                      host: host,
                      onTap: () => _connectToHost(host),
                      onEdit: () => _editHost(host),
                      onDelete: () => _deleteHost(host),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          error: (error, stackTrace) => _buildErrorState(
            'Failed to load hosts',
            error.toString(),
            () => ref.invalidate(hostsProvider),
          ),
        );
      },
    );
  }

  Widget _buildKeysTab() {
    return Consumer(
      builder: (context, ref, child) {
        final keysAsync = ref.watch(sshKeysProvider);
        
        return keysAsync.when(
          data: (keys) {
            if (keys.isEmpty) {
              return _buildEmptyKeysState();
            }
            
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(sshKeysProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: keys.length,
                itemBuilder: (context, index) {
                  final key = keys[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SSHKeyCard(
                      sshKey: key,
                      onEdit: () => _editKey(key),
                      onDelete: () => _deleteKey(key),
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          error: (error, stackTrace) => _buildErrorState(
            'Failed to load SSH keys',
            error.toString(),
            () => ref.invalidate(sshKeysProvider),
          ),
        );
      },
    );
  }

  Widget _buildLogsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final logsAsync = ref.watch(connectionLogsProvider);
        
        return logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return _buildEmptyLogsState();
            }
            
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(connectionLogsProvider);
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return _buildLogCard(log);
                },
              ),
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          error: (error, stackTrace) => _buildErrorState(
            'Failed to load connection logs',
            error.toString(),
            () => ref.invalidate(connectionLogsProvider),
          ),
        );
      },
    );
  }

  Widget _buildEmptyHostsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.darkBorderColor, width: 2),
              ),
              child: const Icon(
                Icons.computer_outlined,
                size: 40,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Hosts Configured',
              style: context.textTheme.headlineMedium?.copyWith(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first SSH host to get started',
              style: context.textTheme.bodyLarge?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddHostDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add First Host'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyKeysState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.darkBorderColor, width: 2),
              ),
              child: const Icon(
                Icons.key_outlined,
                size: 40,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No SSH Keys',
              style: context.textTheme.headlineMedium?.copyWith(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Import or generate SSH keys for secure authentication',
              style: context.textTheme.bodyLarge?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showImportKeyDialog(),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import Key'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showGenerateKeyDialog(),
                  icon: const Icon(Icons.key),
                  label: const Text('Generate Key'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLogsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.darkBorderColor, width: 2),
              ),
              child: const Icon(
                Icons.history_outlined,
                size: 40,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Connection History',
              style: context.textTheme.headlineMedium?.copyWith(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connection logs will appear here after you connect to hosts',
              style: context.textTheme.bodyLarge?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(ConnectionLog log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: log.success ? AppTheme.terminalGreen.withValues(alpha: 0.2) : AppTheme.terminalRed.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            log.success ? Icons.check_circle : Icons.error,
            color: log.success ? AppTheme.terminalGreen : AppTheme.terminalRed,
            size: 20,
          ),
        ),
        title: Text(
          '${log.username}@${log.hostname}',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTimestamp(log.timestamp),
              style: context.textTheme.bodySmall?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
            ),
            if (log.duration != null)
              Text(
                'Duration: ${_formatDuration(log.duration!)}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            if (log.error != null)
              Text(
                'Error: ${log.error}',
                style: context.textTheme.bodySmall?.copyWith(
                  color: AppTheme.terminalRed,
                ),
              ),
          ],
        ),
        trailing: log.commandCount > 0
            ? Chip(
                label: Text('${log.commandCount} cmds'),
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                labelStyle: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 10,
                ),
              )
            : null,
        isThreeLine: log.error != null || log.duration != null,
      ),
    );
  }

  Widget _buildErrorState(String title, String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.terminalRed,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: context.textTheme.headlineMedium?.copyWith(
                color: AppTheme.darkTextPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
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

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
  }

  void _connectToHost(Host host) {
    // Navigate to terminal with host connection
    Navigator.pushNamed(context, '/terminal', arguments: host);
  }

  void _editHost(Host host) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddHostSheet(host: host),
    );
  }

  void _deleteHost(Host host) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Delete Host'),
        content: Text('Are you sure you want to delete "${host.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(hostsProvider.notifier).deleteHost(host.id);
              Navigator.pop(context);
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

  void _editKey(SSHKey key) {
    // TODO: Implement edit key functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit key functionality coming soon')),
    );
  }

  void _deleteKey(SSHKey key) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Delete SSH Key'),
        content: Text('Are you sure you want to delete "${key.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(sshKeysProvider.notifier).deleteKey(key.id);
              Navigator.pop(context);
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

  void _showImportKeyDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import SSH key functionality coming soon')),
    );
  }

  void _showGenerateKeyDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Generate SSH key functionality coming soon')),
    );
  }
}