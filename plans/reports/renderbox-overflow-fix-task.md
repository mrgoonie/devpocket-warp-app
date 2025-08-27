# RenderFlex Overflow Fix Task

## Task Summary
**Objective**: Fix the RenderFlex overflow issue causing 456-pixel bottom overflow in native terminal view
**Scope**: `lib/widgets/terminal/ssh_terminal_widget.dart` at line 729 in `_buildXtermFallbackContent()` method
**Critical Context**: 
- Error occurs when switching from block UI to native terminal view
- Column widget not properly constrained, causing content overflow
- Current implementation already wrapped in Expanded widget but internal Column isn't using proper flex constraints

## Current Issue Analysis
**Root Cause**: The `_buildXtermFallbackContent()` method returns a Column widget that's not using proper flex constraints
**Error Location**: Line 729 in `ssh_terminal_widget.dart`
**Current Structure**:
```dart
Widget _buildXtermFallbackContent() {
  return Column(  // <-- This Column causes overflow
    children: [
      // Welcome message container (fixed height)
      if (_welcomeMessage.isNotEmpty) Container(...),
      // Terminal view (should be flexible)
      Expanded(child: Container(child: TerminalView(...))),
    ],
  );
}
```

## Technical Requirements
1. **Fix Column Constraints**: Ensure Column uses proper mainAxisSize
2. **Validate Layout Behavior**: Test with different screen sizes and orientations  
3. **Ensure Terminal Interaction**: Verify TerminalView receives proper constraints
4. **Test Welcome Message Display**: Ensure conditional welcome message doesn't cause issues

## Success Criteria
- [ ] No RenderFlex overflow errors in Flutter DevTools
- [ ] Native terminal view displays correctly on all screen sizes
- [ ] Terminal interaction (typing, scrolling) works properly
- [ ] Welcome message displays correctly when present
- [ ] Layout adapts properly to orientation changes

## Reference Files
- Primary: `/lib/widgets/terminal/ssh_terminal_widget.dart` (lines 728-777)
- Related: Main build method (lines around 800-850)
- Implementation Plan: `/plans/20250127-terminal-comprehensive-fixes-plan.md` (Phase 2, Task 4)

## Expected Implementation
The fix should involve setting `mainAxisSize: MainAxisSize.min` on the Column widget or restructuring the layout to use proper flex constraints without causing overflow.