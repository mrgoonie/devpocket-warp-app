import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../themes/app_theme.dart';
import '../../../models/ssh_profile_models.dart';
import '../../../providers/ssh_host_providers.dart';
import '../../../widgets/ssh_sync_widgets.dart';
import 'terminal_host_card.dart';
import 'terminal_quick_stats.dart';
import 'terminal_state_widgets.dart';

/// Terminal host selector component for choosing SSH connections
class TerminalHostSelector extends ConsumerStatefulWidget {
  final bool isConnecting;
  final ValueChanged<SshProfile> onHostSelected;
  final VoidCallback onConnectionStart;
  final VoidCallback onConnectionEnd;

  const TerminalHostSelector({
    super.key,
    required this.isConnecting,
    required this.onHostSelected,
    required this.onConnectionStart,
    required this.onConnectionEnd,
  });

  @override
  ConsumerState<TerminalHostSelector> createState() => _TerminalHostSelectorState();
}

class _TerminalHostSelectorState extends ConsumerState<TerminalHostSelector> {
  @override
  Widget build(BuildContext context) {
    final hostsAsync = ref.watch(sshHostsProvider);
    
    return hostsAsync.when(
      data: (hosts) {
        if (hosts.isEmpty) {
          return const TerminalNoHostsState();
        }
        
        return Column(
          children: [
            // Sync status widget
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SyncStatusWidget(compact: true),
            ),
            
            // Header
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
            
            // Quick stats and sync controls
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
                  TerminalQuickStats(
                    totalHosts: hosts.length,
                    onlineHosts: hosts.where((h) => h.status == SshProfileStatus.active).length,
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
            
            // Host list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Perform full sync on refresh
                  await ref.read(syncStateProvider.notifier).performFullSync();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hosts.length,
                  itemBuilder: (context, index) {
                    final host = hosts[index];
                    return TerminalHostCard(
                      host: host,
                      isConnecting: widget.isConnecting,
                      onConnect: widget.onHostSelected,
                      onConnectionStart: widget.onConnectionStart,
                      onConnectionEnd: widget.onConnectionEnd,
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => TerminalErrorState(
        error: error.toString(),
        onRetry: () => ref.refresh(sshHostsProvider),
      ),
    );
  }
}