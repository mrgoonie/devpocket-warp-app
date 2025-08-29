import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';
import '../../models/ssh_models.dart';
import '../../providers/ssh_key_providers.dart';
import 'components/ssh_key_header.dart';
import 'components/ssh_key_info_section.dart';
import 'components/ssh_key_security_section.dart';
import 'components/ssh_key_public_section.dart';
import 'components/ssh_key_usage_section.dart';
import 'components/ssh_key_actions_section.dart';
import 'utils/ssh_key_utils.dart';

class SshKeyDetailScreen extends ConsumerStatefulWidget {
  final String keyId;

  const SshKeyDetailScreen({
    super.key,
    required this.keyId,
  });

  @override
  ConsumerState<SshKeyDetailScreen> createState() => _SshKeyDetailScreenState();
}

class _SshKeyDetailScreenState extends ConsumerState<SshKeyDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final keyAsync = ref.watch(sshKeyProvider(widget.keyId));

    return Scaffold(
      appBar: _buildAppBar(),
      body: keyAsync.when(
        data: (key) {
          if (key == null) {
            return _buildNotFound();
          }
          return _buildKeyDetails(key);
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => _buildError(error),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('SSH Key Details'),
      backgroundColor: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
      foregroundColor: context.isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
      elevation: 0,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'copy_public',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy Public Key'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Export Key'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit Name'),
                dense: true,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete Key', style: TextStyle(color: Colors.red)),
                dense: true,
              ),
            ),
          ],
          onSelected: _handleMenuAction,
        ),
      ],
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.vpn_key_off,
            size: 64,
            color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'SSH Key Not Found',
            style: context.textTheme.headlineSmall?.copyWith(
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The requested SSH key could not be found.',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error Loading SSH Key',
            style: context.textTheme.headlineSmall?.copyWith(
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => setState(() {}), // Trigger rebuild
                child: const Text('Retry'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyDetails(SshKeyRecord key) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SshKeyHeader(sshKey: key),
          const SizedBox(height: 24),
          SshKeyInfoSection(sshKey: key),
          const SizedBox(height: 24),
          SshKeySecuritySection(sshKey: key),
          const SizedBox(height: 24),
          SshKeyPublicSection(sshKey: key),
          const SizedBox(height: 24),
          SshKeyUsageSection(sshKey: key),
          const SizedBox(height: 24),
          SshKeyActionsSection(sshKey: key),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) async {
    final keyAsync = ref.read(sshKeyProvider(widget.keyId));
    final key = keyAsync.value;
    if (key == null) return;

    switch (action) {
      case 'copy_public':
        SshKeyUtils.copyPublicKey(key.publicKey, context);
        break;
      case 'export':
        // TODO: Implement export functionality
        break;
      case 'edit':
        SshKeyUtils.editKeyName(context, ref, key);
        break;
      case 'delete':
        SshKeyUtils.deleteKey(context, ref, key);
        break;
    }
  }
}