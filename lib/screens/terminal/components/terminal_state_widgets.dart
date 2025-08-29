import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';
import '../../vaults/host_edit_screen.dart';

/// Empty state component when no connection is selected
class TerminalEmptyState extends StatelessWidget {
  final VoidCallback onSelectHost;

  const TerminalEmptyState({
    super.key,
    required this.onSelectHost,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.darkBorderColor, width: 2),
              ),
              child: const Icon(
                Icons.terminal,
                size: 40,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Connection Selected',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select an SSH host to start a terminal session',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onSelectHost,
              icon: const Icon(Icons.computer),
              label: const Text('Select Host'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// No hosts state component when no SSH hosts are available
class TerminalNoHostsState extends StatelessWidget {
  const TerminalNoHostsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.darkBorderColor, width: 2),
              ),
              child: const Icon(
                Icons.computer_outlined,
                size: 40,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No SSH Hosts',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add SSH hosts in the Vaults section to connect',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HostEditScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Host'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state component for displaying connection errors
class TerminalErrorState extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const TerminalErrorState({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.terminalRed, width: 2),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 40,
                color: AppTheme.terminalRed,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connection Error',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }
}