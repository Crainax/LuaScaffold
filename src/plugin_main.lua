-- MPQ-relative only. Deliberately independent of war3map.wtg/local disk paths.
package.path = 'script\\?.lua;script\\?\\init.lua;' .. package.path
local runtime = require 'jass.runtime'
runtime.handle_level = 0 -- before any application handles are read
runtime.sleep = false
local log = require 'jass.log'
local config = require 'app.config'
local jass = require 'jass.common'
log.path = (config.project_id or 'LuaScaffold') .. '\\logs\\' .. config.build_id .. '-P' .. (jass.GetPlayerId(jass.GetLocalPlayer()) + 1) .. '.log'
runtime.error_handle = function(err)
    log.error('FAIL: [LuaScaffold] LUA ERROR', tostring(err), debug.traceback())
end
local ok, err = xpcall(function()
    require('jass.japi').SetOwner('问号') -- preserve the upstream loader convention
    require('app.main').start()
end, debug.traceback)
if not ok then
    runtime.error_handle(err)
    error(err, 0)
end
