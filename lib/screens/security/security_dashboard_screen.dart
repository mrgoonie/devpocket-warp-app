import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/audit_service.dart';
import '../../services/biometric_service.dart';
import '../../services/secure_ssh_service.dart';
import '../../widgets/security_risk_indicator.dart';
import '../../widgets/security_metric_card.dart';

/// Security dashboard providing comprehensive security overview
class SecurityDashboardScreen extends ConsumerStatefulWidget {
  const SecurityDashboardScreen({super.key});

  @override
  ConsumerState<SecurityDashboardScreen> createState() => _SecurityDashboardScreenState();
}

class _SecurityDashboardScreenState extends ConsumerState<SecurityDashboardScreen> {
  AuditStatistics? _auditStats;
  List<SecurityAlert> _securityAlerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSecurityData();
  }

  Future<void> _loadSecurityData() async {
    setState(() => _isLoading = true);
    
    try {
      // Load audit statistics
      final auditService = ref.read(auditServiceProvider);
      final stats = await auditService.getAuditStatistics(
        startDate: DateTime.now().subtract(const Duration(days: 30)),
      );
      
      // Generate security alerts
      final alerts = await _generateSecurityAlerts(stats);
      
      setState(() {
        _auditStats = stats;
        _securityAlerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load security data: $e');
    }
  }

  Future<List<SecurityAlert>> _generateSecurityAlerts(AuditStatistics stats) async {
    final alerts = <SecurityAlert>[];
    
    // Check for high failure rates
    if (stats.successRate < 0.8) {
      alerts.add(SecurityAlert(
        severity: SecuritySeverity.high,
        title: 'High Connection Failure Rate',
        description: 'Connection success rate is ${(stats.successRate * 100).toStringAsFixed(1)}%',
        action: 'Review connection settings and credentials',
        icon: Icons.error_outline,
      ));
    }
    
    // Check for security warnings
    if (stats.securityWarningRate > 0.1) {
      alerts.add(SecurityAlert(
        severity: SecuritySeverity.medium,
        title: 'Security Warnings Detected',
        description: '${(stats.securityWarningRate * 100).toStringAsFixed(1)}% of events triggered security warnings',
        action: 'Review command validation settings',
        icon: Icons.warning_outlined,
      ));
    }
    
    // Check biometric availability
    final biometricService = ref.read(biometricServiceProvider);
    if (!await biometricService.isAvailable()) {
      alerts.add(const SecurityAlert(
        severity: SecuritySeverity.medium,
        title: 'Biometric Authentication Unavailable',
        description: 'Enable biometric authentication for enhanced security',
        action: 'Configure biometric settings',
        icon: Icons.fingerprint_outlined,
      ));
    }
    
    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSecurityData,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Export Audit Log'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.security),
                  title: Text('Security Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading ? _buildLoading() : _buildDashboard(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading security data...'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return RefreshIndicator(
      onRefresh: _loadSecurityData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSecurityScore(),
            const SizedBox(height: 24),
            _buildSecurityAlerts(),
            const SizedBox(height: 24),
            _buildSecurityMetrics(),
            const SizedBox(height: 24),
            _buildActiveConnections(),
            const SizedBox(height: 24),
            _buildRecentActivity(),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityScore() {
    final score = _calculateSecurityScore();
    final scoreColor = _getSecurityScoreColor(score);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  size: 32,
                  color: scoreColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Security Score',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getSecurityScoreDescription(score),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$score/100',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityAlerts() {
    if (_securityAlerts.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 32,
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  'No security alerts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Security Alerts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._securityAlerts.map((alert) => _buildAlertCard(alert)),
      ],
    );
  }

  Widget _buildAlertCard(SecurityAlert alert) {
    return Card(
      child: ListTile(
        leading: Icon(
          alert.icon,
          color: _getSeverityColor(alert.severity),
          size: 28,
        ),
        title: Text(
          alert.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(alert.description),
            const SizedBox(height: 8),
            Text(
              alert.action,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          onPressed: () => _handleAlertAction(alert),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildSecurityMetrics() {
    if (_auditStats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Security Metrics',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            SecurityMetricCard(
              title: 'Connection Success',
              value: '${(_auditStats!.successRate * 100).toStringAsFixed(1)}%',
              icon: Icons.link,
              color: _auditStats!.successRate >= 0.9 ? Colors.green : Colors.orange,
            ),
            SecurityMetricCard(
              title: 'Commands Executed',
              value: '${_auditStats!.commandExecutions}',
              icon: Icons.terminal,
              color: Colors.blue,
            ),
            SecurityMetricCard(
              title: 'File Transfers',
              value: '${_auditStats!.fileTransfers}',
              icon: Icons.file_upload,
              color: Colors.purple,
            ),
            SecurityMetricCard(
              title: 'Security Warnings',
              value: '${_auditStats!.securityWarnings}',
              icon: Icons.warning,
              color: _auditStats!.securityWarnings > 0 ? Colors.red : Colors.green,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveConnections() {
    return Consumer(
      builder: (context, ref, child) {
        final sshService = ref.watch(sshServiceProvider);
        final activeConnections = sshService.getActiveConnections();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Connections',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text('${activeConnections.length}'),
                  backgroundColor: activeConnections.isNotEmpty 
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activeConnections.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('No active connections'),
                  ),
                ),
              )
            else
              ...activeConnections.map((connection) => _buildConnectionCard(connection)),
          ],
        );
      },
    );
  }

  Widget _buildConnectionCard(SecureSSHConnection connection) {
    final duration = DateTime.now().difference(connection.connectedAt);
    
    return Card(
      child: ListTile(
        leading: SecurityRiskIndicator(risk: connection.host.securityRisk),
        title: Text(
          connection.host.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${connection.host.username}@${connection.host.hostname}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(duration),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(Icons.terminal, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${connection.commandCount} commands',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close, color: Colors.red),
          onPressed: () => _disconnectHost(connection),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(
              onPressed: () => _navigateToAuditLog(),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.login, color: Colors.green),
                title: const Text('SSH Connection'),
                subtitle: const Text('production-server-01'),
                trailing: Text(
                  '2 min ago',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.terminal, color: Colors.blue),
                title: const Text('Command Executed'),
                subtitle: const Text('docker ps -a'),
                trailing: Text(
                  '5 min ago',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.key, color: Colors.purple),
                title: const Text('SSH Key Generated'),
                subtitle: const Text('production-access-key'),
                trailing: Text(
                  '1 hour ago',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _calculateSecurityScore() {
    int score = 100;
    
    if (_auditStats != null) {
      // Deduct points for low success rate
      if (_auditStats!.successRate < 0.5) {
        score -= 30;
      } else if (_auditStats!.successRate < 0.8) {
        score -= 15;
      }
      
      // Deduct points for security warnings
      if (_auditStats!.securityWarningRate > 0.2) {
        score -= 25;
      } else if (_auditStats!.securityWarningRate > 0.1) {
        score -= 10;
      }
    }
    
    // Deduct points for security alerts
    for (final alert in _securityAlerts) {
      switch (alert.severity) {
        case SecuritySeverity.high:
          score -= 20;
          break;
        case SecuritySeverity.medium:
          score -= 10;
          break;
        case SecuritySeverity.low:
          score -= 5;
          break;
      }
    }
    
    return score.clamp(0, 100);
  }

  Color _getSecurityScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getSecurityScoreDescription(int score) {
    if (score >= 90) return 'Excellent security posture';
    if (score >= 80) return 'Good security practices';
    if (score >= 60) return 'Security needs attention';
    return 'Critical security issues detected';
  }

  Color _getSeverityColor(SecuritySeverity severity) {
    switch (severity) {
      case SecuritySeverity.high:
        return Colors.red;
      case SecuritySeverity.medium:
        return Colors.orange;
      case SecuritySeverity.low:
        return Colors.yellow[700]!;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'export':
        _exportAuditLog();
        break;
      case 'settings':
        _navigateToSecuritySettings();
        break;
    }
  }

  void _handleAlertAction(SecurityAlert alert) {
    // Navigate to appropriate settings or take action based on alert type
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Action: ${alert.action}'),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _disconnectHost(SecureSSHConnection connection) async {
    try {
      final sshService = ref.read(sshServiceProvider);
      await sshService.disconnect(connection.id);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disconnected from ${connection.host.displayName}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to disconnect: $e');
    }
  }

  void _exportAuditLog() {
    // Implementation for exporting audit log
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audit log export started...'),
      ),
    );
  }

  void _navigateToSecuritySettings() {
    Navigator.pushNamed(context, '/security/settings');
  }

  void _navigateToAuditLog() {
    Navigator.pushNamed(context, '/security/audit');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

/// Security alert model
class SecurityAlert {
  final SecuritySeverity severity;
  final String title;
  final String description;
  final String action;
  final IconData icon;

  const SecurityAlert({
    required this.severity,
    required this.title,
    required this.description,
    required this.action,
    required this.icon,
  });
}

/// Security alert severity levels
enum SecuritySeverity {
  high,
  medium,
  low,
}

// Placeholder providers - these would be implemented with Riverpod
final auditServiceProvider = Provider<AuditService>((ref) {
  throw UnimplementedError('AuditService provider not implemented');
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  throw UnimplementedError('BiometricService provider not implemented');
});

final sshServiceProvider = Provider<SecureSSHService>((ref) {
  throw UnimplementedError('SecureSSHService provider not implemented');
});