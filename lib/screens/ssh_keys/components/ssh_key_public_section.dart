import 'package:flutter/material.dart';
import '../../../models/ssh_models.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';
import '../utils/ssh_key_utils.dart';
import 'ssh_key_common_widgets.dart';

/// SSH key public key section with show/hide and copy functionality
class SshKeyPublicSection extends StatefulWidget {
  final SshKeyRecord sshKey;

  const SshKeyPublicSection({
    super.key,
    required this.sshKey,
  });

  @override
  State<SshKeyPublicSection> createState() => _SshKeyPublicSectionState();
}

class _SshKeyPublicSectionState extends State<SshKeyPublicSection> {
  bool _showPublicKey = false;

  @override
  Widget build(BuildContext context) {
    return SshKeySection(
      title: 'Public Key',
      icon: Icons.vpn_key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Public Key Content',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showPublicKey = !_showPublicKey;
                  });
                },
                icon: Icon(
                  _showPublicKey ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                ),
                label: Text(_showPublicKey ? 'Hide' : 'Show'),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          if (_showPublicKey) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDarkMode ? AppTheme.darkBackground : AppTheme.lightBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sshKey.publicKey,
                    style: context.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => SshKeyUtils.copyPublicKey(widget.sshKey.publicKey, context),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // TODO: Implement export functionality
                          },
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.isDarkMode 
                    ? AppTheme.darkTextSecondary.withValues(alpha: 0.1)
                    : AppTheme.lightTextSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off,
                    color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Public key is hidden for security',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}