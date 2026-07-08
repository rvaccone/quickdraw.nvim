# Renders the README demo without a human at the keyboard.
# Requires vhs (brew install vhs). Run from the repo root:
#   vhs demo/quickdraw.tape

Output demo/demo.gif
Output demo/demo.mp4

Set FontFamily "Maple Mono NF"
Set FontSize 20
Set Width 1400
Set Height 800
Set Padding 16
Set Framerate 20

Hide
Type "nvim -u demo/init.lua -i NONE lua/quickdraw/init.lua"
Enter
Sleep 2.5s
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
