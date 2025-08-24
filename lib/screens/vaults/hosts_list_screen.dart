import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../models/ssh_profile_models.dart';
import '../../providers/ssh_host_providers.dart';
import 'host_edit_screen.dart';

class HostsListScreen extends ConsumerStatefulWidget {
  const HostsListScreen({super.key});

  @override
  ConsumerState<HostsListScreen> createState() => _HostsListScreenState();
}

class _HostsListScreenState extends ConsumerState<HostsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(hostSearchProvider.notifier).state = _searchController.text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: _isSearching ? _buildSearchField() : const Text('SSH Hosts'),
        centerTitle: !_isSearching,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshHosts(),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddHostScreen(),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: !_isSearching ? FloatingActionButton(
        onPressed: _showAddHostScreen,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ) : null,
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: AppTheme.darkTextPrimary),
      decoration: const InputDecoration(
        hintText: 'Search hosts...',
        hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildBody() {
    return Consumer(
      builder: (context, ref, child) {
        final hostsAsync = ref.watch(filteredHostsProvider);
        
        return hostsAsync.when(
          data: (hosts) {
            if (hosts.isEmpty) {
              return _isSearching 
                  ? _buildNoSearchResults()
                  : _buildEmptyState();
            }
            
            return _buildHostsList(hosts);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          error: (error, stackTrace) => _buildErrorState(
            'Failed to load hosts',
            error.toString(),
          ),
        );
      },
    );
  }

  Widget _buildHostsList(List<SshProfile> hosts) {
    return Column(
      children: [
        _buildStatsHeader(hosts),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshHosts,
            color: AppTheme.primaryColor,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: hosts.length,
              itemBuilder: (context, index) {
                final host = hosts[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildHostCard(host),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader(List<SshProfile> hosts) {
    final activeCount = hosts.where((h) => h.status == SshProfileStatus.active).length;
    final totalCount = hosts.length;

    return Container(
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
            child: _buildStatItem(
              'Total Hosts',
              totalCount.toString(),
              Icons.computer,
              AppTheme.primaryColor,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.darkBorderColor,
          ),
          Expanded(
            child: _buildStatItem(
              'Online',
              activeCount.toString(),
              Icons.circle,
              AppTheme.terminalGreen,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.darkBorderColor,
          ),
          Expanded(
            child: _buildStatItem(
              'Offline',
              (totalCount - activeCount).toString(),
              Icons.circle_outlined,
              AppTheme.terminalRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
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

  Widget _buildHostCard(SshProfile host) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _connectToHost(host),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildStatusIndicator(host.status),
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
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: AppTheme.darkTextSecondary,
                    ),
                    color: AppTheme.darkSurface,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'connect',
                        child: Row(
                          children: [
                            Icon(Icons.terminal, color: AppTheme.primaryColor),
                            SizedBox(width: 8),
                            Text('Connect', style: TextStyle(color: AppTheme.darkTextPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'test',
                        child: Row(
                          children: [
                            Icon(Icons.wifi_find, color: AppTheme.terminalBlue),
                            SizedBox(width: 8),
                            Text('Test Connection', style: TextStyle(color: AppTheme.darkTextPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: AppTheme.terminalYellow),
                            SizedBox(width: 8),
                            Text('Edit', style: TextStyle(color: AppTheme.darkTextPrimary)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: AppTheme.terminalRed),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: AppTheme.darkTextPrimary)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) => _handleMenuAction(value, host),
                  ),
                ],
              ),
              if (host.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 8),
                Text(
                  host.description!,
                  style: const TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              if (host.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: host.tags.map((tag) => Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                    side: const BorderSide(color: AppTheme.primaryColor),
                    labelStyle: const TextStyle(color: AppTheme.primaryColor),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
              if (host.lastConnectedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last connected: ${_formatTimestamp(host.lastConnectedAt!)}',
                  style: const TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(SshProfileStatus status) {
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _buildEmptyState() {
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
            const Text(
              'No SSH Hosts',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first SSH host to get started with secure connections',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddHostScreen,
              icon: const Icon(Icons.add),
              label: const Text('Add SSH Host'),
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

  Widget _buildNoSearchResults() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.darkTextSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No matching hosts found',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String title, String error) {
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
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshHosts,
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

  void _handleMenuAction(String action, SshProfile host) {
    switch (action) {
      case 'connect':
        _connectToHost(host);
        break;
      case 'test':
        _testConnection(host);
        break;
      case 'edit':
        _editHost(host);
        break;
      case 'delete':
        _deleteHost(host);
        break;
    }
  }

  void _connectToHost(SshProfile host) {
    // Navigate to terminal with host connection
    Navigator.pushNamed(context, '/terminal', arguments: host);
  }

  Future<void> _testConnection(SshProfile host) async {
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

  void _editHost(SshProfile host) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostEditScreen(host: host),
      ),
    ).then((_) => _refreshHosts());
  }

  void _deleteHost(SshProfile host) {
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

  void _showAddHostScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HostEditScreen(),
      ),
    ).then((_) => _refreshHosts());
  }

  Future<void> _refreshHosts() async {
    await ref.read(sshHostsProvider.notifier).refresh();
  }
}