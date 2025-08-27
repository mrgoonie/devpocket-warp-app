# Terminal Screen Refactoring Implementation Assignment

**Date**: 2025-08-27  
**Agent**: flutter-mobile-dev  
**Task Type**: Major Feature Refactoring  
**Estimated Duration**: 4 days

## Assignment Summary
Implement comprehensive Terminal screen refactoring according to the detailed plan at `/Users/duynguyen/www/devpocket-warp-app/plans/20250827-terminal-screen-refactoring-plan.md`.

## Implementation Phases (Sequential Execution Required)

### Phase 1: Sync Component Migration
**Objective**: Move sync functionality from Vaults to Terminal screen
**Critical Files**: 
- `/lib/screens/terminal/enhanced_terminal_screen.dart`
- `/lib/widgets/ssh_sync_widgets.dart`

**Tasks**:
1. Import sync widget dependencies in enhanced_terminal_screen.dart
2. Integrate SyncStatusWidget in Terminal screen header
3. Add SyncControlsWidget and LastSyncTimeWidget to host selection view
4. Update Riverpod provider imports for sync state management
5. Test sync functionality in new Terminal location

### Phase 2: Vaults Screen Restructuring
**Objective**: Remove Hosts tab from Vaults screen (reduce from 3 to 2 tabs)
**Critical Files**:
- `/lib/screens/vaults/vaults_screen.dart`

**Tasks**:
1. Update TabController from 3 to 2 tabs
2. Remove Hosts tab definition (line 65)
3. Remove `_buildHostsTab()` method (lines 117-255)
4. Update TabBarView children array (lines 108-112)
5. Remove host-related import statements and unused methods

### Phase 3: Terminal Screen Enhancement
**Objective**: Enhance terminal screen with consolidated sync integration and improved UX
**Critical Files**:
- `/lib/screens/terminal/enhanced_terminal_screen.dart`

**Tasks**:
1. Remove `_buildLocalTerminalCard()` method (lines 154-222)
2. Update host selector to exclude local terminal option
3. Integrate sync status header in main Terminal view
4. Update AppBar logic: "Add Host" when empty, "Select Host" when hosts available
5. Add loading indicator during host connection process
6. Fix `_buildStatusBar()` icon logic for proper Terminal/Block view switching
7. Integrate welcome message as first fixed block in terminal widget

### Phase 4: Terminal View Switching Fix
**Objective**: Fix terminal view mode switching functionality
**Critical Files**:
- `/lib/widgets/terminal/ssh_terminal_widget.dart`

**Tasks**:
1. Fix icon display logic in `_buildStatusBar()` method (line 899)
2. Implement proper Terminal view (Termius-style) functionality
3. Ensure correct icon switching between Block/Terminal views
4. Test view mode transitions and functionality

### Phase 5: Enhanced Terminal Block Features
**Objective**: Improve terminal block functionality and command handling
**Critical Files**:
- `/lib/widgets/terminal/enhanced_terminal_block.dart`

**Tasks**:
1. Enhance command type detection (One shot, Continuous, Interactive)
2. Improve UI display for different command types
3. Add copy functionality for commands and output
4. Add clear functionality to wipe all terminal blocks
5. Integrate welcome message as non-scrollable first block

### Phase 6: Interactive Command Modal Fix
**Objective**: Fix fullscreen modal for interactive commands
**Critical Files**:
- Related terminal widget files handling interactive commands

**Tasks**:
1. Debug and fix fullscreen modal implementation for vi/vim/nano
2. Test interactive terminal functionality in fullscreen mode
3. Ensure proper modal cleanup and session handling

## Key Requirements
- Follow existing codebase patterns and architecture
- Use Riverpod for state management
- Maintain proper error handling and user feedback
- Ensure UI consistency with existing design system
- Test each phase thoroughly before proceeding to the next
- Report progress after each phase completion

## Success Criteria
- All 6 phases completed successfully
- No breaking changes to existing functionality
- Proper integration of sync components in Terminal screen
- Functional terminal view switching
- Working interactive command modals
- Clean code following project standards

## Context
- Implementation plan available at: `/Users/duynguyen/www/devpocket-warp-app/plans/20250827-terminal-screen-refactoring-plan.md`
- Report back with progress updates in `/plans/reports/` directory
- Use proper error handling and validation
- Follow security best practices