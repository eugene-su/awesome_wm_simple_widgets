# awesome_wm_simple_widgets
Very simple interactive widgets for awesome wm.  
`Usage:  
    Copy desired widget directory to ~/.config/awesome  
    Add to your rc.lua:  
```lua
        ...
        -- Short tip about the widget
        local %widgetname% = require("%widgetname%")
        local my%widgetname% = %widgetname%()
        ...
```
    Then inscribe 'my%widgetname%.widget' to s.mywibox:  
```lua
        ...
        mysystray,
        my%widgetname%.widget,
        mytextclock
        ...
```
    Adjust widget's variables and its code.
`
