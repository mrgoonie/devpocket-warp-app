---
description: Run test flows and fix issues
---

## Reported Issues:
<issue>
 $ARGUMENTS
</issue>

## Workflow:
1. First use `tester` subagent to run the tests.
2. Then use `debugger` subagent to find the root cause of the issues.
3. Then use `flutter-mobile-dev` subagent to analyze the reports and implement the fix. Repeat this process until all issues are addressed.
4. After finishing, delegate to `code-reviewer` agent to review code.