import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../themes/app_theme.dart';
import '../../../models/ssh_profile_models.dart';
import '../utils/host_utils.dart';

/// Host card component for displaying SSH host information with actions
class HostCard extends ConsumerWidget {
  final SshProfile host;
  final Function(String, SshProfile) onMenuAction;

  const HostCard({
    super.key,
    required this.host,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.darkBorderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onMenuAction('connect', host),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _HostStatusIndicator(status: host.status),
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
                    onSelected: (value) => onMenuAction(value, host),
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
                  'Last connected: ${HostUtils.formatTimestamp(host.lastConnectedAt!)}',
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
}

/// Host status indicator component
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
}