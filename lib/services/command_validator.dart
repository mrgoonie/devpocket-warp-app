import '../models/enhanced_ssh_models.dart';

/// Comprehensive command validation service to prevent injection attacks
/// Implements multiple security layers for command sanitization and validation
class CommandValidator {
  // Dangerous command patterns that should be blocked
  static const List<String> _dangerousCommands = [
    'rm -rf',
    'format',
    'mkfs',
    'dd if=',
    'shutdown',
    'reboot',
    'halt',
    'init 0',
    'init 6',
    'killall',
    'pkill',
    ':(){ :|:& };:', // Fork bomb
    'chmod 777',
    'chown root',
    'sudo su',
    'passwd',
  ];
  
  // Dangerous metacharacters and operators
  static const List<String> _dangerousMetacharacters = [
    '&&', '||', '|', ';', '`', '\$(',
    '>', '>>', '<', '<<', '&',
  ];
  
  // File system paths that should be protected
  static const List<String> _protectedPaths = [
    '/etc/',
    '/boot/',
    '/sys/',
    '/proc/',
    '/dev/',
    '/var/log/',
    '/usr/bin/',
    '/usr/sbin/',
    '/sbin/',
    '/bin/',
    'C:\\Windows\\',
    'C:\\Program Files\\',
    'C:\\System Volume Information\\',
  ];
  
  // Safe commands that are always allowed
  static const List<String> _safeCommands = [
    'ls', 'dir', 'pwd', 'whoami', 'id', 'date', 'uptime',
    'ps', 'top', 'htop', 'free', 'df', 'du', 'mount',
    'cat', 'less', 'more', 'head', 'tail', 'grep',
    'find', 'locate', 'which', 'whereis', 'history',
    'echo', 'printf', 'wc', 'sort', 'uniq', 'cut',
    'awk', 'sed', 'tr', 'tee', 'xargs',
  ];
  
  /// Validation result with security analysis
  static const ValidationLevel _defaultLevel = ValidationLevel.strict;
  
  /// Validate a command before execution
  static CommandValidationResult validateCommand(
    String command, {
    ValidationLevel level = _defaultLevel,
    List<String>? additionalAllowedCommands,
    List<String>? additionalBlockedCommands,
    bool allowFileOperations = false,
    bool allowNetworkOperations = true,
    bool allowSystemCommands = false,
  }) {
    final normalizedCommand = command.trim().toLowerCase();
    
    // Check for empty command
    if (normalizedCommand.isEmpty) {
      return CommandValidationResult.invalid('Empty command not allowed');
    }
    
    // Check command length (prevent buffer overflow attempts)
    if (command.length > 8192) {
      return CommandValidationResult.invalid('Command too long (max 8192 characters)');
    }
    
    // Extract base command
    final baseCommand = _extractBaseCommand(normalizedCommand);
    
    // Apply validation levels
    switch (level) {
      case ValidationLevel.permissive:
        return _validatePermissive(
          command,
          normalizedCommand,
          baseCommand,
          additionalBlockedCommands ?? [],
        );
      
      case ValidationLevel.moderate:
        return _validateModerate(
          command,
          normalizedCommand,
          baseCommand,
          allowFileOperations,
          allowNetworkOperations,
          additionalAllowedCommands ?? [],
          additionalBlockedCommands ?? [],
        );
      
      case ValidationLevel.strict:
        return _validateStrict(
          command,
          normalizedCommand,
          baseCommand,
          allowFileOperations,
          allowNetworkOperations,
          allowSystemCommands,
          additionalAllowedCommands ?? [],
          additionalBlockedCommands ?? [],
        );
      
      case ValidationLevel.whitelist:
        return _validateWhitelist(
          command,
          normalizedCommand,
          baseCommand,
          additionalAllowedCommands ?? _safeCommands,
        );
    }
  }
  
