import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/ai_provider.dart';
import 'components/api_key_header_card.dart';
import 'components/api_key_section.dart';
import 'components/model_selection_section.dart';
import 'components/usage_stats_section.dart';
import 'components/features_section.dart';
import 'components/help_section.dart';
import 'utils/api_key_utils.dart';

class ApiKeyScreen extends ConsumerStatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  ConsumerState<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends ConsumerState<ApiKeyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  bool _isObscured = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apiKeyState = ref.watch(apiKeyProvider);
    final aiUsage = ref.watch(aiUsageProvider);
    final availableModels = ref.watch(availableModelsProvider);
    final selectedModel = ref.watch(selectedModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Configuration'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              const ApiKeyHeaderCard(),
              
              const SizedBox(height: 24),
              
              // API Key Configuration
              ApiKeySection(
                apiKeyController: _apiKeyController,
                isObscured: _isObscured,
                isSaving: _isSaving,
                onToggleObscured: () => setState(() => _isObscured = !_isObscured),
                onPasteFromClipboard: () => ApiKeyUtils.pasteFromClipboard(_apiKeyController),
                onSave: _saveApiKey,
                onRemove: ref.read(apiKeyProvider.notifier).hasValidKey ? _removeApiKey : null,
                onGetApiKey: () => ApiKeyUtils.launchUrl('https://openrouter.ai/keys', context),
                apiKeyState: apiKeyState,
              ),
              
              const SizedBox(height: 24),
              
              // Model Selection (only show if API key is valid)
              if (ref.read(apiKeyProvider.notifier).hasValidKey) ...[
                ModelSelectionSection(
                  availableModels: availableModels,
                  selectedModel: selectedModel,
                ),
                const SizedBox(height: 24),
              ],
              
              // Usage Statistics (only show if API key is valid)
              if (ref.read(apiKeyProvider.notifier).hasValidKey) ...[
                UsageStatsSection(usage: aiUsage),
                const SizedBox(height: 24),
              ],
              
              // AI Features Settings
              const FeaturesSection(),
              
              const SizedBox(height: 24),
              
              // Help Section
              HelpSection(
                onOpenRouterDocs: () => ApiKeyUtils.launchUrl('https://openrouter.ai/docs', context),
                onSupportedModels: () => ApiKeyUtils.launchUrl('https://openrouter.ai/models', context),
                onPrivacyDialog: () => ApiKeyUtils.showPrivacyDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveApiKey() {
    ApiKeyUtils.saveApiKey(
      context: context,
      ref: ref,
      formKey: _formKey,
      controller: _apiKeyController,
      setLoading: () => setState(() => _isSaving = true),
      clearLoading: () => setState(() => _isSaving = false),
    );
  }

  void _removeApiKey() {
    ApiKeyUtils.removeApiKey(
      context: context,
      ref: ref,
    );
  }
}