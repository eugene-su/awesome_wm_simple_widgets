--[[

System volume widget for awesome wm.
'alsa-utils' is required.
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
    copy wvolume widget directory to ~/.config/awesome
    add to your rc.lua:
        ...
        -- System volume widget
        local wvolume = require("wvolume")
        local myvolume = wvolume()
        ...
    then inscribe 'myvolume.widget' to s.mywibox:
        ...
        mysystray,
        myvolume.widget,
        mytextclock
        ...
    adjust widget's variables and its code

--]]

local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local string = string
local setmetatable = setmetatable

------------ config variables ------------

local CHECKING_INTERVAL = 15
local CMD_VOLUME = "amixer get Master | grep 'Right:' |\
        awk -F'[][%]' '{ print $2 }'"
local CMD_MUTE = "amixer get Master | grep 'Right:' |\
        awk -F'[][]' '{ print $4 }'"
local ICON_ON = awful.util.getdir('config') ..
        'wvolume/volume_on.png'
local ICON_OFF = awful.util.getdir('config') ..
        'wvolume/volume_off.png'
local TEXT_COLOR = 'PaleGreen'

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
            image=icon_on,
            id='icon'
        },
        {
            widget=wibox.widget.separator,
            orientation='vertical',
            forced_width=5,
            opacity=0
        },
        {
            widget=wibox.widget.textbox,
            markup=nil,
            id='text'
        }
    }

    -- mouse buttons bindings
    self.widget:buttons(
        awful.util.table.join(
            awful.button(
                {}, 1,
                function()
                    awful.util.spawn('st -e alsamixer', false)
                end
            ),
            awful.button(
                {}, 2,
                function()
                    awful.util.spawn('amixer set Master toggle', false)
                    self:get()
                end
            ),
            awful.button(
                {}, 4,
                function()
                    awful.util.spawn('amixer set Master 5%+', false)
                    self:get()
                end
            ),
            awful.button(
                {}, 5,
                function()
                    awful.util.spawn('amixer set Master 5%-', false)
                    self:get()
                end
            )
        )
    )

    -- main timer
    gears.timer { timeout=CHECKING_INTERVAL,
                  call_now=true, 
                  autostart=true,
                  callback=function() self:get() end
    }

    return self
end

function WBody:get()
    awful.spawn.easy_async_with_shell(
        CMD_VOLUME,
        function(stdout)
            self:update_text(stdout)
            self.widget:emit_signal('widget::redraw_needed')
        end
    )
    awful.spawn.easy_async_with_shell(
        CMD_MUTE,
        function(stdout)
            self:update_icon(stdout)
        end
    )
end

function WBody:update_text(text)
    self.widget:get_children_by_id('text')[1].markup
            = string.format('<span color="%s">%s</span>', TEXT_COLOR, text)
end

function WBody:update_icon(text)
    local icon = ''
    local text = string.gsub(text, '\n', '')
    if text == 'on' then
        icon = ICON_ON
    else
        icon = ICON_OFF
    end
    self.widget:get_children_by_id('icon')[1].image = icon
end

return setmetatable(WBody, { __call=WBody.new })

