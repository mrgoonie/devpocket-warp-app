# Terminal SSH Interaction Enhancement Implementation Plan

**Date**: 2025-08-26  
**Type**: Bug Fix + Feature Enhancement  
**Priority**: High  
**Context Tokens**: ~150 words

## Executive Summary

Fix critical Terminal SSH interaction behavior issues where welcome messages are duplicated, command outputs are mixed, and interactive commands don't work properly. Implement a proper PTY-based SSH session management with Warp-style block-based terminal UI and command/AI mode switching.

## Issue Analysis

### Current Problems
- [ ] After SSH connection, only shows "Connected to..." message, missing host welcome message
- [ ] Command outputs show duplicated welcome messages instead of actual command results
- [ ] Interactive commands (vi, nano, htop) don't work properly
- [ ] No proper terminal session state management
- [ ] Missing block-based terminal UI for better command organization

### Root Cause
The current SSH implementation using dartssh2 lacks proper PTY (pseudo-terminal) setup and session management. The shell connection doesn't properly separate welcome messages from command outputs, and there's no interactive terminal support.

### Evidence
- **Components Affected**: 
  - `lib/services/ssh_connection_manager.dart` - Basic shell connection without PTY
  - `lib/services/terminal_session_handler.dart` - Session management layer
  - `lib/widgets/terminal/ssh_terminal_widget.dart` - Terminal UI using xterm
  - `lib/screens/terminal/enhanced_terminal_screen.dart` - Terminal screen layout

## Context Links
- **dartssh2 Documentation**: PTY support via `client.shell()` method
- **xterm.dart**: Terminal emulator widget
- **Current Architecture**: WebSocket fallback with direct SSH connection

## Solution Design

### Approach
Implement proper PTY-based SSH sessions using dartssh2's shell capabilities with proper stdin/stdout/stderr handling, create block-based terminal UI inspired by Warp.dev, and add command/AI mode switching functionality.

### Architecture Changes
1. **Enhanced SSH Session Management**: Replace basic shell connection with PTY-based sessions
2. **Block-based Terminal UI**: Create command execution blocks with input/output separation
3. **Input Mode Switching**: Toggle between direct command input and AI-assisted command generation
4. **Proper Stream Handling**: Separate welcome messages, command echoes, and command outputs

### Key Components
1. **Enhanced SSH Connection Manager**: PTY-based session management
2. **Terminal Block System**: Warp-style command/output blocks
3. **Input Mode Controller**: Command vs AI mode switching
4. **Session State Manager**: Proper interactive command handling

## Implementation Steps

### Phase 1: Enhanced SSH Session Management
1. [ ] **Update SSH Connection Manager** - `lib/services/ssh_connection_manager.dart`
   - Replace basic shell with PTY-enabled shell sessions
   - Implement proper stdin/stdout/stderr stream handling
   - Add session state tracking for interactive commands
   - Separate welcome message handling from command output

2. [ ] **Enhance Terminal Session Handler** - `lib/services/terminal_session_handler.dart`
   - Add PTY session creation methods
   - Implement command execution tracking
   - Add session health monitoring
   - Create proper error handling and recovery

### Phase 2: Terminal UI Enhancements
3. [ ] **Create Terminal Block System** - `lib/widgets/terminal/terminal_block.dart`
   - Design block-based command execution UI
   - Implement input/output separation within blocks
   - Add command status indicators (running, completed, failed)
   - Create block history management

4. [ ] **Enhance SSH Terminal Widget** - `lib/widgets/terminal/ssh_terminal_widget.dart`
   - Replace single xterm widget with block-based UI
   - Implement scrollable command history
   - Add welcome message display area
   - Create interactive command handling

### Phase 3: Input Mode System
5. [ ] **Create Input Mode Controller** - `lib/services/terminal_input_mode_service.dart`
   - Implement command/AI mode switching logic
   - Create mode-specific input handlers
   - Add mode state persistence
   - Integrate with AI command generation service

