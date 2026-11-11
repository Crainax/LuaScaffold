-- Multi-client bridge/engine baseline. No units, UI or hot reload.
local M={}
function M.start()
    local j,log=require 'jass.common',require 'jass.log'
    local config=require 'app.config'
    local local_id=j.GetPlayerId(j.GetLocalPlayer())
    local bridge=require('scaffold.innerjapi').start({},function() return false end)
    local humans=0
    for i=0,11 do
        if j.GetPlayerController(j.Player(i))==j.MAP_CONTROL_USER and j.GetPlayerSlotState(j.Player(i))==j.PLAYER_SLOT_STATE_PLAYING then humans=humans+1 end
    end
    assert(humans==config.clients,'diagnostic peer count mismatch')
    local function record(tag)
        log.info(string.format('[RESOURCE_PROFILE] tag=%s phase=idle tick=%d cycles=0 lua_kib=%.3f controls=0',
            tag,bridge.scheduler:now(),collectgarbage('count')))
    end
    log.info('[LuaScaffold] BOOT',_VERSION,require('jass.runtime').version)
    record('begin')
    bridge.scheduler:after(1000,function() record('sample') end,1000)
    bridge.scheduler:after(75000,function()
        record('end');assert(not bridge:is_faulted(),'bridge fault')
        assert(bridge:stop())
        log.info('PASS: bridge idle diagnostic completed at 75000 ticks with expected peers and clean stop')
        log.info('[RESOURCE_IDLE_DONE] ticks=75000 clients='..humans)
        log.info('[UT_DONE] LuaScaffold '..config.build_id..' P'..(local_id+1))
    end)
end
return M
