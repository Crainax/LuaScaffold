-- Compare the shared 0.01-second tick with an independent native 5-second timer.
local M={}
function M.start()
    local j,dbg,log=require 'jass.common',require 'jass.debug',require 'jass.log'
    local config=require 'app.config'
    local bridge=require('scaffold.innerjapi').start({},function() return false end)
    local timer=j.CreateTimer();dbg.handle_ref(timer)
    local rounds,start_clock=0,os.clock()
    log.info('[LuaScaffold] BOOT',_VERSION,require('jass.runtime').version)
    j.TimerStart(timer,5,true,function()
        rounds=rounds+1
        local ticks=bridge.scheduler:now()
        assert(ticks>0 and not bridge:is_faulted(),'clock probe bridge fault')
        log.info(string.format('[CLOCK_NATIVE] native_seconds=%d shared_ticks=%d logical_seconds=%.2f os_clock=%.6f',
            rounds*5,ticks,ticks/100,os.clock()-start_clock))
        if rounds==3 then
            j.PauseTimer(timer);j.DestroyTimer(timer);dbg.handle_unref(timer)
            assert(bridge:stop())
            log.info('PASS: three native clock intervals recorded and timers stopped')
            log.info('[CLOCK_NATIVE_DONE]')
            log.info('[UT_DONE] LuaScaffold '..config.build_id..' P'..(j.GetPlayerId(j.GetLocalPlayer())+1))
        end
    end)
end
return M