  /// Check if command is potentially dangerous
  static bool isDangerousCommand(String command) {
    final normalizedCommand = command.trim().toLowerCase();
    
    // Check against dangerous command patterns
    for (final dangerous in _dangerousCommands) {
      if (normalizedCommand.contains(dangerous)) {
        return true;
      }
    }
    
    // Check for dangerous metacharacters
    for (final meta in _dangerousMetacharacters) {
      if (normalizedCommand.contains(meta)) {
        return true;
      }
    }
    
    // Check for protected paths
    for (final path in _protectedPaths) {
      if (normalizedCommand.contains(path.toLowerCase())) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Sanitize command by removing/escaping dangerous elements
  static String sanitizeCommand(String command) {
    String sanitized = command.trim();
    
    // Remove null bytes and control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    // Remove dangerous metacharacters (basic sanitization)
    sanitized = sanitized.replaceAll(RegExp(r'[;&|`$]'), '');
    
    // Remove multiple spaces
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    return sanitized;
  }
  
  /// Extract the base command from a command line
  static String _extractBaseCommand(String command) {
    final parts = command.split(RegExp(r'\s+'));
    if (parts.isEmpty) return '';
    
    String baseCommand = parts.first;
    
    // Remove sudo prefix if present
    if (baseCommand == 'sudo' && parts.length > 1) {
      baseCommand = parts[1];
    }
    
    return baseCommand;
  }
  
  /// Permissive validation - only blocks obviously dangerous commands
  static CommandValidationResult _validatePermissive(
    String originalCommand,
    String normalizedCommand,
    String baseCommand,
    List<String> additionalBlocked,
  ) {
    // Check additional blocked commands
    for (final blocked in additionalBlocked) {
      if (normalizedCommand.contains(blocked.toLowerCase())) {
        return CommandValidationResult.blocked(
          'Command contains blocked pattern: $blocked',
        );
      }
    }
    
    // Check most dangerous patterns
    if (normalizedCommand.contains('rm -rf /') ||
        normalizedCommand.contains('format c:') ||
        normalizedCommand.contains(':(){ :|:& };:')) {
      return CommandValidationResult.blocked(
        'Extremely dangerous command blocked',
      );
    }
    
    return CommandValidationResult.allowed(
      'Command allowed under permissive validation',
      securityLevel: SecurityLevel.low,
    );
  }
  
  /// Moderate validation - blocks common dangerous patterns
  static CommandValidationResult _validateModerate(
    String originalCommand,
    String normalizedCommand,
    String baseCommand,
    bool allowFileOperations,
    bool allowNetworkOperations,
    List<String> additionalAllowed,
    List<String> additionalBlocked,
  ) {
    // Check dangerous commands
    if (isDangerousCommand(normalizedCommand)) {
      return CommandValidationResult.blocked(
        'Command contains dangerous patterns',
      );
    }
    
    // Check additional blocked commands
    for (final blocked in additionalBlocked) {
      if (normalizedCommand.contains(blocked.toLowerCase())) {
        return CommandValidationResult.blocked(
          'Command contains blocked pattern: $blocked',
        );
      }
    }
    
    // Check file operations
    if (!allowFileOperations && _isFileOperation(baseCommand)) {
      return CommandValidationResult.blocked(
        'File operations not allowed: $baseCommand',
      );
    }
    
    // Check network operations
    if (!allowNetworkOperations && _isNetworkOperation(baseCommand)) {
      return CommandValidationResult.blocked(
        'Network operations not allowed: $baseCommand',
      );
    }
    
    return CommandValidationResult.allowed(
      'Command allowed under moderate validation',
      securityLevel: SecurityLevel.medium,
    );
  }
  
  /// Strict validation - comprehensive security checks
  static CommandValidationResult _validateStrict(
    String originalCommand,
    String normalizedCommand,
    String baseCommand,
    bool allowFileOperations,
    bool allowNetworkOperations,
    bool allowSystemCommands,
    List<String> additionalAllowed,
    List<String> additionalBlocked,
  ) {
    // All moderate validation checks
    final moderateResult = _validateModerate(
      originalCommand,
      normalizedCommand,
      baseCommand,
      allowFileOperations,
      allowNetworkOperations,
      additionalAllowed,
      additionalBlocked,
    );
    
    if (!moderateResult.isAllowed) {
      return moderateResult;
    }
    
    // Additional strict checks
    
    // Block system administration commands
    if (!allowSystemCommands && _isSystemCommand(baseCommand)) {
      return CommandValidationResult.blocked(
        'System commands not allowed: $baseCommand',
      );
    }
    
    // Check for command injection attempts
    if (_hasInjectionPatterns(normalizedCommand)) {
      return CommandValidationResult.blocked(
        'Potential command injection detected',
      );
    }
    
    // Check for suspicious argument patterns
    if (_hasSuspiciousArguments(originalCommand)) {
      return CommandValidationResult.blocked(
        'Suspicious command arguments detected',
      );
    }
    
    // Check command length and complexity
    if (_isOverlyComplex(originalCommand)) {
      return CommandValidationResult.warning(
        'Command is complex and may pose security risks',
        securityLevel: SecurityLevel.medium,
      );
    }
    
    return CommandValidationResult.allowed(
      'Command allowed under strict validation',
      securityLevel: SecurityLevel.high,
    );
  }
  
  /// Whitelist validation - only allows explicitly permitted commands
  static CommandValidationResult _validateWhitelist(
    String originalCommand,
    String normalizedCommand,
    String baseCommand,
    List<String> allowedCommands,
  ) {
    if (!allowedCommands.contains(baseCommand)) {
      return CommandValidationResult.blocked(
        'Command not in whitelist: $baseCommand',
      );
    }
    
    // Even whitelisted commands should not have dangerous arguments
    if (_hasSuspiciousArguments(originalCommand)) {
      return CommandValidationResult.blocked(
        'Whitelisted command has dangerous arguments',
      );
    }
    
    return CommandValidationResult.allowed(
      'Command in whitelist',
      securityLevel: SecurityLevel.high,
    );
  }
  
  /// Check if command is a file operation
  static bool _isFileOperation(String command) {
    const fileOperationCommands = [
      'cp', 'mv', 'rm', 'rmdir', 'mkdir', 'touch', 'chmod', 'chown',
      'copy', 'move', 'del', 'md', 'rd', 'attrib', 'takeown',
    ];
    return fileOperationCommands.contains(command);
  }
  
  /// Check if command is a network operation
  static bool _isNetworkOperation(String command) {
    const networkCommands = [
      'curl', 'wget', 'nc', 'netcat', 'telnet', 'ssh', 'scp', 'sftp',
      'ping', 'traceroute', 'nslookup', 'dig', 'netstat', 'ss',
    ];
    return networkCommands.contains(command);
  }
  
  /// Check if command is a system administration command
  static bool _isSystemCommand(String command) {
    const systemCommands = [
      'systemctl', 'service', 'mount', 'umount', 'fdisk', 'parted',
      'useradd', 'userdel', 'groupadd', 'crontab', 'at', 'batch',
      'iptables', 'ufw', 'firewall-cmd', 'semanage',
    ];
    return systemCommands.contains(command);
  }
  
  /// Check for command injection patterns
  static bool _hasInjectionPatterns(String command) {
    const injectionPatterns = [
      r'$(', '`', r'${', '||', '&&', '|', ';',
      'eval', 'exec', 'system',
    ];
    
    for (final pattern in injectionPatterns) {
      if (command.contains(pattern)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check for suspicious arguments
  static bool _hasSuspiciousArguments(String command) {
    // Check for suspicious patterns in arguments
    final suspiciousPatterns = [
      RegExp(r'--?force'),
      RegExp(r'--?recursive'),
      RegExp(r'-rf\b'),
      RegExp(r'/\*'),
      RegExp(r'\.\./'),
      RegExp(r'\\\\'),
    ];
    
    for (final pattern in suspiciousPatterns) {
      if (pattern.hasMatch(command)) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Check if command is overly complex
  static bool _isOverlyComplex(String command) {
    // Count various complexity indicators
    int complexity = 0;
    
    // Count pipes
    complexity += RegExp(r'\|').allMatches(command).length;
    
    // Count redirections
    complexity += RegExp(r'[<>]').allMatches(command).length;
    
    // Count logical operators
    complexity += RegExp(r'(\|\||\&\&)').allMatches(command).length;
    
    // Count semicolons
    complexity += ';'.allMatches(command).length;
    
    // Command length factor
    if (command.length > 200) complexity += 2;
    if (command.length > 500) complexity += 3;
    
    return complexity > 5;
  }
}

/// Validation levels for command checking
enum ValidationLevel {
  permissive, // Minimal validation
  moderate,   // Standard validation
  strict,     // Comprehensive validation
  whitelist,  // Only allow whitelisted commands
}

// SecurityLevel is imported from enhanced_ssh_models.dart

/// Command validation result
class CommandValidationResult {
  final bool isAllowed;
  final bool isWarning;
  final String message;
  final SecurityLevel securityLevel;
  final DateTime timestamp;
  
  const CommandValidationResult._({
    required this.isAllowed,
    required this.isWarning,
    required this.message,
    required this.securityLevel,
    required this.timestamp,
  });
  
  /// Create an allowed result
  factory CommandValidationResult.allowed(
    String message, {
    SecurityLevel securityLevel = SecurityLevel.medium,
  }) {
    return CommandValidationResult._(
      isAllowed: true,
      isWarning: false,
      message: message,
      securityLevel: securityLevel,
      timestamp: DateTime.now(),
    );
  }
  
  /// Create a blocked result
  factory CommandValidationResult.blocked(String message) {
    return CommandValidationResult._(
      isAllowed: false,
      isWarning: false,
      message: message,
      securityLevel: SecurityLevel.low,
      timestamp: DateTime.now(),
    );
  }
  
  /// Create an invalid result
  factory CommandValidationResult.invalid(String message) {
    return CommandValidationResult._(
      isAllowed: false,
      isWarning: false,
      message: message,
      securityLevel: SecurityLevel.low,
      timestamp: DateTime.now(),
    );
  }
  
  /// Create a warning result (allowed but risky)
  factory CommandValidationResult.warning(
    String message, {
    SecurityLevel securityLevel = SecurityLevel.medium,
  }) {
    return CommandValidationResult._(
      isAllowed: true,
      isWarning: true,
      message: message,
      securityLevel: securityLevel,
      timestamp: DateTime.now(),
    );
  }
  
  bool get isBlocked => !isAllowed;
  bool get isSafe => isAllowed && securityLevel == SecurityLevel.high;
  
  @override
  String toString() {
    final status = isAllowed ? (isWarning ? 'WARNING' : 'ALLOWED') : 'BLOCKED';
    return '$status: $message (Security: ${securityLevel.name})';
  }
}