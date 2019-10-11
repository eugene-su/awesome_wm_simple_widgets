# awesome_wm_simple_widgets
Very simple interactive widgets for awesome wm.

Usage:

Copy wbacklight widget directory to ~/.config/awesome
Add to your rc.lua:
```lua
        ...
        -- Backlight widget
        local wbacklight = require("wbacklight")
        local mybacklight = wbacklight()
        ...
```
Then inscribe 'mybacklight.widget' to s.mywibox:
```lua
        ...
        mysystray,
        mybacklight.widget,
        mytextclock
        ...
```
Adjust widget's variables and its code.
