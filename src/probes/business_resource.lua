-- Fixed idle/work/idle/work/recovery phases isolate incremental business churn.
local M={}
function M.start(bridge,ui,world,config,check,snapshots)
    local j,log=require 'jass.common',require 'jass.log'
    local scheduler=bridge.scheduler
    local matrix=config.suite=='resource_matrix'
    local names=matrix and {'idle','units','rest_units','events_tasks','rest_events','ui_updates','rest_ui','skills','rest_skills','combined','recovery'} or {'idle1','work1','idle2','work2','recovery'}
    local span=config.duration_ticks//#names
    assert(config.duration_ticks%#names==0 and span>=1000 and span%500==0,'resource profile requires equal 500-tick-aligned phases')
    local phase,cycles,finished_cycles,sequence=1,0,0,0
    local expected={}
    local baseline_ui=ui.count()
    local units_batches,event_batches,ui_batches,pending,event_calls,task_calls=0,0,0,0,0,0
    check(#world.players==config.clients,'resource profile uses expected connected peers')
    local function record(tag)
        log.info(string.format('[RESOURCE_PROFILE] tag=%s phase=%s tick=%d cycles=%d lua_kib=%.3f controls=%d actors=%d effects=%d units=%d probe_tasks=%d probe_events=%d ui_tasks=%d ui_events=%d unit_batches=%d event_batches=%d ui_batches=%d',tag,names[phase],scheduler:now(),finished_cycles,collectgarbage('count'),ui.count(),world.skills:count(),world.combat.effects,world.units:count(),pending,pending,ui.game.timer_size(),ui.game.events:count(),units_batches,event_batches,ui_batches))
    end
    record('begin')
    for index=2,#names do
        local next_phase=index
        scheduler:after((index-1)*span+1,function()
            check(world.challenges:count()==0 and world.combat.effects==0 and world.units:task_count()==0 and pending==0 and ui.count()==baseline_ui,'phase boundary has no retained business resources')
            record('end');phase=next_phase
            collectgarbage('collect');collectgarbage('collect') -- diagnostic boundary only
            record('begin')
        end)
    end
    local function command(player,verb,index,value)
        return world:command(player,{verb=verb,entity=world.heroes.by_player[player][index].unit_id,value=value})
    end
    local churn=scheduler:after(1,function()
        local name=names[phase]
        if name~='work1' and name~='work2' and name~='skills' and name~='combined' then return end
        cycles=cycles+1
        for _,player in ipairs(world.players)do check(command(player,'challenge',1,1),'resource workload starts encounter')end
        scheduler:after(100,function()
            for _,player in ipairs(world.players)do
                local s=assert(world.challenges:get(player))
                for index=1,3 do check(command(player,'cast',index,s.boss_id),'resource workload commits skill')end
            end
        end)
        scheduler:after(300,function()
            finished_cycles=finished_cycles+1
            for _,player in ipairs(world.players)do check(world.challenges.completed[player]==finished_cycles,'resource cycle rewards exactly once')end
            check(world.combat.effects==0 and world.skills:active_count()==0 and world.challenges:count()==0 and world.units:task_count()==0,'resource cycle releases native effects and owned tasks')
            check(world.units:count()==#world.players*3+1 and ui.count()==baseline_ui,'resource cycle unit/UI registrations return to baseline')
        end)
    end,500)
    local isolated=scheduler:after(50,function()
        if not matrix or (scheduler:now()-1)%span>=span-50 then return end
        local name=names[phase]
        if name=='units' or name=='combined' then
            units_batches=units_batches+1
            for _=1,20 do local u=world.units:create(12,string.unpack('>I4','hfoo'),0,0,0);world.units:remove(u.id)end
        end
        if name=='events_tasks' or name=='combined' then
            event_batches=event_batches+1
            local scope=require('scaffold.scope').new()
            local events=require('scaffold.events').new('sync')
            pending=pending+100
            for _=1,100 do
                scope:defer(events:on(function()event_calls=event_calls+1 end))
                local task=scheduler:after(1,function()task_calls=task_calls+1 end)
                scope:defer(function()task:cancel()end)
            end
            events:emit()
            scheduler:after(2,function()
                local ok,why=scope:close();assert(ok,why);pending=pending-100
                assert(events:count()==0,'isolated event registrations retained')
            end)
        end
        if name=='ui_updates' or name=='combined' then
            require('scaffold.context').local_call(function()
                local panel=ui.class.panel:builder{x=640,y=400,w=300,h=300,normal_image='core\\panel.blp'}
                for i=1,30 do
                    local control=ui.class.text:builder{parent=panel,x=0,y=(i-1)*8,w=200,h=12,font_size=12,text='sample'}
                    control:set_text('updated '..i)
                end
                panel:destroy()
            end)
            ui_batches=ui_batches+1
        end
    end,50)
    local samples=scheduler:after(1000,function()record('sample')end,1000)
    local peers=scheduler:after(500,function()
        sequence=sequence+1
        local value=world:snapshot()..':'..event_calls..':'..task_calls..':'..units_batches;local hash=17
        for i=1,#value do hash=(hash*31+value:byte(i))%2147483647 end
        local current=sequence;expected[current]=hash
        bridge:send('snapshot',current,hash)
        scheduler:after(300,function()
            for _,player in ipairs(world.players)do assert(snapshots[current] and snapshots[current][player]==expected[current],'resource peer state mismatch')end
            log.info('[STATE_MATCH] phase='..current..' hash='..hash..' resource_profile='..names[phase])
            snapshots[current],expected[current]=nil,nil
        end)
    end,1000)
    scheduler:after(config.duration_ticks,function()
        churn:cancel();isolated:cancel();samples:cancel();peers:cancel()
        check(finished_cycles==cycles and cycles==span//500*2,'both workload phases completed the exact same fixed cycle count')
        if matrix then
            local batches=(span//50-1)*2
            check(units_batches==batches and event_batches==batches and ui_batches==batches,'isolated and combined profiles execute equal bounded batch counts')
            check(pending==0 and event_calls==batches*100 and task_calls==batches*100,'isolated event and task work completes without retained registrations')
        end
        record('end')
        check(world:stop(),'resource profile world closes')
        check(world.units:count()==0 and world.skills:count()==0 and world.combat.effects==0,'resource profile final registrations are zero')
        check(require('app.main').stop(),'resource profile application bridge closes')
        check(ui.count()==0,'resource profile final UI count is zero')
        log.info((matrix and '[RESOURCE_MATRIX_DONE]' or '[RESOURCE_BUSINESS_DONE]')..' cycles='..cycles..' ticks='..config.duration_ticks)
        log.info('[UT_DONE] LuaScaffold '..config.build_id..' P'..(j.GetPlayerId(j.GetLocalPlayer())+1))
    end)
end
return M
