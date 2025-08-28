# SSH Loading Indicator Implementation Delegation

**Date**: 2025-08-27  
**From**: Project Manager  
**To**: Flutter Mobile Developer  
**Type**: Feature Implementation  

## Task Summary
Implement a loading indicator in the SSH terminal widget to improve user experience during connection establishment.

## Implementation Plan Reference
- **Plan File**: `/Users/duynguyen/www/devpocket-warp-app/plans/20250127-ssh-loading-indicator-plan.md`
- **Status**: Ready for implementation - all phases planned

## Current State Analysis
The `SshTerminalWidget` already has:
- ✅ Connection status tracking via `_status` field
- ✅ Connection states: "Initializing...", "Connecting...", "Authenticating...", etc.
- ✅ Empty blocks state UI in `_buildEmptyBlocksState()` method (lines 782-812)
- ✅ Status bar showing connection status (lines 851-952)

## Required Implementation
Based on the existing plan, implement these specific changes:

### 1. Add Connection State Detection
Add this getter to detect when terminal is connecting:
```dart
bool get _isConnecting {
  return _status == 'Connecting...' || 
         _status == 'Authenticating...' ||
         _status == 'Starting local terminal...' ||
         _status == 'Connecting to ${widget.profile?.connectionString}...' ||
         _status == 'Reconnecting...' ||
         _status == 'Initializing...';
}
```

### 2. Update _buildEmptyBlocksState Method
Replace the current static "Terminal Ready" UI (lines 782-812) with conditional rendering:
- **When Connecting**: Show `CircularProgressIndicator` with connection status text
- **When Idle**: Show existing "Terminal Ready" UI with terminal icon

### 3. Expected UI Behavior
- Loading spinner appears centered during connection states
- Shows actual connection status text from `_status` field
- Smooth transition to "Terminal Ready" when not connecting
- Consistent with app's neobrutalism design theme using `AppTheme` colors

## Key Files to Modify
- **Primary**: `/Users/duynguyen/www/devpocket-warp-app/lib/widgets/terminal/ssh_terminal_widget.dart`
  - Lines 782-812: `_buildEmptyBlocksState()` method

## Success Criteria
- ✅ Loading spinner appears when connecting to SSH hosts
- ✅ Different connection states show appropriate loading messages
- ✅ Smooth transition from loading to connected state
- ✅ Visual consistency with app theme (AppTheme colors)
- ✅ Works across different connection scenarios (SSH, local, reconnect)

## Technical Context
- The widget already handles all connection states properly
- Status updates happen via SSH connection events and are reflected in `_status`
- The UI framework is already in place, just needs conditional rendering logic
- All required theme colors and styling constants are available in `AppTheme`

## Next Steps
1. Implement the `_isConnecting` getter
2. Update `_buildEmptyBlocksState()` with conditional rendering
3. Test with SSH connections, local terminal, and reconnection scenarios
4. Ensure smooth state transitions and proper styling

The implementation should be straightforward as all the infrastructure is already in place - this is primarily a UI enhancement to provide better user feedback during connection establishment.