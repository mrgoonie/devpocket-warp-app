import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';
import '../../../models/ssh_profile_models.dart';

/// Statistics header component showing host counts and status
class HostStatsHeader extends StatelessWidget {
  final List<SshProfile> hosts;

  const HostStatsHeader({
    super.key,
    required this.hosts,
  });

  @override
  Widget build(BuildContext context) {
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
            child: _HostStatItem(
              label: 'Total Hosts',
              value: totalCount.toString(),
              icon: Icons.computer,
              color: AppTheme.primaryColor,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.darkBorderColor,
          ),
          Expanded(
            child: _HostStatItem(
              label: 'Online',
              value: activeCount.toString(),
              icon: Icons.circle,
              color: AppTheme.terminalGreen,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.darkBorderColor,
          ),
          Expanded(
            child: _HostStatItem(
              label: 'Offline',
              value: (totalCount - activeCount).toString(),
              icon: Icons.circle_outlined,
              color: AppTheme.terminalRed,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual statistic item widget
class _HostStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HostStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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