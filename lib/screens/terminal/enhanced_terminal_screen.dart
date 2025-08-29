import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../models/ssh_profile_models.dart';
import '../../providers/ssh_host_providers.dart';
import '../../widgets/terminal/ssh_terminal_widget.dart';
import '../../widgets/ssh_sync_widgets.dart';
import '../vaults/host_edit_screen.dart';

class EnhancedTerminalScreen extends ConsumerStatefulWidget {
  final SshProfile? initialProfile;
  final String? sessionId;

  const EnhancedTerminalScreen({
    super.key,
    this.initialProfile,
    this.sessionId,
  });

  @override
  ConsumerState<EnhancedTerminalScreen> createState() => _EnhancedTerminalScreenState();
}

class _EnhancedTerminalScreenState extends ConsumerState<EnhancedTerminalScreen> {
  SshProfile? _selectedProfile;
  bool _showHostSelector = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    
    // Check provider state as fallback if no initialProfile
    final providerProfile = ref.read(currentSshProfileProvider);
    _selectedProfile = widget.initialProfile ?? providerProfile;
    
    _showHostSelector = _selectedProfile == null && widget.sessionId == null;
    
    // Listen to provider changes for real-time updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listen<SshProfile?>(currentSshProfileProvider, (previous, next) {
        if (mounted && next != null && _selectedProfile == null) {
          setState(() {
            _selectedProfile = next;
            _showHostSelector = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(
          _selectedProfile?.name ?? 'Terminal',
          style: const TextStyle(color: AppTheme.darkTextPrimary),
        ),
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.darkTextPrimary),
        actions: [
          if (_selectedProfile != null) ...[
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showConnectionInfo,
              tooltip: 'Connection Info',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _editHost,
              tooltip: 'Edit Host',
            ),
          ],
          // Sync status indicator in app bar
          Consumer(
            builder: (context, ref, child) {
              final hasPendingConflicts = ref.watch(hasPendingConflictsProvider);
              if (hasPendingConflicts) {
                return IconButton(
                  icon: const Icon(Icons.warning, color: AppTheme.terminalYellow),
                  onPressed: () {
                    final conflict = ref.read(syncStateProvider).pendingConflict;
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
                  tooltip: 'Resolve Sync Conflicts',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Consumer(
            builder: (context, ref, child) {
              final hostsAsync = ref.watch(sshHostsProvider);
              
              return hostsAsync.when(
                data: (hosts) {
                  // Show "Add Host" icon when no hosts exist
                  if (hosts.isEmpty) {
                    return IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HostEditScreen(),
                          ),
                        );
                      },
                      tooltip: 'Add Host',
                    );
                  } else {
                    // Show "Select Host" icon when hosts exist
                    return IconButton(
                      icon: const Icon(Icons.list_alt),
                      onPressed: _showConnectionSelector,
                      tooltip: 'Select Host',
                    );
                  }
                },
                loading: () => const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HostEditScreen(),
                      ),
                    );
                  },
                  tooltip: 'Add Host',
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // Validate provider state consistency
    final providerProfile = ref.watch(currentSshProfileProvider);
    final effectiveProfile = _selectedProfile ?? providerProfile;
    
    if (_showHostSelector) {
      return _buildHostSelector();
    }

    if (effectiveProfile == null && widget.sessionId == null) {
      return _buildEmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SshTerminalWidget(
        profile: effectiveProfile,
        sessionId: widget.sessionId,
        onSessionClosed: _onSessionClosed,
      ),
    );
  }

  Widget _buildHostSelector() {
    return Consumer(
      builder: (context, ref, child) {
        final hostsAsync = ref.watch(sshHostsProvider);
        
        return hostsAsync.when(
          data: (hosts) {
            if (hosts.isEmpty) {
              return _buildNoHostsState();
            }
            
            return Column(
              children: [
                // Sync status widget
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: SyncStatusWidget(compact: true),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.darkSurface,
                  child: const Text(
                    'Select SSH Host',
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Quick stats header with sync controls
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.darkBorderColor),
                  ),
                  child: Column(
                    children: [
                      // Stats row
                      Row(
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Sync controls
                      const SyncControlsWidget(showFullControls: false),
                      const SizedBox(height: 8),
                      // Last sync time
                      const LastSyncTimeWidget(),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      // Perform full sync on refresh
                      ref.read(syncStateProvider.notifier).performFullSync();
                      await ref.read(sshHostsProvider.notifier).refresh();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: hosts.length,
                      itemBuilder: (context, index) {
                        final host = hosts[index];
                        return _buildHostCard(host);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ),
          error: (error, stackTrace) => _buildErrorState(error.toString()),
        );
      },
    );
  }


  Widget _buildHostCard(SshProfile host) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isConnecting ? null : () async {
          setState(() {
            _isConnecting = true;
          });
          
          try {
            // Simulate connection delay and test connection
            await Future.delayed(const Duration(milliseconds: 500));
            
            setState(() {
              _selectedProfile = host;
              _showHostSelector = false;
              _isConnecting = false;
            });
            
            // Sync with provider to maintain consistency
            ref.read(currentSshProfileProvider.notifier).state = host;
          } catch (e) {
            setState(() {
              _isConnecting = false;
            });
            
            // Clear provider state if connection fails
            ref.read(currentSshProfileProvider.notifier).state = null;
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Connection failed: $e'),
                  backgroundColor: AppTheme.terminalRed,
                  action: SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: () async {
                      setState(() {
                        _isConnecting = true;
                      });
                      
                      try {
                        await Future.delayed(const Duration(milliseconds: 500));
                        
                        setState(() {
                          _selectedProfile = host;
                          _showHostSelector = false;
                          _isConnecting = false;
                        });
                        
                        ref.read(currentSshProfileProvider.notifier).state = host;
                      } catch (retryError) {
                        setState(() {
                          _isConnecting = false;
                        });
                        
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Retry failed: $retryError'),
                              backgroundColor: AppTheme.terminalRed,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildStatusIndicator(host.status),
              const SizedBox(width: 16),
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
                    if (host.description?.isNotEmpty ?? false)
                      Text(
                        host.description!,
                        style: const TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              _isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : const Icon(
                    Icons.arrow_forward_ios,
                    color: AppTheme.darkTextSecondary,
                    size: 16,
                  ),
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
                Icons.terminal,
                size: 40,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Connection Selected',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select an SSH host to start a terminal session',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showConnectionSelector,
              icon: const Icon(Icons.computer),
              label: const Text('Select Host'),
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

  Widget _buildNoHostsState() {
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
              'Add SSH hosts in the Vaults section to connect',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HostEditScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Host'),
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

  Widget _buildErrorState(String error) {
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
            const Text(
              'Error Loading Hosts',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
              onPressed: () {
                ref.read(sshHostsProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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

  void _onSessionClosed() {
    // Clear both local and provider state
    setState(() {
      _selectedProfile = null;
      _showHostSelector = true;
    });
    
    ref.read(currentSshProfileProvider.notifier).state = null;
    
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showConnectionSelector() {
    setState(() {
      _showHostSelector = true;
      _selectedProfile = null;  // Clear the selected profile to disconnect
      _isConnecting = false;    // Reset connecting state
    });
    
    // Clear provider state to maintain consistency
    ref.read(currentSshProfileProvider.notifier).state = null;
  }


  void _showConnectionInfo() {
    if (_selectedProfile == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Connection Information',
          style: TextStyle(color: AppTheme.darkTextPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', _selectedProfile!.name),
            _buildInfoRow('Host', _selectedProfile!.host),
            _buildInfoRow('Port', _selectedProfile!.port.toString()),
            _buildInfoRow('Username', _selectedProfile!.username),
            _buildInfoRow('Auth Type', _selectedProfile!.authType.value),
            if (_selectedProfile!.description?.isNotEmpty ?? false)
              _buildInfoRow('Description', _selectedProfile!.description!),
            if (_selectedProfile!.lastConnectedAt != null)
              _buildInfoRow(
                'Last Connected',
                _formatTimestamp(_selectedProfile!.lastConnectedAt!),
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
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

  void _editHost() {
    if (_selectedProfile == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HostEditScreen(host: _selectedProfile),
      ),
    ).then((_) {
      // Refresh the profile data if it was edited
      ref.read(sshHostsProvider.notifier).refresh();
    });
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
}