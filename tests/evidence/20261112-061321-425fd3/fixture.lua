-- Diagnostic replacement for app.main, never shipped in ordinary builds.
-- Ordered phases isolate engine idle, unit churn, UI churn and edit-control churn.
local M={}
function M.start()
    local j,log=require 'jass.common',require 'jass.log'
    local config=require 'app.config'
    local Context=require 'scaffold.context'
    local timer=j.CreateTimer()
    local tick,phase,cycles=0,1,0
    local names={'idle','units','ui_without_edit','ui_with_edit','recovery'}
    local span=15000
    local units,ui={},nil
    local function clear_units()
        for i=#units,1,-1 do j.RemoveUnit(units[i]);units[i]=nil end
    end
    local function record(tag)
        log.info(string.format('[RESOURCE_PROFILE] tag=%s phase=%s tick=%d cycles=%d lua_kib=%.3f controls=%d',
            tag,names[phase],tick,cycles,collectgarbage('count'),ui and ui.count() or 0))
    end
    log.info('[LuaScaffold] BOOT',_VERSION,require('jass.runtime').version)
    record('begin')
    j.TimerStart(timer,0.01,true,function()
        tick=tick+1
        if phase==2 and tick%500==0 then
            if #units>0 then j.RemoveUnit(table.remove(units,1)) end
            local unit=j.CreateUnit(j.Player(0),string.unpack('>I4','hfoo'),0,0,0)
            j.PauseUnit(unit,true);j.SetUnitInvulnerable(unit,true)
            units[#units+1]=unit;cycles=cycles+1
        elseif (phase==3 or phase==4) and tick%25==0 then
            Context.local_call(function()
                for _=1,10 do
                    local p=ui.class.panel:builder{x=30,y=40,w=240,h=180,normal_image='core\\panel.blp'}
                    ui.class.button:builder{parent=p,x=5,y=5,w=32,h=32,normal_image='core\\button.blp'}
                    ui.class.text:builder{parent=p,x=45,y=5,w=140,h=30,text='resource probe',font_size=16}
                    if phase==4 then ui.class.edit:builder{parent=p,x=5,y=60,w=150,h=30,text='edit probe',font_size=16} end
                    p:destroy();cycles=cycles+1
                end
            end)
            collectgarbage('collect')
        end
        if ui then ui.step() end
        if tick%1000==0 then record('sample') end
        if tick%span==0 then
            record('end');clear_units()
            phase=phase+1;cycles=0
            if phase==3 then ui=require('scaffold.ui').start() end
            if phase==5 then ui.stop();ui=nil;collectgarbage('collect');collectgarbage('collect') end
            if phase>#names then
                j.PauseTimer(timer);j.DestroyTimer(timer)
                log.info('[RESOURCE_PROFILE_DONE] all phases complete')
                log.info('[UT_DONE] LuaScaffold '..config.build_id..' P1')
            else record('begin') end
        end
    end)
end
return M
