import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/ai_provider.dart';
import '../../models/ai_models.dart';
import '../../themes/app_theme.dart';
import '../../main.dart';
import '../auth/login_screen.dart';
import 'api_key_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeProvider);
    final hasValidKey = ref.watch(hasValidApiKeyProvider);
    final aiUsage = ref.watch(aiUsageProvider);
    final aiSettings = ref.watch(aiFeatureSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          _buildProfileSection(context, user),
          
          const SizedBox(height: 24),

          // AI Configuration Section
          _buildSectionHeader(context, 'AI Features'),
          const SizedBox(height: 12),
          
          _buildAIStatusCard(context, hasValidKey, aiUsage),
          
          _buildSettingCard(
            context: context,
            icon: hasValidKey ? Icons.psychology : Icons.psychology_outlined,
            title: 'AI Configuration',
            subtitle: hasValidKey 
                ? 'API key configured - ${aiUsage.requestCount} requests used'
                : 'Configure OpenRouter API key for AI features',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ApiKeyScreen()),
            ),
            trailing: hasValidKey 
                ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                : const Icon(Icons.warning, color: Colors.orange, size: 20),
          ),
          
          const SizedBox(height: 24),
          
          // App Settings
          _buildSectionHeader(context, 'App Settings'),
          const SizedBox(height: 12),
          
          _buildSettingCard(
            context: context,
            icon: Icons.color_lens,
            title: 'Theme',
            subtitle: _getThemeDescription(themeMode),
            onTap: () => _showThemeDialog(context, ref),
          ),
          
          _buildSettingCard(
            context: context,
            icon: Icons.text_fields,
            title: 'Terminal Font',
            subtitle: 'JetBrains Mono - 14pt',
            onTap: () => _showFontDialog(context, ref),
          ),
          
          _buildSettingCard(
            context: context,
            icon: Icons.palette,
            title: 'Terminal Theme',
            subtitle: 'GitHub Dark',
            onTap: () => _showTerminalThemeDialog(context, ref),
          ),
          
          const SizedBox(height: 24),
          
          // Security
          _buildSectionHeader(context, 'Security'),
          const SizedBox(height: 12),
          
          _buildSettingCard(
            context: context,
            icon: Icons.lock,
            title: 'Change Password',
            subtitle: 'Update your account password',
            onTap: () => _showChangePasswordDialog(context),
          ),
          
          const SizedBox(height: 24),
          
          // Support
          _buildSectionHeader(context, 'Support'),
          const SizedBox(height: 12),
          
          _buildSettingCard(
            context: context,
            icon: Icons.help_outline,
            title: 'Help & Documentation',
            subtitle: 'Learn how to use DevPocket',
            onTap: () => _openDocumentation(),
          ),
          
          _buildSettingCard(
            context: context,
            icon: Icons.bug_report,
            title: 'Report a Bug',
            subtitle: 'Help us improve DevPocket',
            onTap: () => _reportBug(context),
          ),
          
          _buildSettingCard(
            context: context,
            icon: Icons.star_outline,
            title: 'Rate DevPocket',
            subtitle: 'Love the app? Let us know!',
            onTap: () => _rateApp(),
          ),
          
          const SizedBox(height: 24),
          
          // About
          _buildSectionHeader(context, 'About'),
          const SizedBox(height: 12),
          
          _buildSettingCard(
            context: context,
            icon: Icons.info_outline,
            title: 'Version',
            subtitle: '1.0.0 (Build 100)',
            showArrow: false,
          ),
          
          const SizedBox(height: 32),
          
          // Logout Button
          _buildLogoutButton(context, ref),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, user) {
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
                    style: context.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Not logged in',
                    style: context.textTheme.bodyMedium?.copyWith(
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
              onPressed: () => _showEditProfileDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: context.textTheme.labelLarge?.copyWith(
        color: AppTheme.primaryColor,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildAIStatusCard(BuildContext context, bool hasValidKey, AIUsageStats usage) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasValidKey
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasValidKey
                ? [
                    AppTheme.primaryColor.withValues(alpha: 0.1),
                    AppTheme.primaryColor.withValues(alpha: 0.05),
                  ]
                : [
                    Colors.orange.withValues(alpha: 0.1),
                    Colors.orange.withValues(alpha: 0.05),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasValidKey ? Icons.psychology : Icons.warning,
                  color: hasValidKey ? AppTheme.primaryColor : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasValidKey ? 'AI Features Active' : 'AI Features Disabled',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: hasValidKey ? AppTheme.primaryColor : Colors.orange,
                        ),
                      ),
                      Text(
                        hasValidKey 
                            ? 'Agent Mode, Smart Suggestions, Error Explanations'
                            : 'Configure OpenRouter API key to enable',
                        style: TextStyle(
                          fontSize: 14,
                          color: (hasValidKey ? AppTheme.primaryColor : Colors.orange).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (hasValidKey) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildUsageMetric(
                      'Requests',
                      usage.requestCount.toString(),
                      Icons.send,
                    ),
                  ),
                  Expanded(
                    child: _buildUsageMetric(
                      'Cost',
                      '\$${usage.estimatedCost.toStringAsFixed(3)}',
                      Icons.attach_money,
                    ),
                  ),
                  Expanded(
                    child: _buildUsageMetric(
                      'Tokens',
                      '${(usage.tokenCount / 1000).toStringAsFixed(1)}K',
                      Icons.token,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsageMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool showArrow = true,
    Widget? trailing,
  }) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: AppTheme.darkTextSecondary,
          ),
        ),
        trailing: trailing ?? (showArrow 
            ? const Icon(Icons.chevron_right, color: AppTheme.darkTextSecondary)
            : null),
        onTap: onTap,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _handleLogout(context, ref),
        icon: const Icon(Icons.logout, color: AppTheme.terminalRed),
        label: const Text(
          'Sign Out',
          style: TextStyle(color: AppTheme.terminalRed),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppTheme.terminalRed, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  String _getThemeDescription(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
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

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Choose Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: ref.read(themeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).setTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: ref.read(themeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).setTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('System'),
              value: ThemeMode.system,
              groupValue: ref.read(themeProvider),
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeProvider.notifier).setTheme(value);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showFontDialog(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Font settings coming soon!')),
    );
  }

  void _showTerminalThemeDialog(BuildContext context, WidgetRef ref) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terminal theme settings coming soon!')),
    );
  }


  void _showChangePasswordDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change password feature coming soon!')),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit profile feature coming soon!')),
    );
  }

  void _openDocumentation() {
    // TODO: Open documentation URL
  }

  void _reportBug(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug report feature coming soon!')),
    );
  }

  void _rateApp() {
    // TODO: Open app store rating
  }

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.terminalRed,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}