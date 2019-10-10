package.loaded.wvolume = nil
local module_path = (...):match("(.+)%.[^%.]+$") or ""
local module = require(module_path .. "wvolume.main")
return module
