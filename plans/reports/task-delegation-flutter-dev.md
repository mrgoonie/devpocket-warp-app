# Task Delegation: SSH Host Navigation Black Screen Fix

**Date:** 2025-08-29  
**Delegated to:** flutter-mobile-dev  
**Priority:** P0 (Critical)  

## Task Summary
**Objective:** Fix the critical SSH host navigation black screen issue that blocks users from returning to host selection after connecting to an SSH host.

**Root Cause:** State management disconnect between `HostsListScreen` setting `currentSshProfileProvider` and `EnhancedTerminalScreen` only using `widget.initialProfile`.

## Implementation Plan Reference
Please follow the detailed plan at: `/Users/duynguyen/www/devpocket-warp-app/plans/20250829-ssh-host-navigation-fix-plan.md`

## Critical Changes Required

### Phase 1: Fix State Management (Critical)
**File:** `/Users/duynguyen/www/devpocket-warp-app/lib/screens/terminal/enhanced_terminal_screen.dart`

1. **Update initState() method (lines 32-36):**
   - Add provider state as fallback when `widget.initialProfile` is null
   - Add provider listener for real-time state updates
   - Sync local `_selectedProfile` with provider state

2. **Update _showConnectionSelector() method (lines 574-580):**
   - Clear provider state when clearing local state
   - Maintain state consistency between local and provider

3. **Add host selection synchronization:**
   - Sync provider when host is selected locally
   - Ensure bidirectional state consistency

### Phase 2: Navigation Consistency
- Update tab navigation to be aware of provider state
- Ensure smooth navigation flow without black screens

### Phase 3: Error Handling & Edge Cases
- Add comprehensive error handling
- Validate state consistency
- Handle connection failures gracefully
- Implement proper session cleanup

## Success Criteria
- ✅ User flow works: Terminal → SSH Host List → Click Host → Connected Terminal → "Select Host" → Back to Host List (no black screen)
- ✅ State management is consistent between screens  
- ✅ No breaking changes to existing SSH functionality
- ✅ Proper error handling for edge cases

## Key Files to Modify
1. `/lib/screens/terminal/enhanced_terminal_screen.dart` (Primary)
2. `/lib/screens/main/main_tab_screen.dart` (Secondary)
3. `/lib/screens/vaults/hosts_list_screen.dart` (Validation)

## Provider Reference
- **Provider:** `currentSshProfileProvider` (defined in `/lib/providers/ssh_host_providers.dart`)
- **Type:** `StateProvider<SshProfile?>`

## Testing Requirements
After implementation:
1. Manual testing of complete user flow
2. Test edge cases (connection failures, no hosts, etc.)
3. Verify no regression in existing SSH functionality
4. Test tab navigation consistency

## Expected Outcome
Complete elimination of the black screen issue with robust state management that prevents similar navigation problems in the future.

**CRITICAL:** This is a P0 issue that completely blocks users in the SSH workflow. The fix needs to be comprehensive and definitive.