package.loaded.wpower = nil
local module_path = (...):match("(.+)%.[^%.]+$") or ""
local module = require(module_path .. "wpower.main")
return module
