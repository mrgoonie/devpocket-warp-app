import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/theme_provider.dart';
import '../../../themes/app_theme.dart';
import '../../../main.dart';
import 'settings_common_widgets.dart';

/// App settings section with theme, font, and terminal theme options
class SettingsAppSection extends ConsumerWidget {
  final ThemeMode themeMode;
  final String fontFamily;
  final double fontSize;

  const SettingsAppSection({
    super.key,
    required this.themeMode,
    required this.fontFamily,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SettingsSectionHeader(title: 'App Settings'),
        const SizedBox(height: 12),
        
        SettingsCard(
          icon: Icons.color_lens,
          title: 'Theme',
          subtitle: _getThemeDescription(themeMode),
          onTap: () => _showThemeDialog(context, ref),
        ),
        
        SettingsCard(
          icon: Icons.text_fields,
          title: 'Terminal Font',
          subtitle: '${TerminalFont.getByFontFamily(fontFamily).displayName} - ${fontSize.toInt()}pt',
          onTap: () => _showFontDialog(context, ref),
        ),
        
        SettingsCard(
          icon: Icons.palette,
          title: 'Terminal Theme',
          subtitle: 'GitHub Dark',
          onTap: () => _showTerminalThemeDialog(context),
        ),
      ],
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
    final currentFontFamily = ref.read(fontFamilyProvider);
    final currentFontSize = ref.read(fontSizeProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Terminal Font Settings'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Font family selection
              const Text(
                'Font Family',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: TerminalFont.availableFonts.length,
                  itemBuilder: (context, index) {
                    final font = TerminalFont.availableFonts[index];
                    final isSelected = font.fontFamily == currentFontFamily;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: AppTheme.primaryColor, width: 1)
                            : null,
                      ),
                      child: ListTile(
                        title: Text(
                          font.displayName,
                          style: TextStyle(
                            fontFamily: font.fontFamily,
                            color: isSelected 
                                ? AppTheme.primaryColor
                                : AppTheme.darkTextPrimary,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          'The quick brown fox jumps over the lazy dog',
                          style: TextStyle(
                            fontFamily: font.fontFamily,
                            fontSize: 12,
                            color: AppTheme.darkTextSecondary,
                          ),
                        ),
                        onTap: () {
                          ref.read(fontPreferencesProvider.notifier).setFontFamily(font.fontFamily);
                          Navigator.pop(context);
                        },
                        trailing: isSelected
                            ? const Icon(Icons.check, color: AppTheme.primaryColor)
                            : null,
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Font size selection
              const Text(
                'Font Size',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('${currentFontSize.toInt()}pt'),
                  Expanded(
                    child: Slider(
                      value: currentFontSize,
                      min: 10,
                      max: 24,
                      divisions: 14,
                      label: '${currentFontSize.toInt()}pt',
                      onChanged: (value) {
                        ref.read(fontPreferencesProvider.notifier).setFontSize(value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTerminalThemeDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terminal theme settings coming soon!')),
    );
  }
}