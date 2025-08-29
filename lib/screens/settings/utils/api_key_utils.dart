import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import '../../../providers/ai_provider.dart';

/// Utility class for API key screen operations
class ApiKeyUtils {
  /// Paste text from clipboard into a text controller
  static Future<void> pasteFromClipboard(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      controller.text = data!.text!;
    }
  }

  /// Save API key with validation and user feedback
  static Future<void> saveApiKey({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
    required TextEditingController controller,
    required VoidCallback setLoading,
    required VoidCallback clearLoading,
  }) async {
    if (!formKey.currentState!.validate()) return;

    setLoading();

    try {
      final success = await ref.read(apiKeyProvider.notifier).setApiKey(controller.text.trim());
      
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        controller.clear();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save API key: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        clearLoading();
      }
    }
  }

  /// Remove API key with confirmation dialog
  static Future<void> removeApiKey({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove API Key'),
        content: const Text('Are you sure you want to remove your API key? AI features will be disabled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(apiKeyProvider.notifier).removeApiKey();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key removed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  /// Launch URL with error handling
  static Future<void> launchUrl(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (!await launcher.launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    }
  }

  /// Show privacy information dialog
  static void showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy & Security'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your API key security:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Stored locally using secure storage'),
            Text('• Never transmitted to DevPocket servers'),
            Text('• Only sent directly to OpenRouter API'),
            Text('• Encrypted at rest on your device'),
            SizedBox(height: 16),
            Text('Data handling:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• AI requests are made directly to OpenRouter'),
            Text('• No conversation data is stored on our servers'),
            Text('• Usage statistics are calculated locally'),
            Text('• You control when to reset usage data'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}