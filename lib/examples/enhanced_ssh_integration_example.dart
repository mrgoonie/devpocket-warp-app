// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ssh_connection_error.dart';
import '../providers/enhanced_ssh_connection_providers.dart';
import '../widgets/ssh_connection_widgets.dart';

/// Example of how to integrate the enhanced SSH connection system
/// This shows how to use the new providers and widgets in the terminal screen
class EnhancedSshIntegrationExample extends ConsumerWidget {
  const EnhancedSshIntegrationExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(enhancedSshConnectionProvider);
    final networkState = ref.watch(currentNetworkStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enhanced SSH Terminal'),
        actions: [
          // Network status indicator
          const NetworkStatusIndicator(),
          const SizedBox(width: 8),
          
          // Connection status
          if (connectionState.isConnected)
            IconButton(
              onPressed: () => _disconnect(ref),
              icon: const Icon(Icons.close, color: Colors.red),
              tooltip: 'Disconnect SSH',
            )
          else
            IconButton(
              onPressed: () => _showConnectionDialog(context, ref),
              icon: const Icon(Icons.link),
              tooltip: 'Connect SSH',
            ),
        ],
      ),
      body: Column(
        children: [
          // Network status banner
          if (!networkState.isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.orange.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    networkState.statusDescription,
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),

          // Connection status widget
          if (connectionState.isConnecting || connectionState.hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildConnectionStatus(context, ref, connectionState),
            ),

          // Terminal content area
          Expanded(
            child: Container(
              color: Colors.black,
              child: _buildTerminalContent(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(BuildContext context, WidgetRef ref, EnhancedSshConnectionState state) {
    if (state.isConnecting) {
      return SshConnectionProgressIndicator(
        currentStep: state.currentStep ?? SshConnectionStep.initializing,
        progress: state.connectionProgress,
        showCancel: true,
        onCancel: () => _disconnect(ref),
      );
    }

    if (state.hasError && state.connectionError != null) {
      return Column(
        children: [
          // Error dialog content in a card
          Card(
            color: Colors.red.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.error, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Connection Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(state.connectionError!.userFriendlyMessage),
                  const SizedBox(height: 12),
                  
                  // Action buttons
                  Row(
                    children: [
                      if (state.canRetry)
                        ElevatedButton.icon(
                          onPressed: () => _retry(ref),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _clearError(ref),
                        child: const Text('Dismiss'),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showErrorDetails(context, state.connectionError!),
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('Details'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Retry countdown if auto-retrying
          if (state.isAutoRetrying && state.nextRetryAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _buildRetryCountdown(state.nextRetryAt!),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildRetryCountdown(DateTime nextRetryAt) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) {
        final remaining = nextRetryAt.difference(DateTime.now()).inSeconds;
        return remaining > 0 ? remaining : 0;
      }),
      builder: (context, snapshot) {
        final remaining = snapshot.data ?? 0;
        if (remaining <= 0) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text('Retrying in ${remaining}s...'),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  // Cancel retry functionality - would need proper context
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTerminalContent(BuildContext context, WidgetRef ref) {
    final connectionState = ref.watch(enhancedSshConnectionProvider);
    
    if (connectionState.isConnected) {
      // Show full SSH connection status widget
      return Column(
        children: [
          SshConnectionStatusWidget(
            sessionId: connectionState.sessionId,
            healthMetrics: connectionState.healthMetrics,
            showDetails: true,
            onDisconnect: () => _disconnect(ref),
            onReconnect: () => _reconnect(ref),
          ),
          const SizedBox(height: 16),
          const Expanded(
            child: Center(
              child: Text(
                'Terminal content would go here...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      );
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.terminal,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Connect to an SSH host to start',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // Action methods
  void _disconnect(WidgetRef ref) {
    ref.read(enhancedSshConnectionProvider.notifier).disconnect();
  }

  void _retry(WidgetRef ref) {
    ref.read(enhancedSshConnectionProvider.notifier).retry();
  }

  void _reconnect(WidgetRef ref) {
    ref.read(enhancedSshConnectionProvider.notifier).reconnect();
  }

  void _clearError(WidgetRef ref) {
    ref.read(enhancedSshConnectionProvider.notifier).clearError();
  }

  void _cancelRetry(WidgetRef ref) {
    ref.read(enhancedSshConnectionProvider.notifier).cancelRetry();
  }

  void _showConnectionDialog(BuildContext context, WidgetRef ref) {
    // This would show a dialog to select SSH profiles
    // For now, just show a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SSH profile selection dialog would appear here'),
      ),
    );
  }

  void _showErrorDetails(BuildContext context, SshConnectionError error) {
    showDialog<void>(
      context: context,
      builder: (context) => SshConnectionErrorDialog(
        error: error,
        onRetry: () {
          Navigator.of(context).pop();
          _retry;
        },
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }
}

/// Example of using the enhanced providers in a simple way
class SimpleEnhancedSshExample extends ConsumerWidget {
  const SimpleEnhancedSshExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the connection state
    final isConnected = ref.watch(isConnectedToSshEnhancedProvider);
    final hasError = ref.watch(sshConnectionErrorEnhancedProvider) != null;
    final canRetry = ref.watch(canRetrySshProvider);
    final healthMetrics = ref.watch(sshHealthMetricsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple SSH Example'),
        backgroundColor: isConnected ? Colors.green : Colors.grey,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Connection status
            Icon(
              isConnected ? Icons.check_circle : Icons.error,
              size: 64,
              color: isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              isConnected ? 'Connected to SSH' : 'Not connected',
              style: const TextStyle(fontSize: 18),
            ),
            
            // Health metrics
            if (isConnected && healthMetrics != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('Connection Health'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(healthMetrics.quality.emoji),
                              Text(healthMetrics.quality.displayName),
                            ],
                          ),
                          Column(
                            children: [
                              Text('${healthMetrics.latencyMs.round()}ms'),
                              const Text('Latency'),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            
            // Error state
            if (hasError) ...[
              const SizedBox(height: 16),
              const Text(
                'Connection error occurred',
                style: TextStyle(color: Colors.red),
              ),
              if (canRetry) ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => ref.read(enhancedSshConnectionProvider.notifier).retry(),
                  child: const Text('Retry Connection'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Example of listening to connection events
class SshConnectionListenerExample extends ConsumerStatefulWidget {
  const SshConnectionListenerExample({super.key});

  @override
  ConsumerState<SshConnectionListenerExample> createState() => _SshConnectionListenerExampleState();
}

class _SshConnectionListenerExampleState extends ConsumerState<SshConnectionListenerExample> {
  final List<String> _connectionEvents = [];

  @override
  Widget build(BuildContext context) {
    // Listen to connection state changes
    ref.listen<EnhancedSshConnectionState>(enhancedSshConnectionProvider, (previous, next) {
      if (previous?.status != next.status) {
        _addEvent('Status changed: ${previous?.status} → ${next.status}');
      }
      
      if (previous?.connectionError != next.connectionError && next.connectionError != null) {
        _addEvent('Error: ${next.connectionError!.type}');
      }
      
      if (previous?.healthMetrics?.quality != next.healthMetrics?.quality && next.healthMetrics != null) {
        _addEvent('Health: ${next.healthMetrics!.quality.displayName}');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Connection Events')),
      body: ListView.builder(
        itemCount: _connectionEvents.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.event),
            title: Text(_connectionEvents[index]),
            subtitle: Text(DateTime.now().toString()),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _connectionEvents.clear();
          });
        },
        child: const Icon(Icons.clear),
      ),
    );
  }

  void _addEvent(String event) {
    setState(() {
      _connectionEvents.insert(0, event);
      if (_connectionEvents.length > 50) {
        _connectionEvents.removeLast();
      }
    });
  }
}