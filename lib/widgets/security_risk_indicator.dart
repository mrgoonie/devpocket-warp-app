import 'package:flutter/material.dart';
import '../models/enhanced_ssh_models.dart';

/// Visual indicator for security risk levels
class SecurityRiskIndicator extends StatelessWidget {
  final SecurityRisk risk;
  final double size;
  final bool showLabel;

  const SecurityRiskIndicator({
    super.key,
    required this.risk,
    this.size = 24,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.1),
      decoration: BoxDecoration(
        color: _getRiskColor(risk).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getRiskIcon(risk),
            color: _getRiskColor(risk),
            size: size,
          ),
          if (showLabel) ...[
            SizedBox(width: size * 0.2),
            Text(
              _getRiskLabel(risk),
              style: TextStyle(
                color: _getRiskColor(risk),
                fontSize: size * 0.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRiskColor(SecurityRisk risk) {
    switch (risk) {
      case SecurityRisk.low:
        return Colors.green;
      case SecurityRisk.medium:
        return Colors.orange;
      case SecurityRisk.high:
        return Colors.red;
    }
  }

  IconData _getRiskIcon(SecurityRisk risk) {
    switch (risk) {
      case SecurityRisk.low:
        return Icons.check_circle;
      case SecurityRisk.medium:
        return Icons.warning;
      case SecurityRisk.high:
        return Icons.error;
    }
  }

  String _getRiskLabel(SecurityRisk risk) {
    switch (risk) {
      case SecurityRisk.low:
        return 'Low Risk';
      case SecurityRisk.medium:
        return 'Medium Risk';
      case SecurityRisk.high:
        return 'High Risk';
    }
  }
}