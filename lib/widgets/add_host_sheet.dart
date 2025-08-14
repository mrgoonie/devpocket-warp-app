import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ssh_models.dart';
import '../providers/ssh_providers.dart';
import '../themes/app_theme.dart';
import '../main.dart';
import 'custom_text_field.dart';

class AddHostSheet extends ConsumerStatefulWidget {
  final Host? host; // For editing existing host

  const AddHostSheet({super.key, this.host});

  @override
  ConsumerState<AddHostSheet> createState() => _AddHostSheetState();
}

class _AddHostSheetState extends ConsumerState<AddHostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostnameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _descriptionController = TextEditingController();

  AuthMethod _authMethod = AuthMethod.password;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.host != null) {
      _populateFields(widget.host!);
    }
  }

  void _populateFields(Host host) {
    _nameController.text = host.name;
    _hostnameController.text = host.hostname;
    _usernameController.text = host.username;
    _passwordController.text = host.password ?? '';
    _portController.text = host.port.toString();
    _descriptionController.text = host.description ?? '';
    _authMethod = host.authMethod;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _portController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                
                const SizedBox(height: 24),
                
                // Form fields
                _buildFormFields(),
                
                const SizedBox(height: 32),
                
                // Actions
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.host != null ? 'Edit Host' : 'Add New Host',
            style: context.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Basic Info Section
        _buildSectionHeader('Basic Information'),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _nameController,
          label: 'Host Name',
          prefixIcon: Icons.label_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a host name';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 16),
        
        Row(
          children: [
            Expanded(
              flex: 3,
              child: CustomTextField(
                controller: _hostnameController,
                label: 'Hostname / IP',
                prefixIcon: Icons.dns_outlined,
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter hostname';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 1,
              child: CustomTextField(
                controller: _portController,
                label: 'Port',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Port required';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port < 1 || port > 65535) {
                    return 'Invalid port';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _usernameController,
          label: 'Username',
          prefixIcon: Icons.person_outline,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter username';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        // Authentication Section
        _buildSectionHeader('Authentication'),
        const SizedBox(height: 16),
        
        // Auth method selector
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.darkBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.darkBorderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildAuthMethodButton(
                  'Password',
                  AuthMethod.password,
                  Icons.lock_outline,
                ),
              ),
              Expanded(
                child: _buildAuthMethodButton(
                  'SSH Key',
                  AuthMethod.publicKey,
                  Icons.key_outlined,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Auth method specific fields
        if (_authMethod == AuthMethod.password)
          PasswordTextField(
            controller: _passwordController,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter password';
              }
              return null;
            },
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.darkBorderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.key, color: AppTheme.terminalGreen),
                    const SizedBox(width: 8),
                    const Text('SSH Key Authentication'),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        // TODO: Show key selector
                      },
                      child: const Text('Select Key'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'SSH key authentication is more secure. Select an existing key or add a new one.',
                  style: TextStyle(
                    color: AppTheme.darkTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        
        const SizedBox(height: 24),
        
        // Optional Section
        _buildSectionHeader('Optional'),
        const SizedBox(height: 16),
        
        CustomTextField(
          controller: _descriptionController,
          label: 'Description',
          prefixIcon: Icons.description_outlined,
          maxLines: 2,
          hint: 'Brief description of this host',
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: context.textTheme.titleMedium?.copyWith(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: AppTheme.darkBorderColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthMethodButton(String label, AuthMethod method, IconData icon) {
    final isSelected = _authMethod == method;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _authMethod = method;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.black : AppTheme.darkTextSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.black : AppTheme.darkTextSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppTheme.darkBorderColor, width: 2),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _saveHost,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(widget.host != null ? 'Update Host' : 'Add Host'),
          ),
        ),
      ],
    );
  }

  Future<void> _saveHost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final host = widget.host?.copyWith(
        name: _nameController.text.trim(),
        hostname: _hostnameController.text.trim(),
        username: _usernameController.text.trim(),
        port: int.parse(_portController.text.trim()),
        password: _authMethod == AuthMethod.password ? _passwordController.text : null,
        authMethod: _authMethod,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
        updatedAt: DateTime.now(),
      ) ?? HostFactory.create(
        name: _nameController.text.trim(),
        hostname: _hostnameController.text.trim(),
        username: _usernameController.text.trim(),
        port: int.parse(_portController.text.trim()),
        password: _authMethod == AuthMethod.password ? _passwordController.text : null,
        authMethod: _authMethod,
        description: _descriptionController.text.trim().isNotEmpty 
            ? _descriptionController.text.trim() 
            : null,
      );

      if (widget.host != null) {
        await ref.read(hostsProvider.notifier).updateHost(host);
      } else {
        await ref.read(hostsProvider.notifier).addHost(host);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.host != null 
                  ? 'Host updated successfully' 
                  : 'Host added successfully',
            ),
            backgroundColor: AppTheme.terminalGreen,
          ),
        );
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}