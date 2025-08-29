import 'package:flutter/material.dart';
import '../../../themes/app_theme.dart';

/// Empty state widget when no SSH hosts exist
class HostEmptyState extends StatelessWidget {
  final VoidCallback onAddHost;

  const HostEmptyState({
    super.key,
    required this.onAddHost,
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
              'Add your first SSH host to get started with secure connections',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onAddHost,
              icon: const Icon(Icons.add),
              label: const Text('Add SSH Host'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// No search results state widget
class HostNoSearchResults extends StatelessWidget {
  const HostNoSearchResults({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppTheme.darkTextSecondary,
            ),
            SizedBox(height: 16),
            Text(
              'No matching hosts found',
              style: TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your search terms',
              style: TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state widget for host loading failures
class HostErrorState extends StatelessWidget {
  final String title;
  final String error;
  final VoidCallback onRetry;

  const HostErrorState({
    super.key,
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.terminalRed,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.darkTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                color: AppTheme.darkTextSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
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