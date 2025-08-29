# Active Block Manager Refactoring Plan

## Overview

This plan outlines the refactoring of `active_block_manager.dart` (575 lines) to split it into focused components under 500 lines each, following the Single Responsibility Principle and the established pattern used throughout the codebase for service extraction.

## Current Analysis

### File Structure (575 lines total):
- **PtyConnection class** (lines 9-220, ~211 lines): PTY connection wrapper with process lifecycle management
- **ActiveBlockEvent classes** (lines 223-254, ~31 lines): Event models for active block changes  
- **ActiveBlockManager class** (lines 257-575, ~318 lines): Main service managing active terminal blocks

### Issues Identified:
1. **File Size**: Exceeds 500-line guideline (575 lines)
2. **Mixed Responsibilities**: Connection management, event handling, process control, and orchestration in one file
3. **Maintenance Complexity**: Large class with multiple concerns makes debugging and testing difficult
4. **Code Reusability**: PTY connection logic could be reused elsewhere

## Refactoring Strategy

### Target Architecture:
Split into 6 focused components following established patterns:

```
lib/services/
├── active_block_manager.dart              (~250 lines) - Core orchestration service
├── active_block_models.dart               (~80 lines)  - Event models and data structures
├── pty_connection_manager.dart            (~220 lines) - PTY connection wrapper and lifecycle
├── block_process_controller.dart          (~180 lines) - Process control and signal handling
├── block_focus_manager.dart               (~120 lines) - Focus management and input routing
└── block_statistics_service.dart          (~100 lines) - Statistics and utility functions
```

## Implementation Approach 1: Complete Extraction (Recommended)

### Advantages:
- **Clear Separation of Concerns**: Each component has a single, well-defined responsibility
- **Enhanced Testability**: Smaller, focused classes are easier to unit test
- **Improved Maintainability**: Changes to one aspect don't affect others
- **Better Code Reusability**: Components can be used independently
- **Follows Established Patterns**: Matches the extraction pattern used for SSH and terminal services

### Disadvantages:
- **More Files**: Increased file count (6 files vs 1)
- **Initial Complexity**: More imports and dependency injection needed
- **Refactoring Effort**: Significant initial work to extract and test

## Implementation Approach 2: Minimal Split

### Alternative Approach:
Split into 3 files only:
- `active_block_manager.dart` (~300 lines)
- `pty_connection.dart` (~220 lines) 
- `active_block_models.dart` (~80 lines)

### Trade-offs:
- **Pros**: Less file fragmentation, simpler refactoring
- **Cons**: Still violates single responsibility, harder to test and maintain

## Recommended Implementation Plan

### Phase 1: Extract Models and Data Structures

#### File: `lib/services/active_block_models.dart`
**Purpose**: Event models and data structures  
**Estimated Lines**: ~80

```dart
// Contents to extract:
- ActiveBlockEventType enum (lines 223-230)
- ActiveBlockEvent class (lines 232-254)
- Additional model classes for statistics and connection data
```

### Phase 2: Extract PTY Connection Management

#### File: `lib/services/pty_connection_manager.dart`
**Purpose**: PTY connection wrapper with process lifecycle management  
**Estimated Lines**: ~220

```dart
// Contents to extract:
- PtyConnection class (lines 9-220)
- Connection initialization and stream setup
- Process lifecycle management
- Stream subscription handling
- Resource disposal
```

### Phase 3: Extract Process Control Logic

#### File: `lib/services/block_process_controller.dart`
**Purpose**: Process control signals and termination handling  
**Estimated Lines**: ~180

```dart
// Contents to extract from ActiveBlockManager:
- Process signal handling (sendControlSignal, terminate)
- Process lifecycle events
- Command execution setup
- Process monitoring and health checks
```

### Phase 4: Extract Focus Management

#### File: `lib/services/block_focus_manager.dart`
**Purpose**: Block focus management and input routing  
**Estimated Lines**: ~120

```dart
// Contents to extract from ActiveBlockManager:
- Focus tracking (_focusedBlockId)
- Focus change events
- Input routing logic
- Focus validation and clearing
```

### Phase 5: Extract Statistics and Utilities