6. [ ] **Update Terminal Screen** - `lib/screens/terminal/enhanced_terminal_screen.dart`
   - Add input mode toggle switch
   - Implement mode-specific input field behavior
   - Create command suggestion UI
   - Add keyboard shortcut support

### Phase 4: Command History Integration
7. [ ] **Enhance Command History Service** - `lib/services/history_service.dart`
   - Add command execution context tracking
   - Implement session-based command grouping
   - Create AI-generated command tagging
   - Add command execution metrics

8. [ ] **API Integration Updates** - `lib/services/api_client.dart`
   - Update command history API calls
   - Add session metadata submission
   - Implement command execution analytics
   - Create error reporting integration

## Detailed File Changes

### 1. SSH Connection Manager (`lib/services/ssh_connection_manager.dart`)
```dart
// Key changes:
- Replace: final shell = await client.shell();
+ With: final shell = await client.shell(
+   pty: SSHPtyConfig(
+     width: terminalWidth,
+     height: terminalHeight,
+     term: 'xterm-256color',
+   ),
+ );

// Add welcome message separation:
+ bool _isWelcomeMessage = true;
+ Timer? _welcomeTimeout;

// Enhanced stream handling:
+ shell.stdout.transform(utf8.decoder).listen((data) {
+   if (_isWelcomeMessage && _welcomeTimeout == null) {
+     _welcomeTimeout = Timer(Duration(seconds: 2), () {
+       _isWelcomeMessage = false;
+     });
+   }
+   
+   if (_isWelcomeMessage) {
+     _handleWelcomeMessage(data);
+   } else {
+     _handleCommandOutput(data);
+   }
+ });
```

### 2. Terminal Block Widget (`lib/widgets/terminal/terminal_block.dart`)
```dart
class TerminalBlock extends StatefulWidget {
  final String command;
  final Stream<String> outputStream;
  final TerminalBlockStatus status;
  final DateTime timestamp;
  final VoidCallback? onRerun;
}

enum TerminalBlockStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}
```

### 3. Input Mode Service (`lib/services/terminal_input_mode_service.dart`)
```dart
enum TerminalInputMode { command, ai }

class TerminalInputModeService {
  TerminalInputMode _currentMode = TerminalInputMode.command;
  
  Future<void> toggleMode();
  Future<String?> processInput(String input);
  Stream<TerminalInputMode> get modeStream;
}
```

### 4. Enhanced Terminal Widget (`lib/widgets/terminal/ssh_terminal_widget.dart`)
```dart
// Replace xterm with custom block-based UI:
- TerminalView(_terminal, ...)
+ Column(
+   children: [
+     WelcomeMessageWidget(message: _welcomeMessage),
+     Expanded(
+       child: ListView.builder(
+         itemCount: _terminalBlocks.length,
+         itemBuilder: (context, index) => TerminalBlock(...),
+       ),
+     ),
+     InputModeController(
+       mode: _inputMode,
+       onModeToggle: _toggleInputMode,
+       onCommandSubmit: _submitCommand,
+     ),
+   ],
+ )
```

## Testing Strategy

### Unit Tests
- [ ] SSH connection manager PTY functionality
- [ ] Terminal block creation and management
- [ ] Input mode switching logic
- [ ] Command history integration
- [ ] Session state management

### Integration Tests
- [ ] End-to-end SSH connection flow
- [ ] Block-based terminal UI interactions
- [ ] AI command generation integration
- [ ] Command history API synchronization
- [ ] Interactive command handling (vi, nano, htop)

### Manual Testing
- [ ] SSH connection with various hosts
- [ ] Interactive command execution
- [ ] Mode switching behavior
- [ ] Welcome message display
- [ ] Command output separation
- [ ] Error handling scenarios

## Verification Plan

