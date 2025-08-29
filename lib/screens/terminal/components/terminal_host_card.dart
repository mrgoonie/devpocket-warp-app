import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../themes/app_theme.dart';
import '../../../models/ssh_profile_models.dart';
import '../../../providers/ssh_host_providers.dart';

/// Individual host card component for terminal host selection
class TerminalHostCard extends ConsumerStatefulWidget {
  final SshProfile host;
  final bool isConnecting;
  final ValueChanged<SshProfile> onConnect;
  final VoidCallback onConnectionStart;
  final VoidCallback onConnectionEnd;

  const TerminalHostCard({
    super.key,
    required this.host,
    required this.isConnecting,
    required this.onConnect,
    required this.onConnectionStart,
    required this.onConnectionEnd,
  });

  @override
  ConsumerState<TerminalHostCard> createState() => _TerminalHostCardState();
}

class _TerminalHostCardState extends ConsumerState<TerminalHostCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.darkSurface,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.isConnecting ? null : () => _handleConnection(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _HostStatusIndicator(status: widget.host.status),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.host.name,
                      style: const TextStyle(
                        color: AppTheme.darkTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.host.connectionString,
                      style: const TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                    if (widget.host.description?.isNotEmpty ?? false)
                      Text(
                        widget.host.description!,
                        style: const TextStyle(
                          color: AppTheme.darkTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              widget.isConnecting
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

  Future<void> _handleConnection() async {
    widget.onConnectionStart();
    
    try {
      // Simulate connection delay and test connection
      await Future.delayed(const Duration(milliseconds: 500));
      
      widget.onConnect(widget.host);
      
      // Sync with provider to maintain consistency
      ref.read(currentSshProfileProvider.notifier).state = widget.host;
    } catch (e) {
      widget.onConnectionEnd();
      
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
              onPressed: () => _retryConnection(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _retryConnection() async {
    widget.onConnectionStart();
    
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      
      widget.onConnect(widget.host);
      ref.read(currentSshProfileProvider.notifier).state = widget.host;
    } catch (retryError) {
      widget.onConnectionEnd();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $retryError'),
            backgroundColor: AppTheme.terminalRed,
          ),
        );
      }
    }
  }
}

/// SSH connection status indicator component
class _HostStatusIndicator extends StatelessWidget {
  final SshProfileStatus status;

  const _HostStatusIndicator({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (status) {
      case SshProfileStatus.active:
        color = AppTheme.terminalGreen;
        icon = Icons.circle;
        break;
      case SshProfileStatus.testing:
        color = AppTheme.terminalYellow;
        icon = Icons.sync;
        break;
      case SshProfileStatus.failed:
        color = AppTheme.terminalRed;
        icon = Icons.error;
        break;
      case SshProfileStatus.disabled:
      case SshProfileStatus.unknown:
        color = AppTheme.darkTextSecondary;
        icon = Icons.circle_outlined;
        break;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Icon(
        icon,
        color: color,
        size: 16,
      ),
    );
  }
}