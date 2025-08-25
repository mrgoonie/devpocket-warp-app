import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../themes/app_theme.dart';
import '../../main.dart';
import '../../models/ai_models.dart';
import '../../models/ssh_profile_models.dart';
import '../../providers/ai_provider.dart';
import '../../screens/settings/api_key_screen.dart';
import 'enhanced_terminal_screen.dart';

// Terminal Block Model for tracking command execution
@immutable
class TerminalBlock {
  final String id;
  final String input;
  final String? output;
  final String? error;
  final bool isExecuting;
  final bool isAgentCommand;
  final CommandSuggestion? suggestion;
  final ErrorExplanation? errorExplanation;
  final DateTime timestamp;

  const TerminalBlock({
    required this.id,
    required this.input,
    this.output,
    this.error,
    this.isExecuting = false,
    this.isAgentCommand = false,
    this.suggestion,
    this.errorExplanation,
    required this.timestamp,
  });

  TerminalBlock copyWith({
    String? output,
    String? error,
    bool? isExecuting,
    CommandSuggestion? suggestion,
    ErrorExplanation? errorExplanation,
  }) {
    return TerminalBlock(
      id: id,
      input: input,
      output: output ?? this.output,
      error: error ?? this.error,
      isExecuting: isExecuting ?? this.isExecuting,
      isAgentCommand: isAgentCommand,
      suggestion: suggestion ?? this.suggestion,
      errorExplanation: errorExplanation ?? this.errorExplanation,
      timestamp: timestamp,
    );
  }
}

class TerminalScreen extends ConsumerStatefulWidget {
  final SshProfile? sshProfile;
  
  const TerminalScreen({super.key, this.sshProfile});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  final List<TerminalBlock> _blocks = [];
  final List<String> _commandHistory = [];
  // TODO: Implement command history navigation
  // int _historyIndex = -1;
  bool _isAgentMode = false;
  bool _showSuggestions = false;
  List<CommandSuggestion> _currentSuggestions = [];

  // Mock context for now - in real app this would come from SSH connection
  final CommandContext _currentContext = const CommandContext(
    currentDirectory: '/home/user',
    operatingSystem: 'Linux',
    shellType: 'bash',
    hostname: 'devserver-01',
    availableCommands: ['ls', 'cd', 'ps', 'docker', 'kubectl', 'git', 'vim'],
  );

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    _loadSmartSuggestions();
    