### Test Cases
- [ ] **SSH Connection**: Welcome message appears once after connection
- [ ] **Command Execution**: Each command creates a new block with proper input/output separation
- [ ] **Interactive Commands**: vi, nano, htop work properly with PTY support
- [ ] **Mode Switching**: Toggle between command and AI input modes
- [ ] **Command History**: Commands are saved with proper metadata
- [ ] **Error Handling**: Connection failures and command errors are handled gracefully
- [ ] **Session Management**: Multiple SSH sessions can run simultaneously

### Rollback Plan
If issues occur:
1. Revert SSH connection manager changes
2. Restore original xterm-based terminal widget
3. Disable block-based UI temporarily
4. Fall back to basic shell connection mode

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| PTY compatibility issues | High | Implement fallback to basic shell mode |
| Performance degradation | Medium | Optimize block rendering and stream handling |
| UI complexity breaking existing flows | Medium | Phased rollout with feature flags |
| Interactive command support | High | Extensive testing with common terminal apps |
| Session state synchronization | Medium | Implement robust error recovery |

## Dependencies

### External Libraries
- `dartssh2: ^2.9.0` - Already included, using enhanced PTY features
- `xterm: ^4.0.0` - May need updates for block-based rendering
- Riverpod state management for session handling

### Internal Dependencies
- AI command generation service
- Command history API endpoints
- Authentication service integration
- WebSocket fallback mechanism

## Performance Considerations

- **Memory Management**: Implement block history limits to prevent memory leaks
- **Stream Handling**: Use efficient stream controllers for PTY data
- **UI Rendering**: Optimize block list rendering for large command histories
- **Session Cleanup**: Proper resource disposal for SSH connections

## Security Considerations

- **PTY Security**: Ensure PTY sessions don't leak sensitive information
- **Command Logging**: Sanitize commands before saving to history
- **Session Isolation**: Prevent cross-session data leakage
- **Input Validation**: Validate and sanitize user commands

## Monitoring & Metrics

- **Connection Success Rate**: Track SSH connection reliability
- **Command Execution Time**: Monitor performance of interactive commands
- **Block Rendering Performance**: Measure UI responsiveness
- **Error Rates**: Track connection and command execution failures
- **User Engagement**: Monitor mode switching and feature usage

## Future Enhancements

- **Split Screen Support**: Multiple terminal sessions side-by-side
- **Command Suggestion**: Intelligent command completion
- **Session Replay**: Ability to replay command sessions
- **Advanced PTY Features**: Custom terminal emulation settings
- **Performance Analytics**: Real-time performance monitoring

## TODO Checklist

- [x] **Phase 1: SSH Session Management** ✅ **COMPLETED**
  - [x] Update SSH connection manager with PTY support
  - [x] Enhance terminal session handler
  - [x] Implement proper stream separation
  - [x] Add session state tracking

- [x] **Phase 2: Terminal UI** ✅ **COMPLETED**
  - [x] Create terminal block system
  - [x] Replace xterm with block-based UI
  - [x] Implement welcome message display
  - [x] Add command history blocks

- [x] **Phase 3: Input Mode System** ✅ **COMPLETED**
  - [x] Create input mode service
  - [x] Implement mode switching UI
  - [x] Integrate AI command generation
  - [x] Add keyboard shortcuts

- [x] **Phase 4: Integration & Testing** ✅ **COMPLETED**
  - [x] Update command history integration
  - [x] Enhance API client for session metadata
  - [x] Write comprehensive tests
  - [x] Perform integration testing

- [ ] **Phase 5: Polish & Deployment** ⚠️ **IN PROGRESS**
  - [x] Code review and optimization
  - [ ] Performance testing and tuning
  - [ ] Documentation updates
  - [ ] Staged deployment with monitoring

---

**Implementation Priority**: High - Critical user experience issues affecting core terminal functionality
**Estimated Timeline**: 5-7 days for full implementation and testing
**Success Metrics**: 
- Zero welcome message duplication
- Proper interactive command support
- Seamless mode switching
- Improved terminal responsiveness