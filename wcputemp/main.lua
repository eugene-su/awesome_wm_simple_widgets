--[[

CPU temperature watchdog widget for awesome wm.
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
    copy wcputemp widget directory to ~/.config/awesome
    add to your rc.lua:
        ...
        -- CPU temperature widget
        local wcputemp = require("wcputemp")
        local mycputemp = wcputemp()
        ...
    then inscribe 'mycputemp.widget' to s.mywibox:
        ...
        mysystray,
        mycputemp.widget,
        mytextclock
        ...
    adjust widget's variables and its code

--]]

local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local naughty = require('naughty')
local math = math
local string = string
local tostring = tostring
local setmetatable = setmetatable

------------ config variables ------------

local TEMP_HOT = 80
local TEMP_MID = 65
local TEMP_COOL = 50
local COLOR_HOT = 'Red'
local COLOR_MID = 'Khaki'
local COLOR_COOL = 'LightSteelBlue'
local CHECKING_INTERVAL = 18
local ICON_TEMP = awful.util.getdir('config') .. 'wcputemp/iron.png'
local CMD_INFO = 'st -e acpi -V'
local SOURCE = '/sys/class/thermal/thermal_zone5/temp'

------------------------------------------

local current_temp = ''

local function achtung()
    if current_temp > TEMP_HOT then
        naughty.notify { title='Внимание!',
                         text='Температура процессора критическая!',
                         preset=naughty.config.presets.critical,
                         icon=ICON_TEMP,
                         icon_size=50,
                         timeout=10
        }
    end
end

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
            image=ICON_TEMP,
            id='icon'
        },
        {
            widget = wibox.widget.separator,
            orientation = 'vertical',
            forced_width = 2,
            opacity = 0
        },
        { 
            widget=wibox.widget.textbox,
            markup='',
            id='text'
        },
        {
            widget = wibox.widget.separator,
            orientation = 'vertical',
            forced_width = 5,
            opacity = 0
        },

    }

    -- mouse buttons bindings
    self.widget:buttons(
        awful.util.table.join(
            awful.button(
                {}, 1,
                function() awful.util.spawn(CMD_INFO, false) end
            ),
            awful.button({}, 2, function() self:get() end),
            awful.button({}, 3, function() self:get() end)
        )
    )

    gears.timer { timeout=1,
                  autostart=true,
                  call_now=true,
                  single_shot=true,
                  callback=function() self:get() end
    }

    -- main timer
    gears.timer { timeout=CHECKING_INTERVAL,
                  autostart=true,
                  callback=function() self:get() end
    }

    return self
end

function WBody:get()
    awful.spawn.easy_async_with_shell(
            'cat ' .. SOURCE,
            function(stdout)
                current_temp = string.gsub(stdout, '\n', '')
                current_temp = math.modf(current_temp / 1000)
            end
        )

    if current_temp == nil or current_temp == '' then
        do return end
    end

    self:update_text()
    self.widget:emit_signal('widget::redraw_needed')
    achtung()
end

function WBody:update_text()
    local color = ''

    if current_temp <= TEMP_COOL then
        color = COLOR_COOL
    elseif current_temp > TEMP_COOL and current_temp <= TEMP_MID then
        color = COLOR_MID
    else
        color = COLOR_HOT
    end

    self.widget:get_children_by_id('text')[1].markup
            = string.format(
                  '<span color="%s">%s</span>',
                  color,
                  tostring(current_temp)
              )
end

return setmetatable(WBody, { __call=WBody.new, })

