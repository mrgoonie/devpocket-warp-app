import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../themes/app_theme.dart';
import '../../models/ssh_profile_models.dart';
import '../../providers/ssh_host_providers.dart';
import '../../widgets/custom_text_field.dart';

class HostEditScreen extends ConsumerStatefulWidget {
  final SshProfile? host;

  const HostEditScreen({super.key, this.host});

  @override
  ConsumerState<HostEditScreen> createState() => _HostEditScreenState();
}

class _HostEditScreenState extends ConsumerState<HostEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _privateKeyController = TextEditingController();
  final _passphraseController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  SshAuthType _authType = SshAuthType.password;
  bool _isPasswordVisible = false;
  bool _isPassphraseVisible = false;
  bool _isLoading = false;

  static const Uuid _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.host != null) {
      final host = widget.host!;
      _nameController.text = host.name;
      _hostController.text = host.host;
      _portController.text = host.port.toString();
      _usernameController.text = host.username;
      _passwordController.text = host.password ?? '';
      _privateKeyController.text = host.privateKey ?? '';
      _passphraseController.text = host.passphrase ?? '';
      _descriptionController.text = host.description ?? '';
      _tagsController.text = host.tags.join(', ');
      _authType = host.authType;
    } else {
      _portController.text = '22'; // Default SSH port
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    _passphraseController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.host != null;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit SSH Host' : 'Add SSH Host'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.wifi_find),
              onPressed: _testConnection,
              tooltip: 'Test Connection',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveHost,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicSection(),
            const SizedBox(height: 24),
            _buildConnectionSection(),
            const SizedBox(height: 24),
            _buildAuthenticationSection(),
            const SizedBox(height: 24),
            _buildAdvancedSection(),
            const SizedBox(height: 32),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicSection() {
    return _buildSection(
      title: 'Basic Information',
      icon: Icons.info_outline,
      children: [
        CustomTextField(
          controller: _nameController,
          label: 'Host Name',
          hint: 'My Server',
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Host name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _descriptionController,
          label: 'Description (Optional)',
          hint: 'Production web server',
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _tagsController,
              label: 'Tags (Optional)',
              hint: 'production, web, backend',
            ),
            const SizedBox(height: 4),
            Text(
              'Separate multiple tags with commas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectionSection() {
    return _buildSection(
      title: 'Connection Details',
      icon: Icons.computer,
      children: [
        CustomTextField(
          controller: _hostController,
          label: 'Host Address',
          hint: 'example.com or 192.168.1.100',
          validator: (value) {
            if (value?.isEmpty ?? true) {
              return 'Host address is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: CustomTextField(
                controller: _portController,
                label: 'Port',
                hint: '22',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Port is required';
                  }
                  final port = int.tryParse(value!);
                  if (port == null || port < 1 || port > 65535) {
                    return 'Invalid port (1-65535)';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: CustomTextField(
                controller: _usernameController,
                label: 'Username',
                hint: 'root',
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Username is required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthenticationSection() {
    return _buildSection(
      title: 'Authentication',
      icon: Icons.security,
      children: [
        _buildAuthTypeSelector(),
        const SizedBox(height: 16),
        ..._buildAuthFields(),
      ],
    );
  }

  Widget _buildAuthTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Authentication Method',
          style: TextStyle(
            color: AppTheme.darkTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorderColor),
          ),
          child: Column(
            children: [
              RadioListTile<SshAuthType>(
                title: const Text(
                  'Password',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                subtitle: const Text(
                  'Use password authentication',
                  style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                ),
                value: SshAuthType.password,
                groupValue: _authType,
                onChanged: (value) {
                  setState(() {
                    _authType = value!;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
              RadioListTile<SshAuthType>(
                title: const Text(
                  'SSH Key',
                  style: TextStyle(color: AppTheme.darkTextPrimary),
                ),
                subtitle: const Text(
                  'Use private key authentication (with optional passphrase)',
                  style: TextStyle(color: AppTheme.darkTextSecondary, fontSize: 12),
                ),
                value: SshAuthType.key,
                groupValue: _authType,
                onChanged: (value) {
                  setState(() {
                    _authType = value!;
                  });
                },
                activeColor: AppTheme.primaryColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAuthFields() {
    switch (_authType) {
      case SshAuthType.password:
        return [
          CustomTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter password',
            obscureText: !_isPasswordVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.darkTextSecondary,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Password is required';
              }
              return null;
            },
          ),
        ];

      case SshAuthType.key:
        return [
          CustomTextField(
            controller: _privateKeyController,
            label: 'Private Key',
            hint: 'Paste your private key here',
            maxLines: 8,
            // Remove obscureText for SSH keys as they need to be multiline and visible
            // SSH keys should be visible for proper formatting verification
            suffixIcon: IconButton(
              icon: Icon(
                Icons.copy,
                color: AppTheme.darkTextSecondary,
              ),
              onPressed: () {
                // Copy functionality instead of visibility toggle
                if (_privateKeyController.text.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: _privateKeyController.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Private key copied to clipboard')),
                  );
                }
              },
            ),
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return 'Private key is required';
              }
              if (!value!.contains('BEGIN') || !value.contains('PRIVATE KEY')) {
                return 'Invalid private key format';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _passphraseController,
            label: 'Passphrase (Optional)',
            hint: 'Enter key passphrase if required',
            obscureText: !_isPassphraseVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _isPassphraseVisible ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.darkTextSecondary,
              ),
              onPressed: () {
                setState(() {
                  _isPassphraseVisible = !_isPassphraseVisible;
                });
              },
            ),
          ),
        ];

    }
  }

  Widget _buildAdvancedSection() {
    return _buildSection(
      title: 'Advanced Options',
      icon: Icons.tune,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorderColor),
          ),
          child: const Column(
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.terminalBlue, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Advanced SSH options (compression, keep-alive, timeouts) will be available in a future update.',
                      style: TextStyle(
                        color: AppTheme.darkTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.darkBorderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.darkTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isEditing = widget.host != null;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveHost,
            icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Icon(isEditing ? Icons.save : Icons.add),
            label: Text(
              _isLoading 
                  ? (isEditing ? 'Updating...' : 'Creating...')
                  : (isEditing ? 'Update Host' : 'Create Host'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (isEditing) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _testConnection,
              icon: const Icon(Icons.wifi_find),
              label: const Text('Test Connection'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.terminalBlue,
                side: const BorderSide(color: AppTheme.terminalBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _saveHost() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now();
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      final host = SshProfile(
        id: widget.host?.id ?? _uuid.v4(),
        name: _nameController.text.trim(),
        host: _hostController.text.trim(),
        port: int.parse(_portController.text),
        username: _usernameController.text.trim(),
        authType: _authType,
        password: _authType == SshAuthType.password 
            ? _passwordController.text 
            : null,
        privateKey: _authType == SshAuthType.key
            ? _privateKeyController.text 
            : null,
        passphrase: _authType == SshAuthType.key && _passphraseController.text.isNotEmpty
            ? _passphraseController.text 
            : null,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        tags: tags,
        createdAt: widget.host?.createdAt ?? now,
        updatedAt: now,
      );

      bool success;
      if (widget.host != null) {
        success = await ref.read(sshHostsProvider.notifier).updateHost(host);
      } else {
        success = await ref.read(sshHostsProvider.notifier).addHost(host);
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.host != null 
                    ? 'Host updated successfully' 
                    : 'Host created successfully',
              ),
              backgroundColor: AppTheme.terminalGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.host != null 
                    ? 'Failed to update host' 
                    : 'Failed to create host',
              ),
              backgroundColor: AppTheme.terminalRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.terminalRed,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fix the form errors first'),
            backgroundColor: AppTheme.terminalRed,
          ),
        );
      }
      return;
    }

    // Create temporary host for testing
    final testHost = SshProfile(
      id: 'temp',
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.parse(_portController.text),
      username: _usernameController.text.trim(),
      authType: _authType,
      password: _authType == SshAuthType.password 
          ? _passwordController.text 
          : null,
      privateKey: _authType == SshAuthType.key
          ? _privateKeyController.text 
          : null,
      passphrase: _authType == SshAuthType.key && _passphraseController.text.isNotEmpty
          ? _passphraseController.text 
          : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text(
              'Testing connection...',
              style: TextStyle(color: AppTheme.darkTextPrimary),
            ),
          ],
        ),
      ),
    );

    try {
      final result = await ref.read(sshHostsProvider.notifier).testConnection(testHost);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog

        // Show result dialog
        showDialog(
          context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkSurface,
          title: Text(
            result.success ? 'Connection Successful' : 'Connection Failed',
            style: TextStyle(
              color: result.success ? AppTheme.terminalGreen : AppTheme.terminalRed,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.responseTime != null)
                Text(
                  'Response time: ${result.responseTime!.inMilliseconds}ms',
                  style: const TextStyle(color: AppTheme.darkTextSecondary),
                ),
              if (result.message != null)
                Text(
                  result.message!,
                  style: const TextStyle(color: AppTheme.darkTextPrimary),
                ),
              if (result.error != null)
                Text(
                  result.error!,
                  style: const TextStyle(color: AppTheme.terminalRed),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'OK',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
      );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Test failed: $e'),
            backgroundColor: AppTheme.terminalRed,
          ),
        );
      }
    }
  }
}