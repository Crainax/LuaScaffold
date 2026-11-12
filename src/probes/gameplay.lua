-- Real engine and real command transport, plus explicitly labelled synchronized fault injection.
local M={}
function M.start(bridge,world,view,config,check)
    local j,japi,log=require 'jass.common',require 'jass.japi',require 'jass.log'
    local scheduler,players=bridge.scheduler,world.players
    local local_id=j.GetPlayerId(j.GetLocalPlayer())
    local old_targets={}
    local function click(key)require('scaffold.context').local_call(function()view.buttons[key]:event_notify('on_button_clicked')end)end
    local function command(player,verb,index,value)
        return world:command(player,{verb=verb,entity=world.heroes.by_player[player][index or 1].unit_id,value=value or 0})
    end
    for index=1,3 do
        scheduler:after(200+index*20,function()click('hero'..index);click('talent1')end)
    end
    scheduler:after(500,function()
        for _,player in ipairs(players)do
            for _,hero in ipairs(world.heroes.by_player[player])do check(hero.talent_choice==1,'real UI talent command applied to correct owner')end
        end
        click('start')
    end)
    scheduler:after(800,function()
        for _,player in ipairs(players)do
            local s=assert(world.challenges:get(player),'challenge start not received')
            old_targets[player]=s.boss_id
            check(s.pulses>0,'native boss pulse executed before player skills')
        end
        for index=1,3 do click('hero'..index);click('cast')end
    end)
    scheduler:after(1150,function()
        for _,player in ipairs(players)do check(world.challenges.completed[player]==1,'three Lua hero skills complete native challenge once')end
        check(world.combat.effects==0 and world.skills:active_count()==0,'victory releases all native cast effects and work')
        click('start')
    end)
    scheduler:after(1380,function()
        for _,player in ipairs(players)do world.skills:get(world.heroes.by_player[player][2].unit_id).energy=0 end
        bridge:send('cast',world.heroes.by_player[local_id][2].unit_id,world.challenges:get(local_id).boss_id)
    end)
    scheduler:after(1450,function()
        local index=1;for i,p in ipairs(players)do if p==local_id then index=i end end
        local own=world.heroes.by_player[local_id][1].unit_id
        local foreign=#players>1 and world.heroes.by_player[players[index%#players+1]][1].unit_id or world.placed.training_target.id
        local encounter=assert(world.challenges:get(local_id))
        bridge:send('cast',foreign,encounter.boss_id)
        bridge:send('cast',own,old_targets[local_id])
        japi.SendCustomMessage('LS1|1|ping|0|0')
        japi.SendCustomMessage('LS1|01|cast|0|0')
        japi.SendCustomMessage('LS1|bad')
        japi.SendCustomMessage('LS1|'..string.rep('x',129))
        japi.SendCustomMessage('LS1|2147483647|unlisted|0|0')
    end)
    scheduler:after(1800,function()
        local reasons=bridge.transport.reasons
        for _,reason in ipairs{'duplicate or stale','noncanonical command','invalid fields','invalid size','unknown command'}do
            check((reasons[reason] or 0)>=#players,'native transport rejected '..reason)
        end
        check((world.rejections['stale target'] or 0)>=#players,'stale target commands rejected after native handle retirement')
        check((world.rejections[#players>1 and 'not owner' or 'unknown hero'] or 0)>=#players,'real transport sender cannot control another actor')
        check((world.rejections.energy or 0)>=#players,'native transport cast rejected when energy is exhausted')
        for _,player in ipairs(players)do
            local hero=world.heroes.by_player[player][1]
            local unit=world.units:get(hero.unit_id)
            local encounter=assert(world.challenges:get(player))
            check(command(player,'cast',1,encounter.boss_id),'native windup starts for death interruption')
            local energy=world.skills:get(hero.unit_id).energy
            local life=j.GetWidgetLife(unit.handle)
            check(not command(player,'challenge',1,1),'repeated start rejected')
            check(world.skills:get(hero.unit_id).energy==energy and j.GetWidgetLife(unit.handle)==life,'rejected repeated start cannot replenish or heal')
            j.KillUnit(unit.handle)
            check(world.skills:get(hero.unit_id).cast==nil,'native actor death cancels active cast immediately')
        end
        check(world.combat.effects==0,'death interruption destroys native effects')
    end)
    scheduler:after(1900,function()
        for _,player in ipairs(players)do
            local s=assert(world.challenges:get(player));local boss=world.units:get(s.boss_id)
            check(math.abs(j.GetWidgetLife(boss.handle)-180)<0.01,'cancelled windup produces no late damage')
            check(command(player,'leave',1,s.id),'explicit abandonment finishes correct generation')
            local hero=world.heroes.by_player[player][1]
            check(world.units:get(hero.unit_id).state=='alive','challenge exit restores dead hero with same stable ID')
        end
    end)
    scheduler:after(2000,function()
        for _,player in ipairs(players)do
            check(command(player,'challenge',1,1),'target-removal encounter starts')
            local s=world.challenges:get(player)
            check(command(player,'cast',2,s.boss_id),'channel prepared before target removal')
            world.units:remove(s.boss_id)
            check(not world.challenges:get(player) and not world.skills:get(world.heroes.by_player[player][2].unit_id).cast,'target removal ends encounter and pending channel')
            check(world.challenges.completed[player]==1,'removal is not a duplicate victory')
        end
        check(world.combat.effects==0,'target removal releases native effects')
    end)
    scheduler:after(2150,function()
        for _,player in ipairs(players)do
            check(command(player,'challenge',1,1),'owner-change encounter starts')
            local s=world.challenges:get(player);local hero=world.heroes.by_player[player][3]
            local unit=world.units:get(hero.unit_id)
            check(command(player,'cast',3,s.boss_id),'cast prepared before owner change')
            j.SetUnitOwner(unit.handle,j.Player(15),false)
            check(not world.skills:get(hero.unit_id).cast,'native ownership event cancels cast')
            local accepted,reason=command(player,'cast',3,s.boss_id)
            check(not accepted and reason=='not owner','old owner rejected after control transfer')
            j.SetUnitOwner(unit.handle,j.Player(player),false)
            command(player,'leave',1,s.id)
        end
    end)
    local form,target
    scheduler:after(2300,function()
        local raw=function(s)return string.unpack('>I4',s)end
        form=world.units:create(0,raw('edoc'),8000,8000,0)
        target=world.units:create(12,raw('n001'),8100,8000,0)
        j.PauseUnit(target.handle,true)
        j.SetPlayerTechResearched(j.Player(0),raw('Redc'),2)
        world.skills:register(form.id,{key='form_probe',cost=0,cooldown=1,windup=300,interval=1,hits=1,damage=20,range=600,effect=require 'content.effects.cast_aura'})
        check(world.skills:cast(0,form.id,target.id),'skill active during native form transition')
        check(j.IssueImmediateOrder(form.handle,'bearform'),'native form transition order accepted during Lua windup')
    end)
    scheduler:after(2500,function()
        world.units:refresh(form.id)
        check(form.type_id==string.unpack('>I4','edcm') and not world.skills:get(form.id).cast,'native type change cancels Lua skill and owned effect')
        world.units:remove(form.id);world.units:remove(target.id)
        check(world.combat.effects==0,'form-transition effects return to baseline')
    end)
    scheduler:after(2650,function()
        local hero=world.heroes.by_player[players[1]][1]
        local unit=world.units:get(hero.unit_id)
        local h=unit.handle
        target=world.units:create(12,string.unpack('>I4','n001'),j.GetUnitX(h)+100,j.GetUnitY(h),0)
        j.PauseUnit(target.handle,true)
        local state=world.skills:get(hero.unit_id)
        local energy,cooldown,created=state.energy,state.cooldown_until,world.combat.effects_created
        local after=world.units.after
        world.units.after=function()error('controlled scheduler preparation failure')end
        local ok,err=pcall(world.skills.cast,world.skills,players[1],hero.unit_id,target.id)
        world.units.after=after
        check(not ok and tostring(err):find('controlled scheduler preparation failure',1,true),'controlled failure after native effect allocation is reported')
        check(world.combat.effects_created==created+1 and world.combat.effects==0,'preparation rollback destroys real allocated effect')
        check(state.energy==energy and state.cooldown_until==cooldown and not state.cast,'failed preparation commits neither energy nor cooldown')
        world.units:remove(target.id)
    end)
    local departure_world,revived_target,old_damage
    scheduler:after(2600,function()
        departure_world=require('world.session').start(scheduler,{0},true,function(err)bridge:abort(err)end)
        local actor=departure_world.units:get(departure_world.heroes.by_player[0][1].unit_id)
        revived_target=departure_world.units:create(12,string.unpack('>I4','H001'),j.GetUnitX(actor.handle)+100,j.GetUnitY(actor.handle),0)
        j.PauseUnit(revived_target.handle,true)
        check(departure_world.skills:cast(0,actor.id,revived_target.id),'target-revival native cast starts')
        old_damage=departure_world.combat.damage_calls
        j.KillUnit(revived_target.handle)
        check(j.ReviveHero(revived_target.handle,j.GetUnitX(actor.handle)+100,j.GetUnitY(actor.handle),false),'native target hero revives')
        j.PauseUnit(revived_target.handle,true)
        departure_world.units:refresh(revived_target.id)
        check(revived_target.state=='alive' and not departure_world.skills:get(actor.id).cast,'revived target retains ID but does not revive cancelled cast')
    end)
    scheduler:after(2750,function()
        check(departure_world.combat.damage_calls==old_damage,'target revival cannot reactivate delayed damage')
        departure_world.units:remove(revived_target.id)
        local actor=departure_world.heroes.by_player[0][2].unit_id
        check(departure_world:command(0,{verb='challenge',entity=actor,value=1}),'departure fixture starts native encounter')
        local encounter=departure_world.challenges:get(0)
        check(departure_world.skills:cast(0,actor,encounter.boss_id),'departure fixture allocates native cast resources')
        departure_world.units:create(0,string.unpack('>I4','hfoo'),0,0,0)
        departure_world.units.events:emit('player_left',0) -- Explicit simulation; no client actually disconnects.
        check(encounter.state=='player left' and departure_world.challenges:count()==0,'simulated departure ends active challenge without victory')
        check(departure_world.units:count()==1 and departure_world.skills:count()==0 and departure_world.combat.effects==0 and departure_world.units:task_count()==0,'simulated departure releases real owned units casts and effects but preserves borrowed placement')
        local accepted,reason=departure_world:command(0,{verb='cast',entity=actor,value=encounter.boss_id})
        check(not accepted and reason=='inactive player' and not departure_world:leave_player(0),'departed player requests rejected and departure cleanup is idempotent')
        check(departure_world:stop(),'departure fixture native event bridge closes')
        departure_world=nil;revived_target=nil
    end)
    scheduler:after(2800,function()
        local actor=world.heroes.by_player[local_id][1].unit_id
        for _=1,32 do check(bridge:send('cast',actor,old_targets[local_id]),'bounded native queue accepts available slot')end
        local accepted,reason=bridge:send('cast',actor,old_targets[local_id])
        check(not accepted and reason=='outgoing queue full','bounded native queue rejects request beyond capacity')
    end)
    scheduler:after(3250,function()
        check((world.rejections['stale target'] or 0)>=33*#players,'drained native queue revalidates stale targets instead of granting queued success')
    end)
    local cycles,completed_cycles=0,0
    local cycle_job
    cycle_job=scheduler:after(3000,function()
        if scheduler:now()>config.duration_ticks-500 then cycle_job:cancel();return end
        cycles=cycles+1
        local expected={}
        for _,player in ipairs(players)do
            expected[player]=(world.challenges.completed[player] or 0)+1
            check(command(player,'challenge',1,1),'repeated encounter starts with fresh stable IDs')
        end
        scheduler:after(100,function()
            for _,player in ipairs(players)do
                local s=assert(world.challenges:get(player))
                for index=1,3 do check(command(player,'cast',index,s.boss_id),'repeat cycle skill committed')end
            end
        end)
        scheduler:after(300,function()
            for _,player in ipairs(players)do check(world.challenges.completed[player]==expected[player],'repeat cycle produces one victory')end
            check(world.challenges:count()==0 and world.combat.effects==0 and world.skills:active_count()==0 and world.units:task_count()==0,'repeat cycle releases encounter and cast resources')
            check(world.units:count()==#players*3+1 and world.skills:count()==#players*3,'repeat cycle registration counts remain bounded')
            local refs=require('scaffold.handle_refs').snapshot()
            check(refs.kinds.unit.active==#players*3+1 and refs.kinds.effect.active==0 and refs.kinds.trigger.active==2 and refs.kinds.timer.active==1 and refs.errors==0,'repeat cycle handle references return to baseline')
            log.info(string.format('[HANDLE_REFS] phase=cycle active=%d refs=%d unrefs=%d unit=%d effect=%d trigger=%d timer=%d errors=%d',refs.active,refs.refs,refs.unrefs,refs.kinds.unit.active,refs.kinds.effect.active,refs.kinds.trigger.active,refs.kinds.timer.active,refs.errors))
            completed_cycles=completed_cycles+1
            log.info(string.format('[BUSINESS_RESOURCE] tick=%d cycles=%d units=%d actors=%d effects=%d tasks=%d lua_kib=%.3f',scheduler:now(),completed_cycles,world.units:count(),world.skills:count(),world.combat.effects,world.units:task_count(),collectgarbage('count')))
        end)
    end,500)
    return {finish=function()
        cycle_job:cancel()
        check(cycles>=1 and completed_cycles==cycles,'business lifecycle repetition completed all scheduled cycles')
        log.info(string.format('[BUSINESS_DONE] cycles=%d commands=%d rejected=%d effects_created=%d damage_calls=%d',cycles,world.commands,world.rejected,world.combat.effects_created,world.combat.damage_calls))
    end}
end
return M
