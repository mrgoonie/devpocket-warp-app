import 'package:flutter/material.dart';
import '../../../models/ssh_models.dart';
import '../../../main.dart';
import 'ssh_key_common_widgets.dart';

/// SSH key security information section showing passphrase protection and storage details
class SshKeySecuritySection extends StatelessWidget {
  final SshKeyRecord sshKey;

  const SshKeySecuritySection({
    super.key,
    required this.sshKey,
  });

  @override
  Widget build(BuildContext context) {
    return SshKeySection(
      title: 'Security',
      icon: Icons.security,
      child: Column(
        children: [
          SshKeyInfoRow(
            label: 'Passphrase Protection',
            value:
            Row(
              children: [
                Icon(
                  sshKey.hasPassphrase ? Icons.lock : Icons.lock_open,
                  size: 16,
                  color: sshKey.hasPassphrase ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  sshKey.hasPassphrase ? 'Protected' : 'Not Protected',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: sshKey.hasPassphrase ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SshKeyInfoRow(label: 'Storage', value: 'Encrypted (AES-256-GCM)'),
          const SshKeyInfoRow(label: 'Key Format', value: 'OpenSSH'),
        ],
      ),
    );
  }
}