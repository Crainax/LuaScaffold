-- Minimal synchronized example. No rewards, HTTP, F5 or vendor auto-loader.
local M = {}
local bridge
local ui
local config = require 'app.config'
function M.start()
    assert(not bridge, 'app already started')
    local log = require 'jass.log'
    local jass = require 'jass.common'
    local counts = {}
    local handlers = {
        ping = function(sender)
            counts[sender] = (counts[sender] or 0) + 1
            log.info('[LuaScaffold] COMMAND ping', sender, counts[sender])
        end,
    }
    local test
    if config.runtime_test then
        test = require 'app.runtime_test'
        test.handlers(handlers)
    end
    bridge = require('scaffold.innerjapi').start(handlers, function(sender, cmd)
        local allowed = cmd.verb == 'ping' and cmd.entity == 0 and cmd.value == 0
        if test then allowed = allowed or test.authorize(sender, cmd) end
        return allowed
            and jass.GetPlayerController(jass.Player(sender)) == jass.MAP_CONTROL_USER
            and jass.GetPlayerSlotState(jass.Player(sender)) == jass.PLAYER_SLOT_STATE_PLAYING
    end)
    if config.ui then
        ui = require('scaffold.ui').start()
        bridge.scheduler:after(1, function() ui.step() end, 1)
        require('app.view').start(ui, bridge)
    end
    log.info('[LuaScaffold] BOOT', _VERSION, require('jass.runtime').version)
    if test then test.start(bridge, ui, counts, config) end
    return bridge
end
function M.stop()
    if not bridge then return true end
    local old = bridge
    bridge = nil
    if ui then ui.stop() end
    return old:stop()
end
return M
