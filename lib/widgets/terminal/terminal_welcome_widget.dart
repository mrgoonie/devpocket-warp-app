import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../providers/theme_provider.dart';
import '../../models/ssh_profile_models.dart';

/// Terminal welcome widget that displays host information and connection status
/// This widget is non-scrollable and shows full content at the top of terminal
class TerminalWelcomeWidget extends ConsumerWidget {
  final SshProfile? sshProfile;
  final String? sessionId;
  final bool isConnected;
  final String? connectionInfo;
  final Map<String, String>? systemInfo;
  final VoidCallback? onDismiss;

  const TerminalWelcomeWidget({
    super.key,
    this.sshProfile,
    this.sessionId,
    this.isConnected = false,
    this.connectionInfo,
    this.systemInfo,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.darkSurface,
            AppTheme.darkSurface.withValues(alpha: 0.8),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected 
              ? AppTheme.terminalGreen.withValues(alpha: 0.3)
              : AppTheme.terminalYellow.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(fontSize, fontFamily),
          _buildConnectionStatus(fontSize, fontFamily),
          if (sshProfile != null) 
            _buildHostInfo(fontSize, fontFamily),
          if (systemInfo != null && systemInfo!.isNotEmpty)
            _buildSystemInfo(fontSize, fontFamily),
          _buildWelcomeMessage(fontSize, fontFamily),
          if (onDismiss != null)
            _buildDismissButton(),
        ],
      ),
    );
  }

  Widget _buildHeader(double fontSize, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.terminalGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              sshProfile != null ? Icons.cloud : Icons.computer,
              color: AppTheme.terminalGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sshProfile != null ? 'SSH Terminal' : 'Local Terminal',
                  style: TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: fontSize * 1.2,
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (sshProfile != null)
                  Text(
                    sshProfile!.name,
                    style: TextStyle(
                      color: AppTheme.terminalGreen,
                      fontSize: fontSize,
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          _buildConnectionStatusBadge(fontSize),
        ],
      ),
    );
  }

  Widget _buildConnectionStatusBadge(double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected 
            ? AppTheme.terminalGreen.withValues(alpha: 0.2)
            : AppTheme.terminalYellow.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isConnected 
              ? AppTheme.terminalGreen.withValues(alpha: 0.5)
              : AppTheme.terminalYellow.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? AppTheme.terminalGreen : AppTheme.terminalYellow,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Connected' : 'Connecting',
            style: TextStyle(
              color: isConnected ? AppTheme.terminalGreen : AppTheme.terminalYellow,
              fontSize: fontSize * 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(double fontSize, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppTheme.darkTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Connection Details',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: fontSize * 0.9,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (connectionInfo != null)
            _buildInfoRow(
              'Status',
              connectionInfo!,
              fontSize,
              fontFamily,
            ),
          if (sessionId != null)
            _buildInfoRow(
              'Session ID',
              '${sessionId!.substring(0, 8)}...',
              fontSize,
              fontFamily,
            ),
          _buildInfoRow(
            'Started',
            _formatCurrentTime(),
            fontSize,
            fontFamily,
          ),
        ],
      ),
    );
  }

  Widget _buildHostInfo(double fontSize, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dns,
                size: 16,
                color: AppTheme.darkTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Host Information',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: fontSize * 0.9,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Host',
            '${sshProfile!.username}@${sshProfile!.host}',
            fontSize,
            fontFamily,
          ),
          _buildInfoRow(
            'Port',
            sshProfile!.port.toString(),
            fontSize,
            fontFamily,
          ),
          if (sshProfile!.description?.isNotEmpty == true)
            _buildInfoRow(
              'Description',
              sshProfile!.description!,
              fontSize,
              fontFamily,
            ),
        ],
      ),
    );
  }

  Widget _buildSystemInfo(double fontSize, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings_system_daydream,
                size: 16,
                color: AppTheme.darkTextSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                'System Information',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: fontSize * 0.9,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...systemInfo!.entries.take(5).map((entry) => _buildInfoRow(
                entry.key,
                entry.value,
                fontSize,
                fontFamily,
              )),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage(double fontSize, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.waving_hand,
                size: 20,
                color: AppTheme.terminalYellow,
              ),
              const SizedBox(width: 8),
              Text(
                'Welcome to DevPocket Terminal',
                style: TextStyle(
                  color: AppTheme.terminalYellow,
                  fontSize: fontSize * 1.1,
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWelcomeText(fontSize, fontFamily),
        ],
      ),
    );
  }

  Widget _buildWelcomeText(double fontSize, String fontFamily) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.terminalBlue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sshProfile != null 
                ? 'You are now connected to ${sshProfile!.host}. Start typing commands below or use AI mode for assistance.'
                : 'You are connected to your local terminal. Start typing commands below or use AI mode for assistance.',
            style: TextStyle(
              color: AppTheme.darkTextPrimary,
              fontSize: fontSize * 0.9,
              fontFamily: fontFamily,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickTips(fontSize, fontFamily),
        ],
      ),
    );
  }

  Widget _buildQuickTips(double fontSize, String fontFamily) {
    final tips = [
      '💡 Toggle AI mode with the switch in the command input area',
      '⌨️ Use Ctrl+C to cancel running commands',
      '📋 Long press output text to copy',
      '🖥️ Interactive commands (vi, nano, htop) open in fullscreen mode',
      '📱 Pull down to refresh or scroll up to see command history',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Tips:',
          style: TextStyle(
            color: AppTheme.terminalCyan,
            fontSize: fontSize * 0.85,
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...tips.map((tip) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                tip,
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: fontSize * 0.8,
                  fontFamily: fontFamily,
                  height: 1.3,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildDismissButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: TextButton.icon(
          onPressed: onDismiss,
          icon: const Icon(
            Icons.keyboard_arrow_up,
            color: AppTheme.darkTextSecondary,
            size: 18,
          ),
          label: const Text(
            'Dismiss Welcome',
            style: TextStyle(
              color: AppTheme.darkTextSecondary,
              fontSize: 12,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, double fontSize, String fontFamily) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: fontSize * 0.8,
                fontFamily: fontFamily,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: fontSize * 0.8,
                fontFamily: fontFamily,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
           '${now.month.toString().padLeft(2, '0')}/'
           '${now.year} '
           '${now.hour.toString().padLeft(2, '0')}:'
           '${now.minute.toString().padLeft(2, '0')}';
  }
}

/// Compact welcome widget for minimal display
class CompactTerminalWelcome extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final bool isConnected;
  final VoidCallback? onExpand;

  const CompactTerminalWelcome({
    super.key,
    required this.title,
    this.subtitle,
    this.isConnected = false,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontSize = ref.watch(fontSizeProvider);

    return GestureDetector(
      onTap: onExpand,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isConnected 
                ? AppTheme.terminalGreen.withValues(alpha: 0.3)
                : AppTheme.terminalYellow.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isConnected ? AppTheme.terminalGreen : AppTheme.terminalYellow,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppTheme.darkTextPrimary,
                      fontSize: fontSize * 0.9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: fontSize * 0.8,
                      ),
                    ),
                ],
              ),
            ),
            if (onExpand != null)
              const Icon(
                Icons.keyboard_arrow_down,
                color: AppTheme.darkTextSecondary,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}