#### File: `lib/services/block_statistics_service.dart`
**Purpose**: Statistics collection and utility functions  
**Estimated Lines**: ~100

```dart
// Contents to extract from ActiveBlockManager:
- getStats() method
- Block counting and type distribution
- Session mapping utilities
- Cleanup utilities
```

### Phase 6: Refactor Core Manager

#### File: `lib/services/active_block_manager.dart` (Final)
**Purpose**: Core orchestration and public API  
**Estimated Lines**: ~250

```dart
// Remaining contents:
- Main service class with dependency injection
- Public API methods (activateBlock, terminateBlock)
- Event coordination
- Session management
- Integration with other extracted components
```

## Detailed Component Specifications

### 1. ActiveBlockModels (`active_block_models.dart`)

```dart
// Event types and data structures
enum ActiveBlockEventType { ... }

class ActiveBlockEvent { ... }

class BlockStatistics {
  final int totalActiveBlocks;
  final int runningBlocks;
  final String? focusedBlock;
  final Map<String, int> typeDistribution;
  final Map<String, String> sessionMappings;
}

class ConnectionMetadata {
  final String blockId;
  final DateTime createdAt;
  final Duration uptime;
  final bool isRunning;
  final ProcessInfo processInfo;
}
```

### 2. PtyConnectionManager (`pty_connection_manager.dart`)

```dart
class PtyConnectionManager {
  // PTY connection lifecycle
  Future<PtyConnection> createConnection({
    required String blockId,
    required String command,
    required ProcessInfo processInfo,
  });
  
  // Stream management
  void initializeStreams(PtyConnection connection);
  
  // Resource cleanup
  Future<void> disposeConnection(PtyConnection connection);
  
  // Connection health
  bool isConnectionHealthy(PtyConnection connection);
}

class PtyConnection {
  // Focused on connection state and streams
  // Process lifecycle tracking
  // Stream subscription management
}
```

### 3. BlockProcessController (`block_process_controller.dart`)

```dart
class BlockProcessController {
  // Process creation and startup
  Future<Process?> startProcess(String command, ProcessInfo processInfo);
  
  // Control signal handling
  bool sendControlSignal(PtyConnection connection, String signal);
  
  // Process termination
  Future<bool> terminateProcess(PtyConnection connection, {Duration? timeout});
  
  // Process monitoring
  void monitorProcessExit(PtyConnection connection);
}
```

### 4. BlockFocusManager (`block_focus_manager.dart`)

```dart
class BlockFocusManager {
  String? _focusedBlockId;
  final StreamController<ActiveBlockEvent> _eventController;
  
  // Focus management
  void focusBlock(String blockId);
  void clearFocus();
  String? get focusedBlockId;
  
  // Input routing
  bool routeInput(String blockId, String input);
  bool canAcceptInput(String blockId);
  
  // Focus events
  void emitFocusEvent(ActiveBlockEvent event);
}
```

### 5. BlockStatisticsService (`block_statistics_service.dart`)

```dart
class BlockStatisticsService {
  // Statistics collection
  BlockStatistics generateStats(Map<String, PtyConnection> activeBlocks);
  
  // Type distribution analysis
  Map<String, int> calculateTypeDistribution(List<PtyConnection> connections);
  
  // Session mapping utilities
  Map<String, String> getSessionMappings(Map<String, String> sessionBlocks);
  
  // Cleanup utilities
  List<String> findStaleConnections(Map<String, PtyConnection> activeBlocks);
}
```

### 6. ActiveBlockManager (`active_block_manager.dart`) - Refactored

```dart
class ActiveBlockManager {
  // Dependency injection
  final PtyConnectionManager _connectionManager;
  final BlockProcessController _processController;
  final BlockFocusManager _focusManager;
  final BlockStatisticsService _statisticsService;
  
  // Core orchestration
  Future<String?> activateBlock({...});
  Future<bool> terminateBlock(String blockId);
  
  // Public API
  bool sendInputToBlock(String blockId, String input);
  Stream<String>? getOutputStream(String blockId);
  bool isBlockActive(String blockId);
  
  // Session management
  Future<void> onNewCommandStarted(String sessionId, String newCommand);
  Future<void> cleanupAll();
}
```

## Migration Strategy

