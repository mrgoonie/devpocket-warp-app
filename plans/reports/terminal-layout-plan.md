# Terminal Block Layout Modification Plan

## Task Summary
- **Objective**: Modify terminal block layout to display commands in a separate row below the status and icons row
- **Scope**: Update EnhancedTerminalBlock component header structure
- **Critical Context**: Improve readability for long commands and create cleaner visual hierarchy
- **Success Criteria**: Status/icons in top row, command in dedicated row below with preserved functionality

## Implementation Steps

### Phase 1: Analysis
1. Examine current terminal block implementation in `lib/widgets/terminal/`
2. Identify header layout structure and component organization
3. Document current styling and functionality

### Phase 2: Layout Restructuring  
1. Convert header from Row to Column with two rows
2. First row: Status text and action icons
3. Second row: Command text with appropriate styling
4. Maintain proper spacing and alignment

### Phase 3: Styling Implementation
1. Apply distinct styling for command text
2. Add appropriate vertical spacing between rows
3. Handle long commands gracefully (truncation/wrapping)
4. Ensure responsive design

### Phase 4: Testing & Validation
1. Test layout on different screen sizes
2. Verify all existing functionality preserved
3. Check visual consistency with design guidelines

## Expected Layout Structure
```
┌─────────────────────────────────────┐
│ [Status] [Expand] [Menu] [Copy]     │ ← Row 1: Status & Icons
│ $ ls -la /home/user/documents       │ ← Row 2: Command
├─────────────────────────────────────┤
│ [Terminal Output Content]           │
└─────────────────────────────────────┘
```

## Key Files to Modify
- `lib/widgets/terminal/enhanced_terminal_block.dart`
- Any related header widget components

## Risk Assessment
- Low risk: Layout change only, no functional modifications
- Potential responsive design considerations
- Styling consistency maintenance required