    // Handle SSH profile connection if provided
    if (widget.sshProfile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _connectToSshHost(widget.sshProfile!);
      });
    }
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _addWelcomeMessage() {
    final welcomeBlock = TerminalBlock(
      id: 'welcome',
      input: '',
      output: '''DevPocket Terminal v1.0.0 - AI-Powered SSH Client
Connected to ${_currentContext.hostname} (${_currentContext.operatingSystem})
Current directory: ${_currentContext.currentDirectory}

💡 Switch to Agent Mode to use natural language commands
⚙️  Configure AI features in Settings > AI Configuration
''',
      timestamp: DateTime.now(),
    );

    setState(() {
      _blocks.add(welcomeBlock);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aiEnabled = ref.watch(aiEnabledProvider);
    final hasValidKey = ref.watch(hasValidApiKeyProvider);
    final isNearLimit = ref.watch(isNearCostLimitProvider);

    return Scaffold(
      appBar: _buildAppBar(aiEnabled, hasValidKey, isNearLimit),
      body: Column(
        children: [
          // AI Status Banner (if needed)
          if (!hasValidKey || isNearLimit) _buildStatusBanner(hasValidKey, isNearLimit),
          
          // Terminal output area
          Expanded(
            child: Container(
              color: Colors.black,
              child: Column(
                children: [
                  // Terminal blocks
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _blocks.length,
                      itemBuilder: (context, index) {
                        return _buildTerminalBlock(_blocks[index], index);
                      },
                    ),
                  ),
                  
                  // Smart suggestions (if enabled and available)
                  if (_showSuggestions && _currentSuggestions.isNotEmpty && aiEnabled)
                    _buildSuggestionsBar(),
                ],
              ),
            ),
          ),
          
          // Input area
          _buildInputArea(aiEnabled, hasValidKey),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool aiEnabled, bool hasValidKey, bool isNearLimit) {
    return AppBar(
      title: const Text('Terminal'),
      centerTitle: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      actions: [
        // AI Mode toggle
        if (hasValidKey) ...[
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ToggleButtons(
              isSelected: [!_isAgentMode, _isAgentMode],
              onPressed: aiEnabled ? (index) {
                setState(() {
                  _isAgentMode = index == 1;
                  if (_isAgentMode) {
                    _loadSmartSuggestions();
                  }
                });
              } : null,
              borderRadius: BorderRadius.circular(8),
              selectedBorderColor: AppTheme.primaryColor,
              selectedColor: Colors.black,
              fillColor: AppTheme.primaryColor,
              color: AppTheme.darkTextSecondary,
              constraints: const BoxConstraints(
                minHeight: 36,
                minWidth: 60,
              ),
              children: const [
                Text('CMD', style: TextStyle(fontSize: 12)),
                Text('AI', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
        
        // Settings button
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ApiKeyScreen()),
          ),
          icon: Icon(
            hasValidKey ? Icons.settings : Icons.settings_outlined,
            color: hasValidKey ? AppTheme.primaryColor : Colors.orange,
          ),
        ),
        
        // SSH Terminal button
        TextButton.icon(
          onPressed: _openSshTerminal,
          icon: const Icon(Icons.terminal, size: 16),
          label: const Text('SSH', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(bool hasValidKey, bool isNearLimit) {
    if (!hasValidKey) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.orange.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'AI features disabled. Configure your OpenRouter API key to enable Agent Mode.',
                style: TextStyle(color: Colors.orange, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ApiKeyScreen()),
              ),
              child: const Text('Setup', style: TextStyle(color: Colors.orange)),
            ),
          ],
        ),
      );
    }

    if (isNearLimit) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.red.withValues(alpha: 0.1),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Approaching daily AI usage limit. Check usage in settings.',
                style: TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ApiKeyScreen()),
              ),
              child: const Text('View Usage', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildTerminalBlock(TerminalBlock block, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input line
          if (block.input.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.isAgentCommand ? '🤖 ' : '\$ ',
                  style: AppTheme.terminalTextStyle.copyWith(
                    color: block.isAgentCommand 
                        ? AppTheme.primaryColor 
                        : AppTheme.terminalGreen,
                  ),
                ),
                Expanded(
                  child: Text(
                    block.input,
                    style: AppTheme.terminalTextStyle.copyWith(
                      color: block.isAgentCommand 
                          ? AppTheme.primaryColor 
                          : AppTheme.terminalGreen,
                    ),
                  ),
                ),
                if (block.isExecuting) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        block.isAgentCommand 
                            ? AppTheme.primaryColor 
                            : AppTheme.terminalGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Command suggestion (for agent commands)
          if (block.suggestion != null) ...[
            _buildCommandSuggestionInline(block.suggestion!),
            const SizedBox(height: 8),
          ],

          // Output
          if (block.output != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                block.output!,
                style: AppTheme.terminalTextStyle.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Error with AI explanation
          if (block.error != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    block.error!,
                    style: AppTheme.terminalTextStyle.copyWith(
                      color: Colors.red,
                    ),
                  ),
                  if (block.errorExplanation != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorExplanationInline(block.errorExplanation!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildCommandSuggestionInline(CommandSuggestion suggestion) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(left: 16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppTheme.primaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              const Text(
                'AI Generated Command',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildConfidenceBadge(suggestion.confidence),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.command,
                    style: AppTheme.terminalTextStyle.copyWith(
                      color: AppTheme.terminalGreen,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _copyToClipboard(suggestion.command),
                  icon: const Icon(Icons.copy, size: 16),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          if (suggestion.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              suggestion.explanation,
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorExplanationInline(ErrorExplanation explanation) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.help_outline,
                color: Colors.red,
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'AI Error Explanation',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            explanation.explanation,
            style: TextStyle(
              color: Colors.red.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          if (explanation.suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Suggestions:',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            ...explanation.suggestions.map(
              (suggestion) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• $suggestion',
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    Color color = Colors.orange;
    String label = 'Low';
    
    if (confidence >= 0.8) {
      color = Colors.green;
      label = 'High';
    } else if (confidence >= 0.6) {
      color = Colors.orange;
      label = 'Med';
    } else {
      color = Colors.red;
      label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSuggestionsBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        border: const Border(
          top: BorderSide(color: AppTheme.darkBorderColor),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _currentSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _currentSuggestions[index];
          return _buildSuggestionChip(suggestion);
        },
      ),
    );
  }

  Widget _buildSuggestionChip(CommandSuggestion suggestion) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          suggestion.command,
          style: const TextStyle(fontSize: 12),
        ),
        onPressed: () {
          _commandController.text = suggestion.command;
          _inputFocusNode.requestFocus();
        },
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
    );
  }

  Widget _buildInputArea(bool aiEnabled, bool hasValidKey) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.isDarkMode ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: const Border(
          top: BorderSide(color: AppTheme.darkBorderColor),
        ),
      ),
      child: Column(
        children: [
          // Mode indicator and controls
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isAgentMode 
                      ? AppTheme.primaryColor.withValues(alpha: 0.2)
                      : AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _isAgentMode 
                        ? AppTheme.primaryColor
                        : AppTheme.darkBorderColor,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isAgentMode ? Icons.psychology : Icons.terminal,
                      size: 16,
                      color: _isAgentMode 
                          ? AppTheme.primaryColor
                          : AppTheme.darkTextSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isAgentMode ? 'Agent Mode' : 'Command Mode',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isAgentMode 
                            ? AppTheme.primaryColor
                            : AppTheme.darkTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Suggestions toggle
              if (hasValidKey && aiEnabled) ...[
                TextButton.icon(
                  onPressed: _toggleSuggestions,
                  icon: Icon(
                    _showSuggestions ? Icons.lightbulb : Icons.lightbulb_outline,
                    size: 16,
                  ),
                  label: const Text('Suggestions', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: _showSuggestions 
                        ? AppTheme.primaryColor 
                        : AppTheme.darkTextSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Command input
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isAgentMode && hasValidKey
                          ? AppTheme.primaryColor
                          : AppTheme.terminalGreen,
                    ),
                  ),
                  child: TextField(
                    controller: _commandController,
                    focusNode: _inputFocusNode,
                    style: AppTheme.terminalTextStyle.copyWith(
                      color: AppTheme.terminalGreen,
                    ),
                    decoration: InputDecoration(
                      hintText: _getInputHint(),
                      hintStyle: AppTheme.terminalTextStyle.copyWith(
                        color: AppTheme.darkTextSecondary,
                      ),
                      prefixIcon: Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          _isAgentMode && hasValidKey ? '🤖' : '\$',
                          style: TextStyle(
                            color: _isAgentMode && hasValidKey
                                ? AppTheme.primaryColor
                                : AppTheme.terminalGreen,
                            fontFamily: AppTheme.terminalFont,
                          ),
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: _executeCommand,
                    onChanged: _onInputChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _executeCommand(_commandController.text),
                icon: Icon(
                  _isAgentMode && hasValidKey ? Icons.psychology : Icons.play_arrow,
                  color: _isAgentMode && hasValidKey
                      ? AppTheme.primaryColor
                      : AppTheme.terminalGreen,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: _isAgentMode && hasValidKey
                          ? AppTheme.primaryColor
                          : AppTheme.terminalGreen,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getInputHint() {
    final hasValidKey = ref.read(hasValidApiKeyProvider);
    
    if (_isAgentMode && hasValidKey) {
      return 'Ask AI: "show running processes" or "find large files"';
    } else if (_isAgentMode && !hasValidKey) {
      return 'AI mode disabled - configure API key in settings';
    } else {
      return '\$ Enter command...';
    }
  }

  void _onInputChanged(String value) {
    // Handle up/down arrow for command history
    // This would be implemented with RawKeyboardListener in a full implementation
  }

  Future<void> _executeCommand(String command) async {
    if (command.trim().isEmpty) return;

    final blockId = DateTime.now().millisecondsSinceEpoch.toString();
    final hasValidKey = ref.read(hasValidApiKeyProvider);
    final isAgent = _isAgentMode && hasValidKey;

    // Create initial block
    final block = TerminalBlock(
      id: blockId,
      input: command,
      isExecuting: true,
      isAgentCommand: isAgent,
      timestamp: DateTime.now(),
    );

    setState(() {
      _blocks.add(block);
      _commandHistory.add(command);
      // TODO: Implement command history navigation
      // _historyIndex = -1;
    });

    _commandController.clear();
    _scrollToBottom();

    if (isAgent) {
      await _handleAgentCommand(blockId, command);
    } else {
      await _handleRegularCommand(blockId, command);
    }
  }

  Future<void> _handleAgentCommand(String blockId, String command) async {
    final aiService = ref.read(aiServiceProvider);
    final cacheNotifier = ref.read(commandCacheProvider.notifier);
    final usageNotifier = ref.read(aiUsageProvider.notifier);

    try {
      // Check cache first
      final cached = cacheNotifier.getCached(command, _currentContext);
      if (cached != null) {
        _updateBlock(blockId, suggestion: cached);
        await _executeGeneratedCommand(blockId, cached.command);
        return;
      }

      // Generate command with AI
      final suggestion = await aiService.generateCommand(
        command,
        context: _currentContext,
      );

      // Cache the suggestion
      await cacheNotifier.cache(command, suggestion, context: _currentContext);

      // Record usage
      await usageNotifier.recordUsage(
        model: ref.read(selectedModelProvider),
        tokenCount: 100, // Estimated
        estimatedCost: 0.001, // Estimated
      );

      // Update block with suggestion
      _updateBlock(blockId, suggestion: suggestion);

      // Auto-execute if confidence is high
      if (suggestion.isHighConfidence) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _executeGeneratedCommand(blockId, suggestion.command);
      }

    } catch (e) {
      _updateBlock(
        blockId,
        isExecuting: false,
        error: 'AI Error: ${e.toString()}',
      );
    }
  }

  Future<void> _handleRegularCommand(String blockId, String command) async {
    // Simulate command execution
    await Future.delayed(const Duration(milliseconds: 500));

    // Simulate some outputs based on command
    String output = _simulateCommandOutput(command);
    String? error;

    // Simulate occasional errors
    if (command.contains('invalid') || command.startsWith('badcommand')) {
      error = 'Command not found: $command';
      output = '';
      
      // Generate AI explanation for errors
      await _explainError(blockId, command, error);
    }

    _updateBlock(
      blockId,
      isExecuting: false,
      output: output,
      error: error,
    );
  }

  Future<void> _executeGeneratedCommand(String blockId, String command) async {
    // Simulate executing the AI-generated command
    await Future.delayed(const Duration(milliseconds: 800));
    
    final output = _simulateCommandOutput(command);
    _updateBlock(blockId, isExecuting: false, output: output);
  }

  Future<void> _explainError(String blockId, String command, String error) async {
    final hasValidKey = ref.read(hasValidApiKeyProvider);
    final settings = ref.watch(aiFeatureSettingsProvider);
    
    if (!hasValidKey || !settings.autoErrorExplanation) return;

    final aiService = ref.read(aiServiceProvider);
    
    try {
      final explanation = await aiService.explainError(
        command,
        error,
        context: _currentContext,
      );
      
      _updateBlock(blockId, errorExplanation: explanation);
    } catch (e) {
      // Silently fail error explanation
    }
  }

  String _simulateCommandOutput(String command) {
    if (command.startsWith('ls')) {
      return 'file1.txt\nfile2.txt\ndirectory1/\ndirectory2/';
    } else if (command.startsWith('ps')) {
      return '''PID TTY          TIME CMD
 1234 pts/0    00:00:01 bash
 1235 pts/0    00:00:00 ps''';
    } else if (command.contains('docker')) {
      return '''CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
abc123def456   nginx     "nginx"   2 hours   Up 2hrs   0.0.0.0:80->80/tcp   web''';
    } else if (command.contains('kubectl') || command.contains('k8s')) {
      return '''NAME                     READY   STATUS    RESTARTS   AGE
nginx-deployment-1234    1/1     Running   0          2h
mysql-pod-5678           1/1     Running   0          1h''';
    } else {
      return 'Command executed successfully.';
    }
  }

  void _updateBlock(
    String blockId, {
    String? output,
    String? error,
    bool? isExecuting,
    CommandSuggestion? suggestion,
    ErrorExplanation? errorExplanation,
  }) {
    setState(() {
      final index = _blocks.indexWhere((block) => block.id == blockId);
      if (index != -1) {
        _blocks[index] = _blocks[index].copyWith(
          output: output,
          error: error,
          isExecuting: isExecuting,
          suggestion: suggestion,
          errorExplanation: errorExplanation,
        );
      }
    });
  }

  Future<void> _loadSmartSuggestions() async {
    final hasValidKey = ref.read(hasValidApiKeyProvider);
    final settings = ref.watch(aiFeatureSettingsProvider);
    
    if (!hasValidKey || !settings.smartSuggestionsEnabled) return;

    final aiService = ref.read(aiServiceProvider);
    
    try {
      final suggestions = await aiService.getSmartSuggestions(
        context: _currentContext,
        recentCommands: _commandHistory.take(5).toList(),
      );
      
      setState(() {
        _currentSuggestions = suggestions;
      });
    } catch (e) {
      // Silently fail suggestions
    }
  }

  void _toggleSuggestions() {
    setState(() {
      _showSuggestions = !_showSuggestions;
      if (_showSuggestions && _currentSuggestions.isEmpty) {
        _loadSmartSuggestions();
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openSshTerminal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnhancedTerminalScreen(),
      ),
    );
  }
  
  /// Connect to SSH host using provided SSH profile
  void _connectToSshHost(SshProfile sshProfile) {
    debugPrint('[Terminal] Connecting to SSH host: ${sshProfile.name} (${sshProfile.host})');
    
    // Add connection status block
    final connectionBlock = TerminalBlock(
      id: 'ssh-connect-${DateTime.now().millisecondsSinceEpoch}',
      input: 'ssh ${sshProfile.username}@${sshProfile.host}',
      output: null,
      error: null,
      isExecuting: true,
      isAgentCommand: false,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _blocks.add(connectionBlock);
    });
    
    // Scroll to show the new block
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
    
    // TODO: Implement actual SSH connection logic
    // For now, just simulate the connection attempt
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        final index = _blocks.indexWhere((b) => b.id == connectionBlock.id);
        if (index != -1) {
          _blocks[index] = connectionBlock.copyWith(
            isExecuting: false,
            output: 'Connected to ${sshProfile.host} as ${sshProfile.username}\n'
                   'Welcome to ${sshProfile.name}\n'
                   'Type commands to interact with the remote host.',
          );
        }
      });
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    });
  }

}