# Renders the demo inside the author's real Neovim config (theme, statusline,
# wind.nvim). Run from the repo root:
#   vhs demo/personal.tape
#
# The repo is copied to /tmp/quickdraw-demo first so wind.nvim's persistent
# breath store for the real project is never touched (stores are keyed by cwd).

Output demo/demo.gif
Output demo/demo.mp4

Set FontFamily "Maple Mono NF"
Set FontSize 20
Set Width 1400
Set Height 800
Set Padding 16
Set Framerate 20

Hide
Type "rm -rf /tmp/quickdraw-demo && cp -R . /tmp/quickdraw-demo && cd /tmp/quickdraw-demo && clear"
Enter
Type "nvim lua/quickdraw/init.lua"
Enter
Sleep 4s
# The demo is about one buffer; give it the whole frame. Delete to keep the tree.
Type ":Neotree close"
Enter
Sleep 500ms
# The /tmp copy and the installed plugin double-define every class, so the
# language server would sprinkle duplicate-field hints over the recording.
Type ":lua vim.diagnostic.enable(false)"
Enter
Type ":29"
Enter
Type "zz0"
Type ":echo ''"
Enter
Show

Sleep 2s

# Press f: the view dims and every reachable character is colored by its
# cost. Hold the census, then land on the first h.
Type "f"
Sleep 3s
Type "h"
Sleep 1.5s

# The trail stays lit; ; becomes a read decision.
Type ";"
Sleep 1s
Type ";"
Sleep 1.5s

# Backward works the same way.
Type "F"
Sleep 2.5s
Type "D"
Sleep 1.5s

# Operators span for free: delete through the first comma.
Type "kk0"
Sleep 1s
Type "df"
Sleep 2s
Type ","
Sleep 1.5s
Type "u"
Sleep 3s

Hide
Type ":qa!"
Enter
Type "rm -rf /tmp/quickdraw-demo ~/.local/share/nvim/wind/*quickdraw-demo*"
Enter
