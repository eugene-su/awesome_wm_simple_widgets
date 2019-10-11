# awesome_wm_simple_widgets
Very simple interactive widgets for awesome wm.
usage:
    copy wbacklight widget directory to ~/.config/awesome
    add to your rc.lua:
```lua
        ...
        -- Backlight widget
        local wbacklight = require("wbacklight")
        local mybacklight = wbacklight()
        ...
```
    then inscribe 'mybacklight.widget' to s.mywibox:
```lua
        ...
        mysystray,
        mybacklight.widget,
        mytextclock
        ...
```
    adjust widget's variables and its code
