--[[

Power watchdog widget for awesome wm.
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
    copy wpower widget directory to ~/.config/awesome
    add to your rc.lua:
        ...
        -- Power widget
        local wpower = require("wpower")
        local mypower = wpower()
        ...
    then inscribe 'mypower.widget' to s.mywibox:
        ...
        mysystray,
        mypower.widget,
        mytextclock
        ...
    adjust widget's variables and its code

--]]

local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local next = next
local math = math
local pairs = pairs
local ipairs = ipairs
local string = string
local tonumber = tonumber
local tostring = tostring
local setmetatable = setmetatable

------------ config variables ------------

local CHECKING_INTERVAL = 25
local ACCURACY = 8  -- number of checks for average consumption
local COLOR_FULL = 'GreenYellow'
local COLOR_MID = 'Gold'
local COLOR_LOW = 'Crimson'
local LOW_CHARGE_ALERT = 7
local ICON_BATTERY = awful.util.getdir('config')
        .. 'wpower/battery.png'
local ICON_PLUG = awful.util.getdir('config')
        .. 'wpower/plug.png'
local CMD_POWER_MANAGER = 'st vim /etc/default/tlp'
local AC_PREFIX = '/sys/class/power_supply/ACAD/'
local BATTERY_PREFIX = '/sys/class/power_supply/BAT1/'
local BTMOUSE_PREFIX
        = '/sys/class/power_supply/hid-6c:5d:63:2b:98:03-battery/'

------------------------------------------

local average = 0
local consumption = {}
local values = {}
local parameters = { 'capacity',
                     'charge_full',  -- energy_full
                     'charge_full_design',  -- energy_full_design
                     'charge_now',  -- energy_now
                     'current_now',  -- power_now
                     'voltage_now'
}

-- bluetooth mouse
local btmouse_values = {}
local btmouse_parameters = {
    'capacity',
    'model_name'
}

local function collect(prefix, parameters, export_list)
    for _, param in pairs(parameters) do
        awful.spawn.easy_async_with_shell(
            'cat ' .. prefix .. param,
            function(stdout)
                local output = string.gsub(stdout, '\n', '')
                export_list[param] = output
            end
        )
    end
end

local function achtung(plug, percent)
    local percent = tonumber(percent)
    if plug == '0' and percent < LOW_CHARGE_ALERT then
        naughty.notify { title='Критический остаток заряда!',
                         text='Подключите устройство к сети 220В.',
                         preset=naughty.config.presets.critical,
                         icon=ICON_PLUG,
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
            image=ICON_BATTERY,
            id='icon'
        },
        { 
            widget=wibox.widget.textbox,
            markup='',
            id='text'
        }
    }

    self.tooltip = awful.tooltip { objects={ self.widget },
                                   border_color='#ebcb8b',
                                   border_width=1,
                                   bg='#2e3440',
                                   markup='Проверьте префиксы!'
    }

    -- mouse buttons bindings
    self.widget:buttons(
        awful.util.table.join(
            awful.button(
                {}, 1,
                function() awful.util.spawn(CMD_POWER_MANAGER, false) end
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
    collect(BATTERY_PREFIX, parameters, values)
    collect(AC_PREFIX, { 'online' }, values)
    collect(BTMOUSE_PREFIX, btmouse_parameters, btmouse_values)

    if next(values) == nil
            or #values['capacity'] == 0 then
        do return end
    end

    -- average consumption
    if next(consumption) == nil then
        for i=1, ACCURACY do
            consumption[i] = values['current_now']
        end
    end
    consumption[math.random(1, ACCURACY)]
            = values['current_now']
    average = 0
    for _, value in ipairs(consumption) do
        average = average + value
    end
    average = math.floor(average / ACCURACY + 0.5)

    -- estimated battery life
    local h, m = math.modf(
        values['charge_now'] / average
    )
    values['discharge_h'] = h
    values['discharge_m'] = math.floor(m * 60)

    -- estimated time till full charge
    h, m = math.modf(
        (values['charge_full'] - values['charge_now']) / average
    )
    values['charge_h'] = h
    values['charge_m'] = math.floor(m * 60)

    values['deterioration'] = math.floor(
        values['charge_full']
        / values['charge_full_design'] * 100
        + 0.5
    )

    self:update_text()
    self:update_icon()
    self.widget:emit_signal('widget::redraw_needed')
    self:update_tooltip()
    achtung(values['online'], values['capacity'])
end

function WBody:update_text()
    local color = ''
    local capacity = tonumber(values['capacity'])

    if capacity > 70 then
        color = COLOR_FULL
    elseif capacity < 30 then
        color = COLOR_LOW
    else
        color = COLOR_MID
    end

    self.widget:get_children_by_id('text')[1].markup
            = string.format('<span color="%s">%s</span>', color, capacity)
end

function WBody:update_icon()
    local icon = ''
    if values['online'] == '1' then
        icon = ICON_PLUG
    else
        icon = ICON_BATTERY
    end
    self.widget:get_children_by_id('icon')[1].image = icon
end

function WBody:update_tooltip()
    local average = tostring(
        string.format('%.2f', average/100000)
    )
    
    local voltage = tostring(
        string.format('%.2f', values['voltage_now']/1000000)
    )

    local charge_state = ''
    if values['online'] == '1' then
        charge_state = string.format(
            '\nДо завершения зарядки\t%s ч. %s м.',
            values['charge_h'],
            values['charge_m']
        )
    else
        charge_state = string.format(
            '\nЗапас работы\t\t%s ч. %s м.',
            values['discharge_h'],
            values['discharge_m']
        )
    end
    
    local text =
    'Текущий уровень\t\t' .. values['capacity'] .. ' %'
    .. charge_state
    .. '\nИзнос батареи\t\t' .. values['deterioration'] .. ' %'
    .. '\nНапряжение\t\t' .. voltage .. ' В'
    .. '\nСреднее потребление\t' .. average .. ' Вт⋅ч'

    -- bluetooth mouse
    if next(btmouse_values) ~= nil
            and #btmouse_values['capacity'] ~= 0 then
        text = text
                .. '\n\n' .. btmouse_values['model_name']
                .. '\nЗаряд устройства\t'
                        .. btmouse_values['capacity'] .. ' %'
    end

    self.tooltip.markup = text
end

return setmetatable(WBody, { __call=WBody.new, })

