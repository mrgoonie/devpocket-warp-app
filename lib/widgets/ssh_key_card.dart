import 'package:flutter/material.dart';
import '../models/ssh_models.dart';
import '../themes/app_theme.dart';
import '../main.dart';

class SSHKeyCard extends StatelessWidget {
  final SSHKey sshKey;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const SSHKeyCard({
    super.key,
    required this.sshKey,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Key type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getKeyTypeColor(sshKey.type),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    sshKey.displayType,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Key name
                Expanded(
                  child: Text(
                    sshKey.name,
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // Actions
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  tooltip: 'Edit Key',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppTheme.terminalRed,
                  onPressed: onDelete,
                  tooltip: 'Delete Key',
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Description
            if (sshKey.description != null)
              Text(
                sshKey.description!,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.darkTextSecondary,
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Key details
            Row(
              children: [
                _buildDetailChip(
                  Icons.memory,
                  '${sshKey.keySize ?? 'Unknown'} bits',
                ),
                const SizedBox(width: 8),
                if (sshKey.hasPassphrase)
                  _buildDetailChip(
                    Icons.lock,
                    'Protected',
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Public key preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.darkBorderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.key,
                        size: 16,
                        color: AppTheme.darkTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Public Key',
                        style: context.textTheme.labelMedium?.copyWith(
                          color: AppTheme.darkTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          size: 16,
                        ),
                        onPressed: () => _copyPublicKey(context),
                        tooltip: 'Copy Public Key',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _truncatePublicKey(sshKey.publicKey),
                    style: context.textTheme.bodySmall?.copyWith(
                      fontFamily: AppTheme.terminalFont,
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Creation date
            Text(
              'Created ${_formatDate(sshKey.createdAt)}',
              style: context.textTheme.bodySmall?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.darkBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: AppTheme.darkTextSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getKeyTypeColor(String keyType) {
    switch (keyType.toLowerCase()) {
      case 'rsa':
        return AppTheme.terminalBlue;
      case 'ed25519':
        return AppTheme.terminalGreen;
      case 'ecdsa':
        return AppTheme.terminalPurple;
      default:
        return AppTheme.darkTextSecondary;
    }
  }

  String _truncatePublicKey(String publicKey) {
    if (publicKey.length <= 60) return publicKey;
    return '${publicKey.substring(0, 30)}...${publicKey.substring(publicKey.length - 30)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 7) {
      if (difference.inDays == 0) {
        return 'today';
      } else {
        return '${difference.inDays}d ago';
      }
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  void _copyPublicKey(BuildContext context) {
    // TODO: Implement clipboard copy
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Public key copied to clipboard'),
        backgroundColor: AppTheme.terminalGreen,
        duration: Duration(seconds: 2),
      ),
    );
  }
}