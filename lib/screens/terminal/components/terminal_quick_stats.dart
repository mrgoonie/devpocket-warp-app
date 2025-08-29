import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';

/// Quick statistics component for terminal host selector
class TerminalQuickStats extends StatelessWidget {
  final int totalHosts;
  final int onlineHosts;

  const TerminalQuickStats({
    super.key,
    required this.totalHosts,
    required this.onlineHosts,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickStat(
            label: 'Total',
            value: totalHosts.toString(),
            icon: Icons.computer,
            color: AppTheme.primaryColor,
          ),
        ),
        Container(width: 1, height: 40, color: AppTheme.darkBorderColor),
        Expanded(
          child: _QuickStat(
            label: 'Online',
            value: onlineHosts.toString(),
            icon: Icons.circle,
            color: AppTheme.terminalGreen,
          ),
        ),
      ],
    );
  }
}

/// Individual quick statistic component
class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat({
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