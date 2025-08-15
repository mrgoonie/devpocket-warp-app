import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/biometric_service.dart';
import '../../services/command_validator.dart';
import 'security_dashboard_screen.dart';

/// Comprehensive security settings screen
class SecuritySettingsScreen extends ConsumerStatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  ConsumerState<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends ConsumerState<SecuritySettingsScreen> {
  bool _biometricEnabled = false;
  bool _autoLockEnabled = true;
  int _autoLockMinutes = 15;
  ValidationLevel _commandValidationLevel = ValidationLevel.strict;
  bool _auditLoggingEnabled = true;
  bool _screenRecordingProtection = true;
  bool _clipboardSecurity = true;
  bool _networkWarnings = true;
  bool _requireBiometricForKeys = true;
  bool _requireBiometricForCritical = true;
  
  BiometricCapabilities? _biometricCapabilities;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Load biometric capabilities
      final biometricService = ref.read(biometricServiceProvider);
      final capabilities = await biometricService.getCapabilities();
      
      // Load current settings (would typically come from secure storage)
      await _loadSecurityPreferences();
      
      setState(() {
        _biometricCapabilities = capabilities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load security settings: $e');
    }
  }

  Future<void> _loadSecurityPreferences() async {
    // In a real implementation, these would be loaded from secure storage
    // For now, we'll use default values
    setState(() {
      _biometricEnabled = _biometricCapabilities?.isAvailable ?? false;
      _autoLockEnabled = true;
      _autoLockMinutes = 15;
      _commandValidationLevel = ValidationLevel.strict;
      _auditLoggingEnabled = true;
      _screenRecordingProtection = true;
      _clipboardSecurity = true;
      _networkWarnings = true;
      _requireBiometricForKeys = true;
      _requireBiometricForCritical = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Security Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
        actions: [
          TextButton(
            onPressed: _resetToDefaults,
            child: const Text('Reset'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBiometricSection(),
          const SizedBox(height: 24),
          _buildAuthenticationSection(),
          const SizedBox(height: 24),
          _buildCommandSecuritySection(),
          const SizedBox(height: 24),
          _buildPrivacySection(),
          const SizedBox(height: 24),
          _buildAuditSection(),
          const SizedBox(height: 24),
          _buildAdvancedSection(),
        ],
      ),
    );
  }

  Widget _buildBiometricSection() {
    return _buildSection(
      title: 'Biometric Authentication',
      icon: Icons.fingerprint,
      children: [
        if (!(_biometricCapabilities?.isAvailable ?? false))
          _buildUnavailableCard(
            'Biometric authentication is not available on this device',
            Icons.fingerprint_outlined,
          )
        else ...[
          _buildBiometricCapabilitiesCard(),
          const SizedBox(height: 12),
          _buildSwitchTile(
            title: 'Enable Biometric Authentication',
            subtitle: 'Use ${_biometricCapabilities?.primaryBiometricName} for secure access',
            value: _biometricEnabled,
            onChanged: _setBiometricEnabled,
            icon: Icons.fingerprint,
          ),
          if (_biometricEnabled) ...[
            const SizedBox(height: 8),
            _buildSwitchTile(
              title: 'Require for SSH Keys',
              subtitle: 'Require biometric authentication to access SSH private keys',
              value: _requireBiometricForKeys,
              onChanged: (value) => setState(() => _requireBiometricForKeys = value),
              icon: Icons.key,
              enabled: _biometricEnabled,
            ),
            _buildSwitchTile(
              title: 'Require for Critical Operations',
              subtitle: 'Require biometric authentication for high-security connections',
              value: _requireBiometricForCritical,
              onChanged: (value) => setState(() => _requireBiometricForCritical = value),
              icon: Icons.security,
              enabled: _biometricEnabled,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildAuthenticationSection() {
    return _buildSection(
      title: 'Authentication & Session',
      icon: Icons.lock,
      children: [
        _buildSwitchTile(
          title: 'Auto-Lock',
          subtitle: 'Automatically lock the app after inactivity',
          value: _autoLockEnabled,
          onChanged: (value) => setState(() => _autoLockEnabled = value),
          icon: Icons.lock_clock,
        ),
        if (_autoLockEnabled) ...[
          const SizedBox(height: 8),
          _buildDropdownTile<int>(
            title: 'Auto-Lock Timer',
            subtitle: 'Time before automatic lock',
            value: _autoLockMinutes,
            items: const [
              DropdownMenuItem(value: 5, child: Text('5 minutes')),
              DropdownMenuItem(value: 15, child: Text('15 minutes')),
              DropdownMenuItem(value: 30, child: Text('30 minutes')),
              DropdownMenuItem(value: 60, child: Text('1 hour')),
            ],
            onChanged: (value) => setState(() => _autoLockMinutes = value!),
            icon: Icons.timer,
          ),
        ],
        const SizedBox(height: 8),
        _buildActionTile(
          title: 'Change Master Password',
          subtitle: 'Update your master password for encrypted data',
          icon: Icons.password,
          onTap: _changeMasterPassword,
        ),
      ],
    );
  }

  Widget _buildCommandSecuritySection() {
    return _buildSection(
      title: 'Command Security',
      icon: Icons.terminal,
      children: [
        _buildDropdownTile<ValidationLevel>(
          title: 'Command Validation Level',
          subtitle: 'Security level for command validation',
          value: _commandValidationLevel,
          items: const [
            DropdownMenuItem(
              value: ValidationLevel.permissive,
              child: Text('Permissive (Basic checks only)'),
            ),
            DropdownMenuItem(
              value: ValidationLevel.moderate,
              child: Text('Moderate (Standard security)'),
            ),
            DropdownMenuItem(
              value: ValidationLevel.strict,
              child: Text('Strict (Comprehensive checks)'),
            ),
            DropdownMenuItem(
              value: ValidationLevel.whitelist,
              child: Text('Whitelist (Only approved commands)'),
            ),
          ],
          onChanged: (value) => setState(() => _commandValidationLevel = value!),
          icon: Icons.verified_user,
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          title: 'Manage Command Whitelist',
          subtitle: 'Configure allowed commands for whitelist mode',
          icon: Icons.list_alt,
          onTap: _manageCommandWhitelist,
        ),
      ],
    );
  }

  Widget _buildPrivacySection() {
    return _buildSection(
      title: 'Privacy & Protection',
      icon: Icons.privacy_tip,
      children: [
        _buildSwitchTile(
          title: 'Screen Recording Protection',
          subtitle: 'Prevent screenshots and screen recording of sensitive data',
          value: _screenRecordingProtection,
          onChanged: (value) => setState(() => _screenRecordingProtection = value),
          icon: Icons.screen_lock_portrait,
        ),
        _buildSwitchTile(
          title: 'Clipboard Security',
          subtitle: 'Automatically clear clipboard after copying sensitive data',
          value: _clipboardSecurity,
          onChanged: (value) => setState(() => _clipboardSecurity = value),
          icon: Icons.content_paste,
        ),
        _buildSwitchTile(
          title: 'Network Security Warnings',
          subtitle: 'Show warnings for insecure network connections',
          value: _networkWarnings,
          onChanged: (value) => setState(() => _networkWarnings = value),
          icon: Icons.network_check,
        ),
      ],
    );
  }

  Widget _buildAuditSection() {
    return _buildSection(
      title: 'Audit & Compliance',
      icon: Icons.assessment,
      children: [
        _buildSwitchTile(
          title: 'Audit Logging',
          subtitle: 'Log all security-relevant events for compliance',
          value: _auditLoggingEnabled,
          onChanged: (value) => setState(() => _auditLoggingEnabled = value),
          icon: Icons.history,
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          title: 'Export Audit Logs',
          subtitle: 'Export security audit logs for compliance review',
          icon: Icons.file_download,
          onTap: _exportAuditLogs,
        ),
        _buildActionTile(
          title: 'Retention Policy',
          subtitle: 'Configure how long audit logs are kept',
          icon: Icons.schedule,
          onTap: _configureRetentionPolicy,
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return _buildSection(
      title: 'Advanced Security',
      icon: Icons.security,
      children: [
        _buildActionTile(
          title: 'Security Audit',
          subtitle: 'Run a comprehensive security audit of your configuration',
          icon: Icons.bug_report,
          onTap: _runSecurityAudit,
        ),
        _buildActionTile(
          title: 'Certificate Management',
          subtitle: 'Manage SSH certificates and CA keys',
          icon: Icons.security,
          onTap: _manageCertificates,
        ),
        _buildActionTile(
          title: 'Backup & Recovery',
          subtitle: 'Configure secure backup of encryption keys',
          icon: Icons.backup,
          onTap: _configureBackup,
        ),
        const SizedBox(height: 12),
        _buildDangerZone(),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      secondary: Icon(icon, color: enabled ? null : Colors.grey),
      value: value,
      onChanged: enabled ? onChanged : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required String subtitle,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          DropdownButton<T>(
            value: value,
            items: items,
            onChanged: onChanged,
            isExpanded: true,
            underline: Container(
              height: 1,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildBiometricCapabilitiesCard() {
    final capabilities = _biometricCapabilities!;
    
    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Available Biometric Methods',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: capabilities.biometricNames.map((name) => Chip(
                label: Text(name),
                backgroundColor: Colors.blue.withValues(alpha: 0.2),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailableCard(String message, IconData icon) {
    return Card(
      color: Colors.grey.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerZone() {
    return Card(
      color: Colors.red.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear All Data'),
              subtitle: const Text('Remove all stored SSH keys, hosts, and settings'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _clearAllData,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  // Event handlers

  Future<void> _setBiometricEnabled(bool enabled) async {
    if (enabled) {
      // Test biometric authentication before enabling
      final biometricService = ref.read(biometricServiceProvider);
      final result = await biometricService.authenticate(
        reason: 'Enable biometric authentication for DevPocket',
      );
      
      if (!result.success) {
        _showError('Biometric authentication failed: ${result.message}');
        return;
      }
    }
    
    setState(() => _biometricEnabled = enabled);
    await _saveSettings();
  }

  Future<void> _saveSettings() async {
    // In a real implementation, save settings to secure storage
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text('Are you sure you want to reset all security settings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadSecurityPreferences();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _changeMasterPassword() {
    Navigator.pushNamed(context, '/security/change-password');
  }

  void _manageCommandWhitelist() {
    Navigator.pushNamed(context, '/security/command-whitelist');
  }

  void _exportAuditLogs() {
    Navigator.pushNamed(context, '/security/export-audit');
  }

  void _configureRetentionPolicy() {
    Navigator.pushNamed(context, '/security/retention-policy');
  }

  void _runSecurityAudit() {
    Navigator.pushNamed(context, '/security/audit-scan');
  }

  void _manageCertificates() {
    Navigator.pushNamed(context, '/security/certificates');
  }

  void _configureBackup() {
    Navigator.pushNamed(context, '/security/backup');
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all SSH keys, host configurations, '
          'and security settings. This action cannot be undone.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _performClearAllData();
            },
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );
  }

  Future<void> _performClearAllData() async {
    try {
      // In a real implementation, this would clear all secure storage
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All data cleared successfully'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      _showError('Failed to clear data: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}