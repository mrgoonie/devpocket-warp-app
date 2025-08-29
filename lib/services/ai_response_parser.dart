import '../models/ai_models.dart';

/// Parses AI responses into structured data
class AIResponseParser {
  
  /// Parse command generation response
  static CommandSuggestion parseCommandResponse(String response) {
    String command = '';
    String explanation = '';
    double confidence = 0.8;
    List<String> tags = [];

    try {
      // Try to parse structured response
      final lines = response.split('\n');
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        
        if (line.toLowerCase().startsWith('command:')) {
          command = line.substring(8).trim();
        } else if (line.toLowerCase().startsWith('explanation:')) {
          explanation = _extractMultilineValue(lines, i).trim();
        } else if (line.toLowerCase().startsWith('confidence:')) {
          final confStr = line.substring(11).trim();
          confidence = double.tryParse(confStr) ?? confidence;
        } else if (line.toLowerCase().startsWith('tags:')) {
          final tagsStr = line.substring(5).trim();
          tags = tagsStr.split(',').map((tag) => tag.trim()).toList();
        }
      }
    } catch (e) {
      // Fallback parsing if structured format isn't followed
    }

    // Fallback parsing if structured format isn't followed
    if (command.isEmpty) {
      // Try to extract command from code blocks or first line
      final codeBlockMatch = RegExp(r'```(?:bash|shell)?\n?([^`]+)```').firstMatch(response);
      if (codeBlockMatch != null) {
        command = codeBlockMatch.group(1)?.trim() ?? '';
      } else {
        // Use first non-empty line that looks like a command
        final lines = response.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#') && !trimmed.toLowerCase().contains('explanation')) {
            command = trimmed;
            break;
          }
        }
      }
    }

    if (explanation.isEmpty) {
      explanation = response.replaceAll(RegExp(r'```[^`]*```'), '').trim();
    }

    return CommandSuggestion(
      command: command,
      explanation: explanation,
      confidence: confidence,
      naturalLanguageQuery: '',
      tags: tags,
    );
  }

  /// Parse error explanation response
  static ErrorExplanation parseErrorResponse(String response) {
    String explanation = '';
    List<String> suggestions = [];
    List<String> causes = [];
    double severity = 0.5;

    try {
      final lines = response.split('\n');
      String currentSection = '';
      
      for (final line in lines) {
        final trimmed = line.trim();
        
        if (trimmed.toLowerCase().startsWith('explanation:')) {
          currentSection = 'explanation';
          explanation = trimmed.substring(12).trim();
        } else if (trimmed.toLowerCase().startsWith('suggestions:')) {
          currentSection = 'suggestions';
        } else if (trimmed.toLowerCase().startsWith('causes:')) {
          currentSection = 'causes';
        } else if (trimmed.toLowerCase().startsWith('severity:')) {
          final sevStr = trimmed.substring(9).trim();
          severity = double.tryParse(sevStr) ?? severity;
        } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
          final item = trimmed.substring(2).trim();
          if (currentSection == 'suggestions') {
            suggestions.add(item);
          } else if (currentSection == 'causes') {
            causes.add(item);
          }
        } else if (currentSection == 'explanation' && trimmed.isNotEmpty) {
          explanation += ' $trimmed';
        }
      }
    } catch (e) {
      // Fallback parsing
    }

    // Fallback if structured parsing fails
    if (explanation.isEmpty) {
      explanation = response.trim();
    }

    return ErrorExplanation(
      originalCommand: '',
      errorOutput: '',
      explanation: explanation,
      suggestions: suggestions,
      potentialCauses: causes,
      timestamp: DateTime.now(),
    );
  }

  /// Parse smart suggestions response
  static List<CommandSuggestion> parseSuggestionsResponse(String response) {
    final suggestions = <CommandSuggestion>[];
    
    try {
      final lines = response.split('\n');
      CommandSuggestion? currentSuggestion;
      
      for (final line in lines) {
        final trimmed = line.trim();
        
        if (trimmed.startsWith('##') || trimmed.startsWith('**')) {
          // New suggestion header
          if (currentSuggestion != null) {
            suggestions.add(currentSuggestion);
          }
          
          String command = '';
          String explanation = '';
          double confidence = 0.8;
          List<String> tags = [];
          
          currentSuggestion = CommandSuggestion(
            command: command,
            explanation: explanation,
            confidence: confidence,
            naturalLanguageQuery: '',
            tags: tags,
          );
          
        } else if (trimmed.startsWith('`') && trimmed.endsWith('`')) {
          // Command in backticks
          if (currentSuggestion != null) {
            final newSuggestion = CommandSuggestion(
              command: trimmed.substring(1, trimmed.length - 1),
              explanation: currentSuggestion.explanation,
              confidence: currentSuggestion.confidence,
              naturalLanguageQuery: currentSuggestion.naturalLanguageQuery,
              tags: currentSuggestion.tags,
            );
            currentSuggestion = newSuggestion;
          }
          
        } else if (trimmed.isNotEmpty && currentSuggestion != null) {
          // Description line
          final newSuggestion = CommandSuggestion(
            command: currentSuggestion.command,
            explanation: currentSuggestion.explanation.isEmpty 
              ? trimmed 
              : '${currentSuggestion.explanation} $trimmed',
            confidence: currentSuggestion.confidence,
            naturalLanguageQuery: currentSuggestion.naturalLanguageQuery,
            tags: currentSuggestion.tags,
          );
          currentSuggestion = newSuggestion;
        }
      }
      
      if (currentSuggestion != null) {
        suggestions.add(currentSuggestion);
      }
    } catch (e) {
      // Fallback parsing
    }

    return suggestions;
  }

  /// Extract multiline value from response lines
  static String _extractMultilineValue(List<String> lines, int startIndex) {
    final buffer = StringBuffer();
    
    // Start with the content after the colon on the same line
    final firstLine = lines[startIndex];
    final colonIndex = firstLine.indexOf(':');
    if (colonIndex != -1 && colonIndex < firstLine.length - 1) {
      buffer.write(firstLine.substring(colonIndex + 1).trim());
    }
    
    // Continue with subsequent lines until we hit another field or empty line
    for (int i = startIndex + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      
      if (line.isEmpty || line.contains(':')) {
        break;
      }
      
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(line);
    }
    
    return buffer.toString();
  }
}