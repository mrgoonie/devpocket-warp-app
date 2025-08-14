import 'package:flutter/material.dart';

// This file serves as a placeholder for terminal block widgets
// The actual implementation is inline in the terminal_screen.dart for now
// In a more complex app, you could extract reusable terminal block components here

class TerminalBlockWidget extends StatelessWidget {
  final String input;
  final String? output;
  final String? error;
  final bool isExecuting;
  final bool isAgentCommand;

  const TerminalBlockWidget({
    super.key,
    required this.input,
    this.output,
    this.error,
    this.isExecuting = false,
    this.isAgentCommand = false,
  });

  @override
  Widget build(BuildContext context) {
    // Implementation would go here if extracted from main terminal screen
    return const SizedBox.shrink();
  }
}