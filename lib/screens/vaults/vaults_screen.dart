import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';
import '../../models/ssh_models.dart';
import '../../models/ssh_profile_models.dart';
import '../../providers/ssh_providers.dart';
import '../../providers/ssh_host_providers.dart';
import '../../providers/ssh_key_providers.dart';
import 'hosts_list_screen.dart';
import 'host_edit_screen.dart';
import '../ssh_keys/ssh_keys_screen.dart';
import '../ssh_keys/ssh_key_create_screen.dart';

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HostEditScreen(),
      ),
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
        final hostsAsync = ref.watch(sshHostsProvider);
        
        return hostsAsync.when(
          data: (hosts) {
            if (hosts.isEmpty) {
              return _buildEmptyHostsState();
            }
            
            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(sshHostsProvider.notifier).refresh();
              },
              child: Column(
                children: [
                  // Quick stats header
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkBorderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickStat(
                            'Total',
                            hosts.length.toString(),
                            Icons.computer,
                            AppTheme.primaryColor,
                          ),
                        ),
                        Container(width: 1, height: 40, color: AppTheme.darkBorderColor),
                        Expanded(
                          child: _buildQuickStat(
                            'Online',
                            hosts.where((h) => h.status == SshProfileStatus.active).length.toString(),
                            Icons.circle,
                            AppTheme.terminalGreen,
                          ),
                        ),
                        Container(width: 1, height: 40, color: AppTheme.darkBorderColor),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const HostsListScreen()),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_forward, color: AppTheme.primaryColor, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'View All',
                                  style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Recent hosts list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: (hosts.length > 3 ? 3 : hosts.length) + (hosts.length > 3 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (hosts.length > 3 && index == 3) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              color: AppTheme.darkSurface,
                              child: ListTile(
                                leading: const Icon(Icons.more_horiz, color: AppTheme.primaryColor),
                                title: Text(
                                  'View ${hosts.length - 3} more hosts',
                                  style: const TextStyle(color: AppTheme.primaryColor),
                                ),
                                trailing: const Icon(Icons.arrow_forward, color: AppTheme.primaryColor),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const HostsListScreen()),
                                ),
                              ),
                            ),
                          );
                        }
                        
                        final host = hosts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildHostProfileCard(host),
                        );
                      },
                    ),
                  ),
                ],
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
            () => ref.read(sshHostsProvider.notifier).refresh(),
          ),
        );
      },
    );
  }

  Widget _buildKeysTab() {
    return Consumer(
      builder: (context, ref, child) {
        final keysAsync = ref.watch(sshKeysProvider);
        final statsAsync = ref.watch(sshKeyStatsProvider);
        
        return keysAsync.when(
          data: (keys) {
            if (keys.isEmpty) {
              return _buildEmptyKeysState();
            }
            
            return RefreshIndicator(
              onRefresh: () async {
                await ref.read(sshKeysProvider.notifier).refreshKeys();
              },
              child: Column(
                children: [
                  // Quick stats header for keys
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.darkBorderColor),
                    ),
                    child: statsAsync.when(
                      data: (stats) => Row(
                        children: [
                          Expanded(
                            child: _buildQuickStat(
                              'Total',
                              (stats['totalKeys'] ?? 0).toString(),
                              Icons.key,
                              AppTheme.primaryColor,
                            ),
                          ),
                          Container(width: 1, height: 40, color: AppTheme.darkBorderColor),
                          Expanded(
                            child: _buildQuickStat(
                              'Recent',
                              (stats['recentlyUsed'] ?? 0).toString(),
                              Icons.schedule,
                              AppTheme.terminalGreen,
                            ),
                          ),
                          Container(width: 1, height: 40, color: AppTheme.darkBorderColor),
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SshKeysScreen()),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.arrow_forward, color: AppTheme.primaryColor, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'View All',
                                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const SizedBox(height: 72),
                      error: (_, __) => const SizedBox(height: 72),
                    ),
                  ),
                  // Recent keys list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: (keys.length > 3 ? 3 : keys.length) + (keys.length > 3 ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (keys.length > 3 && index == 3) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              color: AppTheme.darkSurface,
                              child: ListTile(
                                leading: const Icon(Icons.more_horiz, color: AppTheme.primaryColor),
                                title: Text(
                                  'View ${keys.length - 3} more keys',
                                  style: const TextStyle(color: AppTheme.primaryColor),
                                ),
                                trailing: const Icon(Icons.arrow_forward, color: AppTheme.primaryColor),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SshKeysScreen()),
                                ),
                              ),
                            ),
                          );
                        }
                        
                        final key = keys[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildKeyRecordCard(key),
                        );
                      },
                    ),
                  ),
                ],
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
            () => ref.read(sshKeysProvider.notifier).refreshKeys(),
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
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SshKeysScreen()),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import Key'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SshKeyCreateScreen()),
                  ),
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

  Widget _buildQuickStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildHostProfileCard(SshProfile host) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _connectToSshProfile(host),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildSshProfileStatusIndicator(host.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.name,
                      style: const TextStyle(
                        color: AppTheme.darkTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      host.connectionString,
                      style: const TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (host.lastConnectedAt != null)
                      Text(
                        'Last: ${_formatTimestamp(host.lastConnectedAt!)}',
                        style: const TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert, color: AppTheme.darkTextSecondary),
                onPressed: () => _showSshProfileMenu(host),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSshProfileStatusIndicator(SshProfileStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case SshProfileStatus.active:
        color = AppTheme.terminalGreen;
        icon = Icons.circle;
        break;
      case SshProfileStatus.testing:
        color = AppTheme.terminalYellow;
        icon = Icons.hourglass_empty;
        break;
      case SshProfileStatus.failed:
        color = AppTheme.terminalRed;
        icon = Icons.error;
        break;
      case SshProfileStatus.disabled:
        color = AppTheme.darkTextSecondary;
        icon = Icons.pause_circle;
        break;
      default:
        color = AppTheme.darkTextSecondary;
        icon = Icons.circle_outlined;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  void _showSshProfileMenu(SshProfile host) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.terminal, color: AppTheme.primaryColor),
              title: const Text('Connect', style: TextStyle(color: AppTheme.darkTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                _connectToSshProfile(host);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.terminalYellow),
              title: const Text('Edit', style: TextStyle(color: AppTheme.darkTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HostEditScreen(host: host)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.wifi_find, color: AppTheme.terminalBlue),
              title: const Text('Test Connection', style: TextStyle(color: AppTheme.darkTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                _testSshConnection(host);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.terminalRed),
              title: const Text('Delete', style: TextStyle(color: AppTheme.darkTextPrimary)),
              onTap: () {
                Navigator.pop(context);
                _deleteSshProfile(host);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _connectToSshProfile(SshProfile host) {
    // Navigate to terminal with SSH profile connection
    Navigator.pushNamed(context, '/terminal', arguments: host);
  }

  Future<void> _testSshConnection(SshProfile host) async {
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
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test failed: $e'),
          backgroundColor: AppTheme.terminalRed,
        ),
      );
    }
  }

  void _deleteSshProfile(SshProfile host) {
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
              final success = await ref.read(sshHostsProvider.notifier).deleteHost(host.id);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Host deleted successfully'),
                    backgroundColor: AppTheme.terminalGreen,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete host'),
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




  Widget _buildKeyRecordCard(SshKeyRecord key) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SshKeysScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
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
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      key.name,
                      style: const TextStyle(
                        color: AppTheme.darkTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getKeyTypeColor(key.keyType).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            key.keyType.displayName,
                            style: TextStyle(
                              color: _getKeyTypeColor(key.keyType),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (key.hasPassphrase)
                          Icon(
                            Icons.lock,
                            size: 12,
                            color: AppTheme.darkTextSecondary,
                          ),
                      ],
                    ),
                    if (key.lastUsed != null)
                      Text(
                        'Used: ${_formatTimestamp(key.lastUsed!)}',
                        style: const TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: AppTheme.darkTextSecondary, size: 16),
            ],
          ),
        ),
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
}