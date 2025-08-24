import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';
import '../../models/ssh_models.dart';
import '../../providers/ssh_key_providers.dart';

class SshKeyCreateScreen extends ConsumerStatefulWidget {
  const SshKeyCreateScreen({super.key});

  @override
  ConsumerState<SshKeyCreateScreen> createState() => _SshKeyCreateScreenState();
}

class _SshKeyCreateScreenState extends ConsumerState<SshKeyCreateScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _confirmPassphraseController = TextEditingController();

  SshKeyType _selectedKeyType = SshKeyType.rsa4096;
  bool _usePassphrase = false;
  bool _isGenerating = false;
  bool _obscurePassphrase = true;
  bool _obscureConfirmPassphrase = true;

  @override
  void initState() {
    super.initState();
    // Set default comment based on device
    _commentController.text = 'devpocket-mobile';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recommendedTypes = ref.watch(recommendedKeyTypesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create SSH Key'),
        backgroundColor: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
        foregroundColor: context.isDarkMode ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildKeyNameField(),
                    const SizedBox(height: 24),
                    _buildKeyTypeSelection(recommendedTypes),
                    const SizedBox(height: 24),
                    _buildCommentField(),
                    const SizedBox(height: 24),
                    _buildPassphraseSection(),
                    const SizedBox(height: 24),
                    _buildGenerationInfo(),
                  ],
                ),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Name',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: 'Enter a descriptive name for your key',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.label),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a key name';
            }
            if (value.trim().length < 3) {
              return 'Key name must be at least 3 characters';
            }
            return null;
          },
          enabled: !_isGenerating,
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a meaningful name to identify this key later',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyTypeSelection(List<SshKeyType> recommendedTypes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Key Type',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        // Recommended keys section
        Text(
          'Recommended',
          style: context.textTheme.labelMedium?.copyWith(
            color: Colors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...recommendedTypes.map((type) => _buildKeyTypeCard(type, isRecommended: true)),
        
        const SizedBox(height: 16),
        
        // Other keys section
        Text(
          'Other Options',
          style: context.textTheme.labelMedium?.copyWith(
            color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        ...SshKeyType.values
            .where((type) => !recommendedTypes.contains(type))
            .map((type) => _buildKeyTypeCard(type, isRecommended: false)),
      ],
    );
  }

  Widget _buildKeyTypeCard(SshKeyType keyType, {required bool isRecommended}) {
    final isSelected = _selectedKeyType == keyType;
    final estimatedTime = ref.watch(keyGenerationTimeProvider(keyType));
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected 
              ? AppTheme.primaryColor
              : (context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: _isGenerating ? null : () {
          setState(() {
            _selectedKeyType = keyType;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection radio
              Radio<SshKeyType>(
                value: keyType,
                groupValue: _selectedKeyType,
                onChanged: _isGenerating ? null : (value) {
                  if (value != null) {
                    setState(() {
                      _selectedKeyType = value;
                    });
                  }
                },
              ),
              
              const SizedBox(width: 12),
              
              // Key type info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          keyType.displayName,
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isRecommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: context.textTheme.labelSmall?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      keyType.description,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Generation time: ${_formatDuration(estimatedTime)}',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comment (Optional)',
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _commentController,
          decoration: InputDecoration(
            hintText: 'Add a comment to identify this key',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.comment),
          ),
          enabled: !_isGenerating,
        ),
        const SizedBox(height: 4),
        Text(
          'The comment will be appended to your public key',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPassphraseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Security',
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Switch(
              value: _usePassphrase,
              onChanged: _isGenerating ? null : (value) {
                setState(() {
                  _usePassphrase = value;
                  if (!value) {
                    _passphraseController.clear();
                    _confirmPassphraseController.clear();
                  }
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        Row(
          children: [
            Icon(
              _usePassphrase ? Icons.lock : Icons.lock_open,
              size: 20,
              color: _usePassphrase ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _usePassphrase
                    ? 'Passphrase protection enabled (recommended)'
                    : 'No passphrase protection',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: _usePassphrase ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Text(
          _usePassphrase
              ? 'Your private key will be encrypted with a passphrase for additional security'
              : 'Your private key will be stored without encryption (less secure)',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.isDarkMode ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          ),
        ),
        
        if (_usePassphrase) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _passphraseController,
            decoration: InputDecoration(
              labelText: 'Passphrase',
              hintText: 'Enter a strong passphrase',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassphrase ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassphrase = !_obscurePassphrase;
                  });
                },
              ),
            ),
            obscureText: _obscurePassphrase,
            validator: _usePassphrase ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a passphrase';
              }
              if (value.length < 8) {
                return 'Passphrase must be at least 8 characters';
              }
              return null;
            } : null,
            enabled: !_isGenerating,
          ),
          
          const SizedBox(height: 12),
          
          TextFormField(
            controller: _confirmPassphraseController,
            decoration: InputDecoration(
              labelText: 'Confirm Passphrase',
              hintText: 'Confirm your passphrase',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassphrase ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassphrase = !_obscureConfirmPassphrase;
                  });
                },
              ),
            ),
            obscureText: _obscureConfirmPassphrase,
            validator: _usePassphrase ? (value) {
              if (value != _passphraseController.text) {
                return 'Passphrases do not match';
              }
              return null;
            } : null,
            enabled: !_isGenerating,
          ),
        ],
      ],
    );
  }

  Widget _buildGenerationInfo() {
    final estimatedTime = ref.watch(keyGenerationTimeProvider(_selectedKeyType));
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Generation Details',
                style: context.textTheme.titleSmall?.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildInfoRow('Key Type:', _selectedKeyType.displayName),
          _buildInfoRow('Algorithm:', _selectedKeyType.algorithm.toUpperCase()),
          _buildInfoRow('Key Size:', '${_selectedKeyType.keySize} bits'),
          _buildInfoRow('Estimated Time:', _formatDuration(estimatedTime)),
          _buildInfoRow('Security:', _usePassphrase ? 'Passphrase Protected' : 'No Passphrase'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: context.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          top: BorderSide(
            color: context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isGenerating ? null : () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateKey,
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Generating...'),
                        ],
                      )
                    : const Text('Generate Key'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 1) {
      return '${duration.inMilliseconds}ms';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  void _generateKey() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final actions = ref.read(sshKeyActionsProvider);
      
      final keyRecord = await actions.generateKey(
        name: _nameController.text.trim(),
        keyType: _selectedKeyType,
        passphrase: _usePassphrase ? _passphraseController.text : null,
        comment: _commentController.text.trim().isNotEmpty 
            ? _commentController.text.trim()
            : null,
        metadata: {
          'created_from': 'mobile_app',
          'device_info': 'DevPocket Flutter',
        },
      );

      if (keyRecord != null && mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SSH key "${keyRecord.name}" created successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Navigate to key detail screen
              },
            ),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate SSH key: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }
}