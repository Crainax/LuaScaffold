-- Official globals are isolated here. No common.lua or Blizzard initialization.
local jass = require 'jass.common'
local env = {log = require 'jass.log'}
env.print = function(...) env.log.info('[UI]', ...) end
setmetatable(env, {__index = function(_, key)
    local value = _G[key]
    if value ~= nil then return value end
    return jass[key]
end})
return env
