import 'package:flutter/material.dart';
import '../../../models/ssh_models.dart';
import '../../../main.dart';
import '../utils/ssh_key_utils.dart';

/// SSH key header component showing key name, type, and visual indicator
class SshKeyHeader extends StatelessWidget {
  final SshKeyRecord sshKey;

  const SshKeyHeader({
    super.key,
    required this.sshKey,
  });

  @override
  Widget build(BuildContext context) {
    final keyTypeColor = SshKeyUtils.getKeyTypeColor(sshKey.keyType);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            keyTypeColor.withValues(alpha: 0.1),
            keyTypeColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: keyTypeColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: keyTypeColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: keyTypeColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: Icon(
              SshKeyUtils.getKeyTypeIcon(sshKey.keyType),
              color: keyTypeColor,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sshKey.name,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: keyTypeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sshKey.keyType.displayName,
                    style: context.textTheme.labelMedium?.copyWith(
                      color: keyTypeColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}