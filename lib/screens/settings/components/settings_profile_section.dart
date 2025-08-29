import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';

/// Profile section component displaying user information and edit option
class SettingsProfileSection extends StatelessWidget {
  final dynamic user;
  final VoidCallback onEditProfile;

  const SettingsProfileSection({
    super.key,
    required this.user,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.primaryColor,
              backgroundImage: user?.avatarUrl != null 
                  ? NetworkImage(user!.avatarUrl!)
                  : null,
              child: user?.avatarUrl == null 
                  ? Text(
                      (user?.username?.substring(0, 1).toUpperCase() ?? 'U'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? user?.username ?? 'Guest User',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Not logged in',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _getSubscriptionStatus(user),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEditProfile,
            ),
          ],
        ),
      ),
    );
  }

  String _getSubscriptionStatus(user) {
    if (user == null) return 'Free';
    if (user.isInTrial) {
      final daysLeft = user.trialDaysLeft;
      return 'Trial - $daysLeft days left';
    }
    switch (user.subscriptionTier) {
      case 'pro':
        return 'Pro';
      case 'team':
        return 'Team';
      default:
        return 'Free';
    }
  }
}