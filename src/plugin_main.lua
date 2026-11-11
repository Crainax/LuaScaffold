-- MPQ-relative only. Deliberately independent of war3map.wtg/local disk paths.
package.path = 'script\\?.lua;script\\?\\init.lua;' .. package.path
-- The pinned engine automatically requires this optional local protection tool.
-- This project ships plain JASS boot glue; never run a machine-global j2b script.
package.loaded.jass2binary = true
package.console_enable = false
require('jass.console').enable = false
local runtime = require 'jass.runtime'
runtime.handle_level = 0 -- before any application handles are read
runtime.sleep = false
local log = require 'jass.log'
local config = require 'app.config'
local jass = require 'jass.common'
log.path = (config.log_folder or config.project_id or 'LuaScaffold') .. '\\logs\\' .. config.build_id .. '-P' .. (jass.GetPlayerId(jass.GetLocalPlayer()) + 1) .. '.log'
print = function(...) log.info(...) end
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