### Step 1: Create Model Files First
1. Create `active_block_models.dart` with extracted enums and classes
2. Update imports in `active_block_manager.dart`
3. Run tests to ensure no breaking changes

### Step 2: Extract PTY Connection Manager
1. Create `pty_connection_manager.dart` 
2. Move `PtyConnection` class with minimal changes
3. Update dependencies and imports
4. Run integration tests

### Step 3: Extract Supporting Services
1. Create remaining service files in dependency order
2. Extract methods and inject dependencies
3. Update main manager to use extracted services
4. Run comprehensive tests

### Step 4: Final Integration Testing
1. Run full test suite
2. Performance testing to ensure no regressions
3. Memory usage validation
4. Integration testing with terminal system

## Testing Strategy

### Unit Tests Required:
- **PtyConnectionManager**: Connection lifecycle, stream handling
- **BlockProcessController**: Process signals, termination logic
- **BlockFocusManager**: Focus tracking, input routing
- **BlockStatisticsService**: Statistics calculation, utilities
- **ActiveBlockManager**: Orchestration, public API

### Integration Tests:
- **Full workflow**: Block activation → focus → input → termination
- **Multi-session**: Multiple concurrent active blocks
- **Error scenarios**: Process failures, connection timeouts
- **Resource cleanup**: Memory leaks, resource disposal

## Risk Assessment

### Low Risk:
- **Model extraction**: Pure data classes with no logic
- **Statistics service**: Read-only utility functions
- **Testing**: Can be done incrementally

### Medium Risk:
- **PTY connection extraction**: Core functionality but well-isolated
- **Process controller**: Signal handling needs careful testing
- **Dependency injection**: Need to maintain singleton pattern

### High Risk:
- **Focus manager**: Critical for input routing
- **Main manager refactor**: Central orchestration logic
- **Stream management**: Potential for resource leaks

### Mitigation Strategies:
1. **Incremental approach**: Extract one component at a time
2. **Comprehensive testing**: Unit and integration tests for each component
3. **Backward compatibility**: Maintain existing public API
4. **Rollback plan**: Keep original file until testing complete

## Implementation Checklist

### Pre-Refactoring:
- [ ] Analyze current test coverage
- [ ] Document existing public API
- [ ] Identify all dependencies and callers
- [ ] Create comprehensive test suite for current behavior

### Extraction Phase:
- [ ] Extract `active_block_models.dart`
- [ ] Extract `pty_connection_manager.dart`
- [ ] Extract `block_process_controller.dart`
- [ ] Extract `block_focus_manager.dart`  
- [ ] Extract `block_statistics_service.dart`
- [ ] Refactor main `active_block_manager.dart`

### Post-Refactoring:
- [ ] Run full test suite
- [ ] Performance benchmarking
- [ ] Memory usage validation
- [ ] Integration testing
- [ ] Update documentation
- [ ] Code review and approval

## Success Criteria

### Functional Requirements:
- [ ] All existing functionality preserved
- [ ] No breaking changes to public API
- [ ] All tests pass
- [ ] No performance regression

### Code Quality Requirements:
- [ ] All files under 500 lines
- [ ] Clear separation of concerns
- [ ] Improved testability
- [ ] Better code organization
- [ ] Enhanced maintainability

### Documentation Requirements:
- [ ] Updated component documentation
- [ ] Clear dependency relationships
- [ ] Usage examples for new services
- [ ] Migration guide for other developers

## Future Benefits

### Maintainability:
- **Focused Changes**: Modifications to process control don't affect focus management
- **Easier Testing**: Smaller, focused classes are easier to test thoroughly
- **Better Debugging**: Issues can be isolated to specific components

### Extensibility:
- **Plugin Architecture**: Components can be swapped or extended independently
- **Reusability**: PTY connection logic can be used in other contexts
- **Feature Addition**: New functionality can be added without modifying core logic

### Performance:
- **Lazy Loading**: Components can be initialized only when needed
- **Memory Optimization**: Better resource management with focused cleanup
- **Concurrent Processing**: Independent components can be optimized separately

This refactoring plan follows established patterns in the codebase while significantly improving code organization, testability, and maintainability. The phased approach minimizes risk while delivering clear benefits for future development.