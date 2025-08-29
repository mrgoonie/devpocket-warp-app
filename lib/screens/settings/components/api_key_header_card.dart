import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';

/// Header card component for the API key screen showing AI-powered features information
class ApiKeyHeaderCard extends StatelessWidget {
  const ApiKeyHeaderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.psychology,
                color: AppTheme.primaryColor,
                size: 32,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI-Powered Features',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Bring Your Own Key (BYOK) Model',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.darkTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'DevPocket uses your own OpenRouter API key to provide AI features like natural language command generation and error explanations. Your key stays secure and you maintain full control over your usage and costs.',
            style: TextStyle(
              fontSize: 14,
              color: context.isDarkMode ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}