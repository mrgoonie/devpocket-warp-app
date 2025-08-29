import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../models/ssh_profile_models.dart';
import '../../providers/ssh_host_providers.dart';
import '../../widgets/terminal/ssh_terminal_widget.dart';
import '../../widgets/ssh_sync_widgets.dart';
import 'components/terminal_host_selector.dart';
import 'components/terminal_state_widgets.dart';
import 'utils/terminal_utils.dart';

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
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            onPressed: () => TerminalUtils.showConnectionInfo(context, _selectedProfile!),
            tooltip: 'Connection Info',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => TerminalUtils.editHost(context, _selectedProfile!),
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
            
            final syncNeeded = ref.watch(syncNeededProvider);
            return IconButton(
              icon: Icon(
                syncNeeded.value == false ? Icons.cloud_done : Icons.cloud_off,
                color: syncNeeded.value == false ? AppTheme.terminalGreen : AppTheme.terminalYellow,
              ),
              onPressed: () {
                // Show sync status dialog or perform manual sync
                ref.read(syncStateProvider.notifier).performFullSync();
              },
              tooltip: syncNeeded.value == false ? 'Synced - Tap to sync' : 'Needs sync - Tap to sync',
            );
          },
        ),
        // Connection selector button
        if (_selectedProfile == null || _showHostSelector)
          IconButton(
            icon: const Icon(Icons.computer),
            onPressed: _showConnectionSelector,
            tooltip: 'Select Connection',
          ),
      ],
    );
  }

  Widget _buildBody() {
    // Validate provider state consistency
    final providerProfile = ref.watch(currentSshProfileProvider);
    final effectiveProfile = _selectedProfile ?? providerProfile;
    
    if (_showHostSelector) {
      return TerminalHostSelector(
        isConnecting: _isConnecting,
        onHostSelected: _onHostSelected,
        onConnectionStart: () => setState(() => _isConnecting = true),
        onConnectionEnd: () => setState(() => _isConnecting = false),
      );
    }

    if (effectiveProfile == null && widget.sessionId == null) {
      return TerminalEmptyState(
        onSelectHost: _showConnectionSelector,
      );
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

  void _onHostSelected(SshProfile host) {
    setState(() {
      _selectedProfile = host;
      _showHostSelector = false;
      _isConnecting = false;
    });
  }

  void _onSessionClosed() {
    setState(() {
      _selectedProfile = null;
      _showHostSelector = false;
    });
    
    // Clear provider state when session closes
    ref.read(currentSshProfileProvider.notifier).state = null;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terminal session closed'),
          backgroundColor: AppTheme.terminalYellow,
        ),
      );
    }
  }

  void _showConnectionSelector() {
    setState(() {
      _showHostSelector = true;
    });
  }
}