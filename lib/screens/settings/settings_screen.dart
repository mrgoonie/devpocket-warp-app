import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/api_providers.dart';
import 'components/settings_profile_section.dart';
import 'components/settings_ai_section.dart';
import 'components/settings_app_section.dart';
import 'components/settings_security_section.dart';
import 'components/settings_support_section.dart';
import 'components/settings_about_section.dart';
import 'utils/settings_utils.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeProvider);
    final fontFamily = ref.watch(fontFamilyProvider);
    final fontSize = ref.watch(fontSizeProvider);
    final hasValidKey = ref.watch(hasAiApiKeyProvider).maybeWhen(
      data: (hasKey) => hasKey,
      orElse: () => false,
    );
    final canUseAI = ref.watch(canUseAiProvider).maybeWhen(
      data: (canUse) => canUse,
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          SettingsProfileSection(
            user: user,
            onEditProfile: () => SettingsUtils.showEditProfileDialog(context),
          ),
          
          const SizedBox(height: 24),

          // AI Configuration Section
          SettingsAISection(
            hasValidKey: hasValidKey,
            canUseAI: canUseAI,
          ),
          
          const SizedBox(height: 24),
          
          // App Settings
          SettingsAppSection(
            themeMode: themeMode,
            fontFamily: fontFamily,
            fontSize: fontSize,
          ),
          
          const SizedBox(height: 24),
          
          // Security
          const SettingsSecuritySection(),
          
          const SizedBox(height: 24),
          
          // Support
          const SettingsSupportSection(),
          
          const SizedBox(height: 24),
          
          // About
          const SettingsAboutSection(),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}