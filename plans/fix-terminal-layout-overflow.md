# Fix Terminal Layout Overflow Issue

## Problem Description

RenderFlex overflowed by 101 pixels on the right in Row widget at `lib/widgets/terminal/ssh_terminal_widget.dart:644:14`. The Row contains too many fixed-width elements for the available 364px width constraint.

## Root Cause Analysis

The Row widget contains these elements (estimated widths):
- Status indicator: 12px circle + 8px spacing = 20px
- Connection text: Expanded (flexible)  
- Block UI elements (when enabled):
  - Mode badge: ~60px
  - Spacing: 8px  
  - Block count text: ~60px
  - Spacing: 8px
- Status text: Variable width (could be long)
- Toggle icon: 24px + spacing
- Options menu icon: 24px

Total fixed width: ~200px + variable text lengths = potential overflow

## Implementation Plan

### Phase 1: Immediate Fixes
- [ ] Wrap status text in Flexible widget to prevent overflow
- [ ] Add text overflow handling (ellipsis) for long connection strings
- [ ] Use intrinsic dimensions for mode badge text

### Phase 2: Responsive Layout
- [ ] Implement priority-based hiding for smaller screens
- [ ] Use SingleChildScrollView as fallback for very small screens
- [ ] Test on different screen sizes (320px, 375px, 414px widths)

### Phase 3: Optimization
- [ ] Consider using wrap or column layout for very constrained spaces
- [ ] Implement adaptive text sizing
- [ ] Add breakpoint-based responsive behavior

## Technical Solution

1. **Wrap status text in Flexible**:
   ```dart
   Flexible(
     child: Text(
       _status,
       overflow: TextOverflow.ellipsis,
       style: const TextStyle(...)
     ),
   )
   ```

2. **Add conditional visibility for block count on small screens**:
   ```dart
   if (_useBlockUI && MediaQuery.of(context).size.width > 400) ...[
     Text('${_terminalBlocks.length} blocks', ...)
   ]
   ```

3. **Use SingleChildScrollView as container if needed**:
   ```dart
   SingleChildScrollView(
     scrollDirection: Axis.horizontal,
     child: Row(...)
   )
   ```

## Success Criteria
- ✅ No RenderFlex overflow errors
- ✅ All UI elements visible and functional  
- ✅ Responsive design works on screen widths 320px-500px
- ✅ Text truncation handles long strings gracefully
- ✅ Terminal functionality remains unchanged

## Testing Plan
1. Test on iPhone SE (375px width)
2. Test on standard phones (414px width) 
3. Test with long connection strings
4. Test with both block and terminal modes
5. Verify all buttons remain functional