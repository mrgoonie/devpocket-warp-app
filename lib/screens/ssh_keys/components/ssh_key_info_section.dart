import 'package:flutter/material.dart';
import '../../../models/ssh_models.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';
import '../utils/ssh_key_utils.dart';
import 'ssh_key_common_widgets.dart';

/// SSH key information section showing algorithm, size, dates, and fingerprint
class SshKeyInfoSection extends StatefulWidget {
  final SshKeyRecord sshKey;

  const SshKeyInfoSection({
    super.key,
    required this.sshKey,
  });

  @override
  State<SshKeyInfoSection> createState() => _SshKeyInfoSectionState();
}

class _SshKeyInfoSectionState extends State<SshKeyInfoSection> {
  bool _showFullFingerprint = false;

  @override
  Widget build(BuildContext context) {
    return SshKeySection(
      title: 'Key Information',
      icon: Icons.info,
      child: Column(
        children: [
          SshKeyInfoRow(label: 'Algorithm', value: widget.sshKey.keyType.algorithm.toUpperCase()),
          SshKeyInfoRow(label: 'Key Size', value: '${widget.sshKey.keyType.keySize} bits'),
          SshKeyInfoRow(label: 'Created', value: SshKeyUtils.formatDateTime(widget.sshKey.createdAt)),
          if (widget.sshKey.lastUsed != null)
            SshKeyInfoRow(label: 'Last Used', value: SshKeyUtils.formatDateTime(widget.sshKey.lastUsed!))
          else
            const SshKeyInfoRow(label: 'Last Used', value: 'Never'),
          SshKeyInfoRow(
            label: 'Fingerprint',
            value:
            GestureDetector(
              onTap: () {
                setState(() {
                  _showFullFingerprint = !_showFullFingerprint;
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _showFullFingerprint
                          ? widget.sshKey.fingerprint
                          : '${widget.sshKey.fingerprint.substring(0, 20)}...',
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: AppTheme.primaryColor,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Icon(
                    _showFullFingerprint ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}