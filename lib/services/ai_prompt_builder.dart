import '../models/ai_models.dart';

/// Builds prompts for different AI operations
class AIPromptBuilder {
  
  /// Build prompt for command generation
  static String buildCommandGenerationPrompt(CommandContext? context) {
    final buffer = StringBuffer();
    
    buffer.writeln('You are a helpful terminal assistant. Generate a shell command based on the user\'s natural language request.');
    buffer.writeln();
    buffer.writeln('Please respond in the following structured format:');
    buffer.writeln('Command: [the actual shell command]');
    buffer.writeln('Explanation: [brief explanation of what the command does]');
    buffer.writeln('Confidence: [0.0 to 1.0 indicating how confident you are]');
    buffer.writeln('Tags: [comma-separated list of relevant tags]');
    buffer.writeln();
    
    if (context != null) {
      buffer.writeln('Context information:');
      
      if (context.currentDirectory != null) {
        buffer.writeln('- Current directory: ${context.currentDirectory}');
      }
      
      if (context.operatingSystem != null) {
        buffer.writeln('- Operating system: ${context.operatingSystem}');
      }
      
      if (context.recentCommands != null && context.recentCommands!.isNotEmpty) {
        buffer.writeln('- Recent commands: ${context.recentCommands!.take(5).join(', ')}');
      }
      
      if (context.availableTools != null && context.availableTools!.isNotEmpty) {
        buffer.writeln('- Available tools: ${context.availableTools!.join(', ')}');
      }
      
      buffer.writeln();
    }
    
    buffer.writeln('Important notes:');
    buffer.writeln('- Provide safe, commonly used commands');
    buffer.writeln('- Avoid potentially destructive operations unless explicitly requested');
    buffer.writeln('- Consider the user\'s operating system when suggesting commands');
    buffer.writeln('- If the request is ambiguous, provide the most likely interpretation');
    buffer.writeln();
    
    return buffer.toString();
  }

  /// Build prompt for error explanation
  static String buildErrorExplanationPrompt(CommandContext? context) {
    final buffer = StringBuffer();
    
    buffer.writeln('You are a helpful terminal assistant. Analyze the command error and provide a clear explanation.');
    buffer.writeln();
    buffer.writeln('Please respond in the following structured format:');
    buffer.writeln('Explanation: [clear explanation of what went wrong]');
    buffer.writeln('Causes: [list of possible causes, each on a new line starting with "- "]');
    buffer.writeln('Suggestions: [list of suggestions to fix the issue, each on a new line starting with "- "]');
    buffer.writeln('Severity: [0.0 to 1.0 indicating how serious this error is]');
    buffer.writeln();
    
    if (context != null) {
      buffer.writeln('Context information:');
      
      if (context.currentDirectory != null) {
        buffer.writeln('- Current directory: ${context.currentDirectory}');
      }
      
      if (context.operatingSystem != null) {
        buffer.writeln('- Operating system: ${context.operatingSystem}');
      }
      
      if (context.recentCommands != null && context.recentCommands!.isNotEmpty) {
        buffer.writeln('- Recent commands: ${context.recentCommands!.take(3).join(', ')}');
      }
      
      buffer.writeln();
    }
    
    buffer.writeln('Guidelines:');
    buffer.writeln('- Focus on actionable solutions');
    buffer.writeln('- Consider common beginner mistakes');
    buffer.writeln('- Provide specific command examples when helpful');
    buffer.writeln('- Explain technical terms if necessary');
    buffer.writeln();
    
    return buffer.toString();
  }

  /// Build prompt for smart suggestions
  static String buildSuggestionsPrompt(CommandContext? context) {
    final buffer = StringBuffer();
    
    buffer.writeln('You are a helpful terminal assistant. Suggest useful commands based on the current context.');
    buffer.writeln();
    buffer.writeln('Please provide 3-5 practical command suggestions in the following format:');
    buffer.writeln('For each suggestion:');
    buffer.writeln('## [Brief description]');
    buffer.writeln('`[command]`');
    buffer.writeln('[Explanation of what this command does and why it\'s useful]');
    buffer.writeln();
    
    if (context != null) {
      buffer.writeln('Current context:');
      
      if (context.currentDirectory != null) {
        buffer.writeln('- Working in: ${context.currentDirectory}');
      }
      
      if (context.operatingSystem != null) {
        buffer.writeln('- Operating system: ${context.operatingSystem}');
      }
      
      if (context.recentCommands != null && context.recentCommands!.isNotEmpty) {
        buffer.writeln('- Recent activity: ${context.recentCommands!.take(5).join(', ')}');
      }
      
      if (context.availableTools != null && context.availableTools!.isNotEmpty) {
        buffer.writeln('- Available tools: ${context.availableTools!.join(', ')}');
      }
      
      buffer.writeln();
    }
    
    buffer.writeln('Focus on:');
    buffer.writeln('- Commonly used commands for the current context');
    buffer.writeln('- Commands that complement recent activity');
    buffer.writeln('- Productivity-enhancing utilities');
    buffer.writeln('- Safe, everyday operations');
    buffer.writeln();
    
    return buffer.toString();
  }

  /// Build user prompt for command generation
  static String buildUserPrompt(
    String naturalLanguage, {
    CommandContext? context,
    String? specificTask,
  }) {
    final buffer = StringBuffer();
    
    if (specificTask != null) {
      buffer.writeln('Task: $specificTask');
      buffer.writeln();
    }
    
    buffer.writeln('User request: $naturalLanguage');
    
    return buffer.toString();
  }

  /// Build user prompt for error explanation
  static String buildErrorUserPrompt(
    String command,
    String errorOutput, {
    CommandContext? context,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('Command that failed: $command');
    buffer.writeln();
    buffer.writeln('Error output:');
    buffer.writeln(errorOutput);
    
    return buffer.toString();
  }

  /// Build user prompt for suggestions
  static String buildSuggestionsUserPrompt({
    String? currentTask,
    List<String>? recentCommands,
    CommandContext? context,
  }) {
    final buffer = StringBuffer();
    
    if (currentTask != null && currentTask.isNotEmpty) {
      buffer.writeln('Current task: $currentTask');
      buffer.writeln();
    }
    
    buffer.writeln('Please suggest useful commands for the current context.');
    
    return buffer.toString();
  }
}