package.loaded.wcputemp = nil
local module_path = (...):match("(.+)%.[^%.]+$") or ""
local module = require(module_path .. "wcputemp.main")
return module
