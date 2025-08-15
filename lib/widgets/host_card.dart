import 'package:flutter/material.dart';
import '../models/ssh_models.dart';
import '../themes/app_theme.dart';
import '../main.dart';

class HostCard extends StatelessWidget {
  final Host host;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const HostCard({
    super.key,
    required this.host,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _getStatusColor(host.status),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Status indicator
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _getStatusColor(host.status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Host name
                  Expanded(
                    child: Text(
                      host.name,
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  // Actions menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: AppTheme.darkTextSecondary,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'connect',
                        child: ListTile(
                          leading: Icon(Icons.play_arrow),
                          title: Text('Connect'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit),
                          title: Text('Edit'),
                          dense: true,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: AppTheme.terminalRed),
                          title: Text('Delete', style: TextStyle(color: AppTheme.terminalRed)),
                          dense: true,
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      switch (value) {
                        case 'connect':
                          onTap?.call();
                          break;
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Connection details
              Text(
                host.connectionString,
                style: context.textTheme.bodyLarge?.copyWith(
                  fontFamily: AppTheme.terminalFont,
                  color: AppTheme.darkTextSecondary,
                ),
              ),
              
              if (host.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  host.description!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.darkTextSecondary,
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Tags and status
              Row(
                children: [
                  // Tags
                  if (host.tags.isNotEmpty)
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: host.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              tag,
                              style: context.textTheme.labelSmall?.copyWith(
                                color: AppTheme.primaryColor,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  
                  // Last connected
                  if (host.lastConnectedAt != null)
                    Text(
                      _formatLastConnected(host.lastConnectedAt!),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Connect button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: host.status == HostStatus.connecting ? null : onTap,
                  icon: host.status == HostStatus.connecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.terminal),
                  label: Text(
                    host.status == HostStatus.connecting ? 'Connecting...' : 'Connect',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(HostStatus status) {
    switch (status) {
      case HostStatus.online:
        return AppTheme.terminalGreen;
      case HostStatus.offline:
        return AppTheme.darkTextSecondary;
      case HostStatus.connecting:
        return AppTheme.accentColor;
      case HostStatus.error:
        return AppTheme.terminalRed;
      case HostStatus.unknown:
        return AppTheme.darkBorderColor;
    }
  }

  String _formatLastConnected(DateTime lastConnected) {
    final now = DateTime.now();
    final difference = now.difference(lastConnected);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastConnected.month}/${lastConnected.day}';
    }
  }
}