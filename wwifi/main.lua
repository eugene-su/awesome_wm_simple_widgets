--[[

Wifi watchdog widget for awesome wm.
'connman' is required.
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

--]]

--[[
    -- debug
    local naughty = require('naughty')
    local function n(text, title)
    local ttl = title or '!'
    local txt = text or '-'
    naughty.notify { title=tostring(ttl),
                     text=tostring(txt)
    }
end
--]]

local awful = require('awful')
local wibox = require('wibox')
local gears = require('gears')
local string = string
local tostring = tostring
local tonumber = tonumber
local setmetatable = setmetatable

------------ config variables ------------

local TERM = 'st'
local CHECKING_INTERVAL = 10
local CMD_IP = 'curl ifconfig.co/ip'
local CMD_COUNTRY = 'curl ifconfig.co/country'
local ICON_ON = gears.filesystem.get_dir('config')
        .. 'wwifi/connected.png'
local ICON_BAD = gears.filesystem.get_dir('config')
        .. 'wwifi/bad_connection.png'
local ICON_OFF = gears.filesystem.get_dir('config')
        ..  'wwifi/no_connection.png'
local TEXT_COLOR = 'Aquamarine' -- web color
local DEFAULT_TIP = 'Нет информации о подключении'

------------------------------------------

local ip
local country
local tx_session
local rx_session
local new_tx_session
local new_rx_session
local tx_bandwidth
local rx_bandwidth
local wifi_dev
local access_point
local wifi_parameters = {}
local CURRENT_AP = "connmanctl services | grep '*' | awk 'NR == 1 {print $3}'"
local CMD_CONNMAN = TERM .. ' connmanctl'
local CMD_RX = "cat /proc/net/dev | awk '/wl/ { print $2 }'"
local CMD_TX = "cat /proc/net/dev | awk '/wl/ { print $10 }'"
local CMD_WIFI_DEV = "cat /proc/net/dev | awk '/wl/ { print substr($1, 1, length($1)-1) }'"

local function connman_parser(text)
  local parameters = {}
  for line in text:gmatch('([^\r\n]+)') do
    if not string.match(line, '%[%s*%]')
        and string.match(line, '=') then
      if not string.match(line, '%[') then
        local key, value = string.match(line, '([%w%.]+) = (.+)')
        parameters[key] = value
      else
        local nested_list = {}
        local key, list = string.match(
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
        parameters[key] = nested_list
      end
    end
  end
  return parameters
end

local function read_param(...)
    local vars = {...}
    local value
    if #vars == 1 then
        value = wifi_parameters[vars[1]]
    else
        if wifi_parameters[vars[1]] ~= nil then
            value = wifi_parameters[vars[1]][vars[2]]
        end
    end
    if value == nil or value == '' then
        value = '--'
    end
    return value
end

local function get_wifi_dev_name()
    awful.spawn.easy_async_with_shell(
        CMD_WIFI_DEV,
        function(stdout_dev)
            wifi_dev = string.gsub(stdout_dev, '\n', '')
        end
    )
end

local function get_bandwidth()
    if wifi_dev ~= nil
            and wifi_dev ~= '' then
        awful.spawn.easy_async_with_shell(
            CMD_TX,
            function(stdout_tx)
                new_tx_session = string.gsub(stdout_tx, '\n', '')
            end
        )
        awful.spawn.easy_async_with_shell(
            CMD_RX,
            function(stdout_rx)
                new_rx_session = string.gsub(stdout_rx, '\n', '')
            end
        )
        -- for the first run
        if tx_session == nil
                or rx_session == nil then
            tx_session = new_tx_session
            rx_session = new_rx_session
            do return end
        end
    else
        tx_session = nil
        rx_session = nil
        tx_bandwidth = nil
        rx_bandwidth = nil
        do return end
    end
    tx_bandwidth = tonumber(new_tx_session) - tonumber(tx_session)
    rx_bandwidth = tonumber(new_rx_session) - tonumber(rx_session)
    tx_session = new_tx_session
    rx_session = new_rx_session
end

local function human_readable(size_in_bytes)
    local value
    local number = tonumber(size_in_bytes)
    if number < 1024 then
        value = tostring(number) .. ' b'
    elseif number < 1048576
            and number >= 1024 then
        value = string.format('%.1f', number/1024) .. ' kb'
    else
        value = string.format('%.1f', number/1048576) .. ' mb'
    end
    return value
end

local function get_ip_info()
    ip = nil
    country = nil
    awful.spawn.easy_async_with_shell(
        CMD_IP,
        function(stdout)
            ip = string.gsub(stdout, '\n', '')
        end
    )
    awful.spawn.easy_async_with_shell(
        CMD_COUNTRY,
        function(stdout)
            country = string.gsub(stdout, '\n', '')
        end
    )
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
            image=ICON_ON,
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
            markup='',
            id='text'
        }
    }

    self.tooltip = awful.tooltip
    {
        objects={ self.widget },
        border_color='#ebcb8b',
        border_width=1,
        bg='#2e3440',
        markup=DEFAULT_TIP
    }

    -- mouse buttons bindings
    self.widget:buttons(
        gears.table.join(
            awful.button(
                {}, 1,
                function() awful.spawn(CMD_CONNMAN, false) end
            ),
            awful.button({}, 2, function() self:get(); get_ip_info() end),
            awful.button({}, 3, function() self:get(); get_ip_info() end)
        )
    )

    -- main timer
    gears.timer { timeout=CHECKING_INTERVAL,
                  autostart=true,
                  callback=function() self:get() end
    }

    -- bandwidth timer
    self.bandwidth_timer = gears.timer
    {
        timeout=1,
        autostart=false,
        callback=function()
            if read_param('State') ~= 'idle'
                    and read_param('State') ~= '--' then
                get_bandwidth()
                self:update_tooltip()
            end
        end
    }
    self.widget:connect_signal('mouse::enter',
                                function()
                                    self.bandwidth_timer:start()
                                end
    )
    self.widget:connect_signal('mouse::leave',
                                function()
                                    self.bandwidth_timer:stop()
                                end
    )

    -- first shot
    self:get()
    get_ip_info()
    return self
