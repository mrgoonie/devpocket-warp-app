import 'package:flutter/material.dart';
import '../../../models/ssh_models.dart';
import '../utils/ssh_key_utils.dart';
import 'ssh_key_common_widgets.dart';

/// SSH key usage information section showing status, age, and metadata
class SshKeyUsageSection extends StatelessWidget {
  final SshKeyRecord sshKey;

  const SshKeyUsageSection({
    super.key,
    required this.sshKey,
  });

  @override
  Widget build(BuildContext context) {
    return SshKeySection(
      title: 'Usage',
      icon: Icons.analytics,
      child: Column(
        children: [
          SshKeyInfoRow(label: 'Status', value: sshKey.lastUsed != null ? 'Active' : 'Unused'),
          SshKeyInfoRow(label: 'Age', value: SshKeyUtils.getKeyAge(sshKey.createdAt)),
          if (sshKey.metadata.isNotEmpty)
            ...sshKey.metadata.entries.map((entry) => 
              SshKeyInfoRow(
                label: SshKeyUtils.formatMetadataKey(entry.key),
                value: entry.value.toString(),
              ),
            ),
        ],
      ),
    );
  }
}