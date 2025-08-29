import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';

/// Search field component for filtering SSH hosts
class HostSearchField extends StatelessWidget {
  final TextEditingController controller;

  const HostSearchField({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      style: const TextStyle(color: AppTheme.darkTextPrimary),
      decoration: const InputDecoration(
        hintText: 'Search hosts...',
        hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
        border: InputBorder.none,
      ),
    );
  }
}