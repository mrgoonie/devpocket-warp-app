import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/ai_models.dart';
import '../../../providers/ai_provider.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';

/// Model selection section component for choosing AI models
class ModelSelectionSection extends ConsumerWidget {
  final AsyncValue<List<AIModel>> availableModels;
  final String selectedModel;

  const ModelSelectionSection({
    super.key,
    required this.availableModels,
    required this.selectedModel,
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
            const Row(
              children: [
                Icon(
                  Icons.model_training,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'AI Model Selection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            availableModels.when(
              data: (models) => Column(
                children: models.map((model) => _ModelTile(
                  model: model,
                  selectedModel: selectedModel,
                  onSelectModel: (modelId) {
                    ref.read(selectedModelProvider.notifier).setModel(modelId);
                  },
                )).toList(),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Failed to load models'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual model tile component
class _ModelTile extends StatelessWidget {
  final AIModel model;
  final String selectedModel;
  final ValueChanged<String> onSelectModel;

  const _ModelTile({
    required this.model,
    required this.selectedModel,
    required this.onSelectModel,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = model.id == selectedModel;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onSelectModel(model.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppTheme.primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? AppTheme.primaryColor
                  : (context.isDarkMode ? AppTheme.darkBorderColor : AppTheme.lightBorderColor),
            ),
          ),
          child: Row(
            children: [
              Radio<String>(
                value: model.id,
                groupValue: selectedModel,
                onChanged: (value) {
                  if (value != null) {
                    onSelectModel(value);
                  }
                },
                activeColor: AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      model.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ModelBadge(text: 'Context: ${(model.contextLength / 1000).toStringAsFixed(0)}K'),
                        const SizedBox(width: 8),
                        _ModelBadge(text: '\$${model.pricing.toStringAsFixed(4)}/1K tokens'),
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
}

/// Model information badge component
class _ModelBadge extends StatelessWidget {
  final String text;

  const _ModelBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.isDarkMode 
            ? AppTheme.darkSurface
            : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: context.isDarkMode 
              ? AppTheme.darkBorderColor 
              : AppTheme.lightBorderColor,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: context.isDarkMode ? Colors.white70 : Colors.black54,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}