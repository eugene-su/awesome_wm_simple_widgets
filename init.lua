package.loaded.wbacklight = nil
local module_path = (...):match("(.+)%.[^%.]+$") or ""
local module = require(module_path .. "wbacklight.main")
return module
