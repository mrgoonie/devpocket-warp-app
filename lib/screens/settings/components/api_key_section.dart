import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';

/// API key configuration section component
class ApiKeySection extends ConsumerWidget {
  final TextEditingController apiKeyController;
  final bool isObscured;
  final bool isSaving;
  final VoidCallback onToggleObscured;
  final VoidCallback onPasteFromClipboard;
  final VoidCallback onSave;
  final VoidCallback? onRemove;
  final VoidCallback onGetApiKey;
  final AsyncValue<String?> apiKeyState;

  const ApiKeySection({
    super.key,
    required this.apiKeyController,
    required this.isObscured,
    required this.isSaving,
    required this.onToggleObscured,
    required this.onPasteFromClipboard,
    required this.onSave,
    this.onRemove,
    required this.onGetApiKey,
    required this.apiKeyState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context.isDarkMode 
              ? AppTheme.darkBorderColor 
              : AppTheme.lightBorderColor,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.vpn_key,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'OpenRouter API Key',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _buildApiKeyStatus(),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // API Key Input
            TextFormField(
              controller: apiKeyController,
              obscureText: isObscured,
              decoration: InputDecoration(
                hintText: 'sk-or-v1-xxxxxxxxxxxxxxxxxxxxxxxx',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: onToggleObscured,
                      icon: Icon(isObscured ? Icons.visibility : Icons.visibility_off),
                    ),
                    IconButton(
                      onPressed: onPasteFromClipboard,
                      icon: const Icon(Icons.paste),
                    ),
                  ],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your OpenRouter API key';
                }
                if (!value.startsWith('sk-or-v1-')) {
                  return 'API key should start with sk-or-v1-';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isSaving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Save API Key',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                if (onRemove != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: onRemove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    child: const Text('Remove'),
                  ),
                ],
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Get API Key Link
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDarkMode 
                    ? AppTheme.darkSurface.withValues(alpha: 0.3)
                    : AppTheme.lightSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.isDarkMode 
                      ? AppTheme.darkBorderColor 
                      : AppTheme.lightBorderColor,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Don't have an API key?",
                      style: TextStyle(
                        fontSize: 14,
                        color: context.isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onGetApiKey,
                    child: const Text(
                      'Get one here',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyStatus() {
    return apiKeyState.when(
      data: (apiKey) {
        if (apiKey != null && apiKey.isNotEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 4),
                Text(
                  'Connected',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 16),
                SizedBox(width: 4),
                Text(
                  'Not Set',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error, color: Colors.red, size: 16),
            SizedBox(width: 4),
            Text(
              'Error',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}