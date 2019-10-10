package.loaded.wwifi = nil
local module_path = (...):match("(.+)%.[^%.]+$") or ""
local module = require(module_path .. "wwifi.main")
return module