end

function WBody:get()
    awful.spawn.easy_async_with_shell(
        CURRENT_AP,
        function(stdout_1)
            access_point = string.gsub(stdout_1, '\n', '')
            if #access_point == 0 then
                wifi_parameters['State'] = 'idle'
                self:update_icon('idle')
                self.tooltip.markup = DEFAULT_TIP
                self.widget:get_children_by_id('text')[1].markup = ''
                do return end
            end

            awful.spawn.easy_async_with_shell(
                    'connmanctl services ' .. access_point,
                function(stdout_2)
                    wifi_parameters = connman_parser(stdout_2)
                    self:update_text(read_param('Strength'))
                    self:update_icon(read_param('State'))
                    self.widget:emit_signal('widget::redraw_needed')
                    self:update_tooltip()
                end
            )
        end
    )
    -- update wifi device info
    get_wifi_dev_name()
end

function WBody:update_text(text)
    self.widget:get_children_by_id('text')[1].markup
            = string.format('<span color="%s">%s</span>', TEXT_COLOR, text)
end

function WBody:update_icon(text)
    local icon
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
    if read_param('State') == 'idle' then
        self.tooltip.markup = DEFAULT_TIP
        self.widget:get_children_by_id('text')[1].markup = ''
        do return end
    end

    local text =
    'Сила сигнала:\t\t' .. read_param('Strength')
    .. '\nSSID точки доступа:\t<span color="#ebcb8b"><b>'
    ..  read_param('Name') .. '</b></span>'
    ..  '\nСостояние подключения:\t' .. read_param('State')
    .. '\nПолученный от ТД IPv4:\t' .. read_param('IPv4', 'Address')
    .. '\nТип шифрования ключа:\t' .. read_param('Security', 1)
    .. '\nАвтоподключение:\t' .. read_param('AutoConnect')
    .. '\nMac-адрес ТД:\t\t' .. read_param('Ethernet', 'Address')
    .. '\nGateway:\t\t' .. read_param('IPv4', 'Gateway')
    .. '\nDNS ТД:\t\t\t' .. read_param('Nameservers', 1)
    .. '\n\t\t\t' .. read_param('Nameservers', 2)

    if ip ~= '' and ip ~= nil then
        text = text
                .. '\n\nМой внешний ip:\t\t<span color="#ebcb8b"><b>'
                .. ip .. '</b></span>'
    end
    if country ~= '' and country ~= nil then
        text = text
                .. '\nСтрана:\t\t\t<span color="#a3be8c"><b>'
                .. country .. '</b></span>'
    end

    if wifi_dev ~= nil
            and wifi_dev ~= '' then
        text = text
                .. '\nСетевой интерфейс:\t' .. wifi_dev
    end
    if tx_session ~= nil
            and rx_session ~= nil then
        text = text
                .. '\n\nВсего передано за сессию:'
                .. '\nTX:\t\t\t' .. human_readable(tx_session)
                .. '\nRX:\t\t\t' .. human_readable(rx_session)
    end
    if tx_bandwidth ~= nil
            and rx_bandwidth ~= nil then
        text = text
                .. '\n\nТекущая скорость соединения:'
                .. '\nTX:\t\t\t' .. human_readable(tx_bandwidth)
                .. '\nRX:\t\t\t' .. human_readable(rx_bandwidth)
    end

    self.tooltip.markup = text
end

return setmetatable(WBody, { __call=WBody.new })
