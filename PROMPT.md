# [IN_PROGRESS] Fix typing issue in `vi` editor of the Terminal View mode in the Terminal screen

## Current behavior
- Go to "Terminal" screen > List of SSH Host > Click on a host to connect > Tapping on "Switch to Terminal View" icon in the status bar > Show Terminal View > see a blank Terminal view > type `vi hello.txt` > tap on "Return" > `vi` open and we can start writing in the file content > but the layout look weird (probably because of the resize)
- **Screenshot:** 

## Expected behavior
- Go to "Terminal" screen > List of SSH Host > Click on a host to connect > Tapping on "Switch to Terminal View" icon in the status bar > Show Terminal View > see a host's welcome message > type `vi hello.txt` > tap on "Return" > `vi` open and we can start writing in the file content > the layout look normal

---

# [IN_PROGRESS] Fix sync issue of the Terminal View mode and Block UI mode

## Current behavior
- Go to "Terminal" screen -> List of SSH Host -> Click on a host to connect -> Host's connected -> See the Block UI mode by default and the host's welcome message -> Type `ls` -> tap on "Return" -> See the block of `ls` output added -> Tapping on "Switch to Terminal View" icon in the status bar -> Show Terminal View -> see a blank Terminal view -> type `cat hello.txt` -> see the content of `hello.txt` -> Tapping on "Switch to Block UI" icon in the status bar -> See the welcome block and `ls` block.

## Expected behavior
- Go to "Terminal" screen -> List of SSH Host -> Click on a host to connect -> Host's connected -> See the Block UI mode by default and the host's welcome message -> Type `ls` -> tap on "Return" -> See the block of `ls` output added -> Tapping on "Switch to Terminal View" icon in the status bar -> Show Terminal View -> Should see welcome message and the `ls` command with output -> type `cat hello.txt` -> see the content of `hello.txt` -> Tapping on "Switch to Block UI" icon in the status bar -> See the host's welcome block, `ls` block, `cat hello.txt` block.

> Safely comment out the code to disable command sync between Block UI mode and Terminal View mode because it didn't work as expected.

---

# [IN_PROGRESS] Fix the font issue of the Block UI mode

## Current behavior
- The output content of the block is not displayed properly, it contains some rectangular symbols and special characters. 
- This issue doesn't exist in the Terminal View mode.
- **Screenshot:** '/Users/duynguyen/Pictures/Screenshots/CleanShot 2025-08-29 at 14.09.54.png'

## Expected behavior
- The output content of the block should be displayed properly.

---

# [IN_PROGRESS] Analyze and provide a plan to clean up the codebase

Think hard.

## Objectives
- Extract into smaller components to make the codebase more maintainable and better context engineering.
- Try to keep the code file length under 500 lines.
- There are many unused code due to many reasons, such as old versions, old features, old UI, etc.
- Provide a plan to clean up the codebase by removing unused code.
- **IMPORTANT:** Make sure the plan is safe and doesn't break any existing functionality.


---

# Fix the "Executing command" issue when switching from Block UI mode to Terminal View mode frequently

## Current behavior
- Go to "Terminal" screen -> List of SSH Host -> Click on a host to connect -> Host's connected -> See the Block UI mode by default -> Type `ls` -> tap on "Return" -> See the block of `ls` output added -> Tap on "Switch to Terminal View" icon in the status bar -> Tap on "Switch to Block UI" icon in the status bar -> Repeat tapping a few times -> See the "Executing command..." message with a loading indicator in the `ls` block.
- **Screenshot:** '/Users/duynguyen/Pictures/Screenshots/CleanShot 2025-08-29 at 14.17.15.png'

## Expected behavior
- The "Executing command..." message with a loading indicator should not be displayed when switching between Block UI mode and Terminal View mode constantly.

---

# Fix the scroll to top issue of the Block UI mode when switching from Terminal View mode to Block UI mode

## Current behavior
- Go to "Terminal" screen -> List of SSH Host -> Click on a host to connect -> Host's connected -> See the Block UI mode by default -> Type `ls` -> tap on "Return" -> the block ui scrolled to the bottom -> See the block of `ls` output added -> Tap on "Switch to Terminal View" icon in the status bar -> Tap again on that icon ("Switch to Block UI") in the status bar -> See the Block UI view but it's scrolled to the top.

## Expected behavior
- The Block UI view should be scrolled to the bottom when switching from Terminal View mode to Block UI mode.

---

[DONE] In `ssh_terminal_widget.dart`: 
- Improve the AI mode of the input field by adding a loading indicator while the OpenRouter API is processing.
- Move the mode toggle button to the "Control keys and shortcuts" section.
- Change to input field to multiline mode.

---

# Improve natural language to command conversion
Related file: `openrouter_ai_service.dart`
## Current behavior
- The output command is not good because the current prompt is not context awareness.
## Expected behavior
- The prompt should be context awareness, there should have functions for AI agent to send commands to the host's shell to collect relevant information to improve the prompt. For example: current directory, list of files in the directory, last 50 commands, system information, etc.

---

/cook 
## Current behavior
## Expected behavior


=======

/plan:two 
<logs>
</logs>

=======

/cook 
* 
* 

=======

/fix:fast
<logs>
</logs>

=======

/fix:hard 
* 1
  <logs>
  </logs>
* 2

=======

/fix:test 

=======

