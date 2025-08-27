/plan lot of issues still persist after the implementation, this is the original requests:
* [✅DONE] **In "Vaults" screen:** move the "Sync status, Quick stats header with sync controls" in the "Hosts" tab to "Terminal" screen, then delete the "Hosts" tab
* **In "Terminal" screen:**
  * [❌ NOT DONE] The first screen is "Select SSH Host" screen, so the "Select Host" icon on the AppBar should be hidden. Show the "Add Host" icon instead, click it to navigate to the "Add SSH Host" screen (`host_edit_screen.dart`).
  * [❌ NOT DONE] When the user connects to a host, the "Select Host" icon on the AppBar will be shown, click it to navigate back to the "Select SSH Host" screen (`Widget _buildHostSelector()` in `enhanced_terminal_screen.dart`).
  * [✅DONE] Delete `LocalTerminalCard`.
  * [❌ NOT DONE] Show loading indicator while connecting to the host.
  * [❌ NOT DONE] Welcome Message block (`ExpandableWelcomeWidget`): should be a part of the scrollable content of the Terminal blocks (`ssh_terminal_widget.dart`) as the first block. This welcome block's content should not be scrollable, expandable or collapsible. It should be fixed height and display the full content.
  * In `Widget _buildStatusBar()` (in `ssh_terminal_widget.dart`):
    * [❌ NOT DONE, layout issue] Click on "Switch to Terminal View" icon shows the Terminal view but empty and not working (unable to interact), this view should be full functional like the native terminal (similar to the terminal in [Termius](https://termius.com/) mobile app)
    * [✅DONE] When the user is in the Terminal view, the icon should be "Switch to Block View" (right now it's hidden).
  * The `EnhancedTerminalBlock`: 
    * [❌ NOT DONE, now it's gone] Display the command in a separate row because it could be long.
    * [❌ NOT DONE] The content view should use the font size, font family, and text color from the settings. It should NOT be scrollable, expandable or collapsible. It should be fixed height and display the full content.
    * [❌ NOT DONE] Detect the command type and display the status icon accordingly (Right now it's displaying "Running" icon only):
      * One shot: for example `ls`, `pwd`, `whoami`, etc.
      * Continuous: for example `top`, `htop`, `watch`, etc.
      * Interactive: for example `vi`, `vim`, `nano`, etc.
    * [❌ NOT DONE] The stop icon should be displayed when the command is running ("Continuous" command or "Interactive" command), click it to stop the command (simply kill the process like key combination `Ctrl+C`).
    * [❌ NOT DONE, just one icon to copy both command and output] Add copy icon to copy the command and the output to clipboard.
  * The `Interactive Command Fullscreen Modal`:
    * [❌ NOT DONE] This fullscreen terminal modal is currently not working
    * [❌ NOT DONE] This modal should allow the user to interact with the command as if they were using a terminal natively (for example, type content to `vi` or `vim` command).
  * Command input field (in `ssh_terminal_widget.dart`):
    * [❌ NOT DONE, it creates more duplicated blocks rather than wiping out all blocks] Clear icon: should wipe out all blocks in the Terminal blocks container.
  
=======

/cook Loading indicator when connecting to a host
## Current behavior
- Go to "Terminal" screen > List of SSH Host > Click on a host to connect > Show Terminal Block-based view > Status bar showing "Connecting..." and the "Terminal Ready" container below.
## Expected behavior
- Go to "Terminal" screen > List of SSH Host > Click on a host to connect > Show Terminal Block-based view > Status bar showing "Connecting..." and the spinning loading indicator in the center of "Terminal Ready" container below.

---

/cook Command display should be in a separate row in the Terminal blocks
## Current behavior
- After connecting to a host successfully > Submit a command to the input > a Terminal block added to the scroll view > In the header of the block, the command is displayed in the same row with the status and icons.
## Expected behavior
- After connecting to a host successfully > Submit a command to the input > a Terminal block added to the scroll view > In the header of the block, the command should be display as a separate row (right below the row of the status and icons)

---

/cook The Welcome Message block should be the first Terminal block in the scroll view.
## Current behavior
- After connecting to a host successfully > Welcome Message block is outside of the scroll view of the Terminal blocks and stay at the fixed position forever.
## Expected behavior
- After connecting to a host successfully > Welcome Message block should be added to the scroll view as the first Terminal block > The next Terminal blocks will be added right after that, so when we scroll the content of "Terminal blocks" view, we will see all Terminal blocks (including the Welcome Message block) go up and down.
## Screenshot: [image]

---

/cook Fix layout issue of the native Terminal view
## Current behavior
- After connecting to a host successfully > Click on "Switch to Terminal View" icon in the status bar > Show Terminal view > The layout of the Terminal view is broken with errors and unable to interac
<logs>
══╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═════════════════════════════════════════════════════════
The following assertion was thrown during layout:
A RenderFlex overflowed by 456 pixels on the bottom.

The relevant error-causing widget was:
  Column
  Column:file:///Users/duynguyen/www/devpocket-warp-app/lib/widgets/terminal/ssh_terminal_widget.dart:729:12

To inspect this widget in Flutter DevTools, visit:
http://127.0.0.1:9101/#/inspector?uri=http%3A%2F%2F127.0.0.1%3A62191%2Fh-AAtKXeYg0%3D%2F&inspectorRef=inspector-0

The overflowing RenderFlex has an orientation of Axis.vertical.
The edge of the RenderFlex that is overflowing has been marked in the rendering with a yellow and
black striped pattern. This is usually caused by the contents being too big for the RenderFlex.
Consider applying a flex factor (e.g. using an Expanded widget) to force the children of the
RenderFlex to fit within the available space instead of being sized to their natural size.
This is considered an error condition because it indicates that there is content that cannot be
seen. If the content is legitimately bigger than the available space, consider clipping it with a
ClipRect widget before putting it in the flex, or using a scrollable container rather than a Flex,
like a ListView.
The specific RenderFlex in question is: RenderFlex#4cfde relayoutBoundary=up3 OVERFLOWING:
  needs compositing
  creator: Column ← Expanded ← Column ← SshTerminalWidget ← Padding ← KeyedSubtree-[GlobalKey#fdcf5] ←
    _BodyBuilder ← MediaQuery ← LayoutId-[<_ScaffoldSlot.body>] ← CustomMultiChildLayout ←
    _ActionsScope ← Actions ← ⋯
  parentData: offset=Offset(0.0, 40.0); flex=1; fit=FlexFit.tight (can use size)
  constraints: BoxConstraints(0.0<=w<=398.0, h=590.0)
  size: Size(398.0, 590.0)
  direction: vertical
  mainAxisAlignment: start
  mainAxisSize: max
  crossAxisAlignment: center
  verticalDirection: down
  spacing: 0.0
◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤◢◤
════════════════════════════════════════════════════════════════════════════════════════════════════
</logs>
**Screenshot:** [image]

## Expected behavior
- After connecting to a host successfully > Click on "Switch to Terminal View" icon in the status bar > Show Terminal view > The layout of the Terminal view should display correctly and able to interact natively like a normal Terminal.

---

/cook Fix layout of the content in the Terminal blocks
## Current behavior
In the Block View mode > Each Terminal block (`EnhancedTerminalBlock`): 
- The content of the Terminal block is using incorrect font size & font family of the App Settings.
- The content view of each Terminal block is scrollable, expandable or collapsible.
## Expected behavior
- The content view of each Terminal block should use the font size, font family, and text color from the settings. 
- The content view of each Terminal block should NOT be scrollable, NOT be expandable or NOT be collapsible. 
- The content view of each Terminal block should be displayed in a fixed height enough to display the full content.

---

/cook Detect the command type and display the according status icon in each Terminal block
## Current behavior
- In each Terminal block (`EnhancedTerminalBlock`), the status icon is always "Running" icon.
## Expected behavior
- In each Terminal block (`EnhancedTerminalBlock`), the status icon should be displayed according to the command type:
  * One shot: for example `ls`, `pwd`, `whoami`, etc.
  * Continuous: for example `top`, `htop`, `watch`, etc.
  * Interactive: for example `vi`, `vim`, `nano`, etc.

---

/cook The "Clear Screen" icon in the command input component should wipe out all Terminal blocks in the scroll view
## Current behavior
- Click on the "Clear Screen" icon in the command input component > add a new Terminal block with a `clear` command.
## Expected behavior
- Click on the "Clear Screen" icon in the command input component > wipe out all Terminal blocks in the scroll view.

---

/cook Fix user interaction issue when showing `Interactive Command Fullscreen Modal`
## Current behavior
- Type an interactive command to the command input (eg. `vi hello.txt`) > Open `Interactive Command Fullscreen Modal` > The modal is not working and unable to interact, only show an error "Terminal Error: Local execution failed..."
## Expected behavior
- Type an interactive command to the command input (eg. `vi hello.txt`) > Open `Interactive Command Fullscreen Modal` > The modal should allow the user to interact with the command as if they were using a terminal natively (for example, type on the keyboard to input content to the file of `vi` or `vim` command).

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

