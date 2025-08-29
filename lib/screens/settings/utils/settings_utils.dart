import 'package:flutter/material.dart';

/// Utility functions for settings screen operations
class SettingsUtils {
  SettingsUtils._();

  /// Show edit profile dialog (placeholder)
  static void showEditProfileDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit profile feature coming soon!')),
    );
  }

  /// Show change password dialog (placeholder)
  static void showChangePasswordDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Change password feature coming soon!')),
    );
  }

  /// Show terminal theme dialog (placeholder)
  static void showTerminalThemeDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Terminal theme settings coming soon!')),
    );
  }

  /// Open documentation URL (placeholder)
  static void openDocumentation() {
    // TODO: Open documentation URL
  }

  /// Show bug report dialog (placeholder)
  static void reportBug(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bug report feature coming soon!')),
    );
  }

  /// Open app store rating (placeholder)
  static void rateApp() {
    // TODO: Open app store rating
  }
}