--[[

Backlight watchdog widget for awesome wm.
'xbacklight' and 'inotify-tools' are required.
Tested with Lua 5.3.5.
Copyright (c) 2019 Evgeny.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

usage:
    copy wbacklight widget directory to ~/.config/awesome
    add to your rc.lua:
        ...
        -- Backlight widget
        local wbacklight = require("wbacklight")
        local mybacklight = wbacklight()
        ...
    then inscribe 'mybacklight.widget' to s.mywibox:
        ...
        mysystray,
        mybacklight.widget,
        mytextclock
        ...
    adjust widget's variables and its code

--]]

local awful = require('awful')
local gears = require('gears')
local wibox = require('wibox')
local string = string
local tonumber = tonumber
local setmetatable = setmetatable

------------ config variables ------------

local CMD_GET = 'xbacklight -get'
local CMD_SET_LOW = 'xbacklight -set 1'
local CMD_SET_MID = 'xbacklight -set 40'
local CMD_INCREASE = 'xbacklight -inc 5'
local CMD_DECREASE = 'xbacklight -dec 5'
local WATCH_FILE
        = '/sys/class/backlight/intel_backlight/actual_brightness'
local CMD_WATCHDOG
        = 'inotifywait -mq -e modify ' .. WATCH_FILE
local ICON_PATH
        = gears.filesystem.get_dir('config') .. 'wbacklight/bulb.png'
local COLOR = 'PeachPuff'

------------------------------------------

local function watchdog(cls)
    awful.spawn.with_line_callback(
        CMD_WATCHDOG,
        {
            stdout = function(_)
                cls:get()
            end,
            exit = function(_, code)
                -- respawn, except SIGKILL
                if code == 9 then
                    do return end
                else
                    watchdog(cls)
                end
            end
        }
    )
end

local current = 0

-------------- widget body ---------------

local WBody = {}

function WBody:new()
    return setmetatable({}, { __index=self }):init()
end

function WBody:init()
    self.widget = wibox.widget {
        layout=wibox.layout.fixed.horizontal,
        {
            widget=wibox.widget.imagebox,
            image=ICON_PATH,
            id='icon'
        },
        {
            widget=wibox.widget.textbox,
            markup=nil,
            id='text'
        }
    }
    
    -- mouse buttons bindings
    self.widget:buttons(
        gears.table.join(
            awful.button(
                {}, 2, 
                function()
                    self:low_mid()
                end
            ),
            awful.button(
                {}, 4,
                function()
                    awful.spawn(CMD_INCREASE, false)
                end
            ),
            awful.button(
                { }, 5,
                function()
                    awful.spawn(CMD_DECREASE, false)
                end
            )
        )
    )

    self:get()
    watchdog(self)
    return self
end

function WBody:get()
    awful.spawn.easy_async_with_shell(
        CMD_GET,
        function(stdout)
            current = stdout
            self:update_text(current)
            self.widget:emit_signal('widget::redraw_needed')
        end
    )
end

function WBody:low_mid()
    if tonumber(current) > 1 then
       awful.spawn(CMD_SET_LOW, false)
    else
       awful.spawn(CMD_SET_MID, false)
    end
end

function WBody:update_text(text)
    self.widget:get_children_by_id('text')[1].markup
            = string.format('<span color="%s">%s</span>', COLOR, text)
end

return setmetatable(WBody, { __call=WBody.new, })

