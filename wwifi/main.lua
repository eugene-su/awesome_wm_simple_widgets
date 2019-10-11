--[[

Wifi watchdog widget for awesome wm.
'connman' is required.
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

--]]

local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local string = string
local setmetatable = setmetatable

------------ config variables ------------

local CHECKING_INTERVAL = 20
local CMD_IP = 'wget --timeout=5 -O - -q icanhazip.com'
local CMD_AP = "connmanctl services | grep '*' | awk '{print $3}'"
local CMD_CONNMAN = 'st connmanctl'
local ICON_ON = awful.util.getdir('config')
        .. 'wwifi/connected.png'
local ICON_BAD = awful.util.getdir('config')
        .. 'wwifi/bad_connection.png'
local ICON_OFF = awful.util.getdir('config')
        ..  'wwifi/no_connection.png'
local TEXT_COLOR = 'Aquamarine'
local DEFAULT_TIP = 'Нет информации о подключении'

------------------------------------------

function connman_parser(text)
  local wifi_parameters = {}
  for line in text:gmatch('([^\r\n]+)') do
    if not string.match(line, '%[%s*%]')
        and string.match(line, '=') then
      if not string.match(line, '%[') then
        key, value = string.match(line, '([%w%.]+) = (.+)')
        wifi_parameters[key] = value
      else
        local nested_list = {}
        key, list = string.match(
            line, '([%w%.]+) = %[ (.+) %]')
        if string.match(line, '^[^=]*=[^=]*$') then
          for no_key in string.gmatch(list, '([%w%.]+)') do
              table.insert(nested_list, no_key)
          end
        else
          for nested_key, nested_value in string.gmatch(
              list, '%s?([^,]+)=([^,]+)') do
            nested_list[nested_key] = nested_value
          end
        end
        wifi_parameters[key] = nested_list
      end
    end
  end
  return wifi_parameters
end

local ip = ''
local access_point = ''
local wifi_parameters = {}

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
    self.tooltip = awful.tooltip { objects={ self.widget },
                                   border_color='#ebcb8b',
                                   border_width=1,
                                   bg='#2e3440',
                                   markup=DEFAULT_TIP
    }

    -- mouse buttons bindings
    self.widget:buttons(
        awful.util.table.join(
            awful.button(
                {}, 1,
                function() awful.util.spawn(CMD_CONNMAN, false) end
            ),
            awful.button({}, 2, function() self:get(); self:get_ip() end),
            awful.button({}, 3, function() self:get(); self:get_ip() end)
        )
    )

    -- main timer
    gears.timer { timeout=CHECKING_INTERVAL,
                  autostart=true,
                  callback=function() self:get() end
    }

    self:get()
    self:get_ip()
    return self
end

function WBody:get()
    awful.spawn.easy_async_with_shell(
        CMD_AP,
        function(stdout)
            access_point = string.gsub(stdout, '\n', '')
            if #access_point == 0 then
                self:update_icon('idle')
                self.tooltip.markup = DEFAULT_TIP
                do return end
            end

            awful.spawn.easy_async_with_shell(
                    'connmanctl services ' .. access_point,
                function(stdout)
                    wifi_parameters = connman_parser(stdout)
                    self:update_text(wifi_parameters['Strength'])
                    self:update_icon(wifi_parameters['State'])
                    self.widget:emit_signal('widget::redraw_needed')
                    self:update_tooltip()
                end
            )
        end
    )
end

function WBody:get_ip()
    awful.spawn.easy_async_with_shell(
        CMD_IP,
        function(stdout)
            ip = string.gsub(stdout, '\n', '')
        end
    )
end

function WBody:update_text(text)
    self.widget:get_children_by_id('text')[1].markup
            = string.format('<span color="%s">%s</span>', TEXT_COLOR, text)
end

function WBody:update_icon(text)
    local icon = ''
    if text == 'online' then
        icon = ICON_ON
    elseif text == 'ready' then
        icon = ICON_BAD
    else
        icon = ICON_OFF
    end
    self.widget:get_children_by_id('icon')[1].image = icon 
end

function WBody:update_tooltip()
    if wifi_parameters['State'] == 'idle' then
        self.tooltip.markup = DEFAULT_TIP
        do return end
    end

    local text =
    'Сила сигнала:\t\t' .. wifi_parameters['Strength']
    .. '\nSSID точки доступа:\t<span color="GreenYellow"><b>'
    ..  wifi_parameters['Name'] .. '</b></span>'
    ..  '\nСостояние подключения:\t' .. wifi_parameters['State']
    .. '\nПолученный от ТД IPv4:\t' .. wifi_parameters['IPv4']['Address']
    .. '\nТип шифрования ключа:\t' .. wifi_parameters['Security'][1]
    .. '\nАвтоподключение:\t' .. wifi_parameters['AutoConnect']
    .. '\nMac-адрес ТД:\t\t' .. wifi_parameters['IPv4']['Address']
    .. '\nGateway:\t\t' .. wifi_parameters['IPv4']['Gateway']
    .. '\nDNS ТД:\t\t\t' .. wifi_parameters['Nameservers'][1]
    .. '\n\t\t\t' .. wifi_parameters['Nameservers'][2]

    if ip ~= '' and ip ~= nil then
        text = text
                .. '\nМой внешний ip:\t\t<span color="GreenYellow"><b>'
                .. ip .. '</b></span>'
    end

    self.tooltip.markup = text
end

return setmetatable(WBody, { __call=WBody.new })

