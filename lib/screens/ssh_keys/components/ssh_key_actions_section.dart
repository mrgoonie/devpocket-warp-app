import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ssh_models.dart';
import '../utils/ssh_key_utils.dart';
import 'ssh_key_common_widgets.dart';

/// SSH key actions section with buttons for copy, export, edit, and delete
class SshKeyActionsSection extends ConsumerWidget {
  final SshKeyRecord sshKey;

  const SshKeyActionsSection({
    super.key,
    required this.sshKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SshKeySection(
      title: 'Actions',
      icon: Icons.build,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton.icon(
            onPressed: () => SshKeyUtils.copyPublicKey(sshKey.publicKey, context),
            icon: const Icon(Icons.copy),
            label: const Text('Copy Public Key'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              // TODO: Implement export functionality
            },
            icon: const Icon(Icons.download),
            label: const Text('Export Key'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => SshKeyUtils.editKeyName(context, ref, sshKey),
            icon: const Icon(Icons.edit),
            label: const Text('Edit Name'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => SshKeyUtils.deleteKey(context, ref, sshKey),
            icon: const Icon(Icons.delete),
            label: const Text('Delete Key'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}