import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
        ],
      ),
      body: _buildHistoryContent(context),
    );
  }

  Widget _buildHistoryContent(BuildContext context) {
    // Mock history data
    final historyItems = [
      _HistoryItem(
        type: _HistoryType.connection,
        title: 'ubuntu@prod.example.com',
        subtitle: 'Connected for 45 minutes • 12 commands',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        success: true,
      ),
      _HistoryItem(
        type: _HistoryType.command,
        title: 'docker ps -a',
        subtitle: 'Executed via AI Agent • prod.example.com',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        success: true,
      ),
      _HistoryItem(
        type: _HistoryType.connection,
        title: 'developer@dev.example.com',
        subtitle: 'Connection failed • Timeout',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        success: false,
      ),
    ];

    if (historyItems.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historyItems.length,
      itemBuilder: (context, index) {
        final item = historyItems[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildHistoryCard(context, item),
        );
      },
    );
  }

  Widget _buildEmptyState() {
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
                Icons.history_outlined,
                size: 40,
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No History Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your command and connection history will appear here',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.darkTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, _HistoryItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showItemDetails(context, item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getItemColor(item).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getItemIcon(item),
                  color: _getItemColor(item),
                  size: 20,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontFamily: item.type == _HistoryType.command 
                            ? AppTheme.terminalFont 
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 8),
              
              // Timestamp and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatTimestamp(item.timestamp),
                    style: context.textTheme.bodySmall?.copyWith(
                      color: AppTheme.darkTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.success 
                          ? AppTheme.terminalGreen.withValues(alpha: 0.1)
                          : AppTheme.terminalRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.success ? 'Success' : 'Failed',
                      style: TextStyle(
                        fontSize: 10,
                        color: item.success 
                            ? AppTheme.terminalGreen
                            : AppTheme.terminalRed,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getItemIcon(_HistoryItem item) {
    switch (item.type) {
      case _HistoryType.connection:
        return Icons.computer;
      case _HistoryType.command:
        return Icons.terminal;
    }
  }

  Color _getItemColor(_HistoryItem item) {
    if (!item.success) return AppTheme.terminalRed;
    
    switch (item.type) {
      case _HistoryType.connection:
        return AppTheme.terminalBlue;
      case _HistoryType.command:
        return AppTheme.terminalGreen;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
    }
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Search History'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Search commands, connections...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text('Filter History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CheckboxListTile(
              title: const Text('Connections'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Commands'),
              value: true,
              onChanged: (value) {},
            ),
            CheckboxListTile(
              title: const Text('Failed only'),
              value: false,
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showItemDetails(BuildContext context, _HistoryItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: context.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.title,
              style: context.textTheme.titleLarge?.copyWith(
                fontFamily: item.type == _HistoryType.command 
                    ? AppTheme.terminalFont 
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.subtitle,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Timestamp: ${item.timestamp}',
              style: context.textTheme.bodySmall?.copyWith(
                color: AppTheme.darkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HistoryType {
  connection,
  command,
}

class _HistoryItem {
  final _HistoryType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final bool success;

  _HistoryItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.success,
  });
}