-- Native evidence: fixed workload on every peer. Raw handle observations never drive gameplay.
local M={}
function M.start(bridge,check)
    local j,log=require 'jass.common',require 'jass.log'
    local units=require('game.unit.service').new(bridge.scheduler,nil,function(err)bridge:abort(err)end)
    local scheduler=bridge.scheduler
    local function raw(s)return string.unpack('>I4',s) end
    local placements=require 'world.generated_placements'
    local placed=units:register_placements(placements.resolve(j))
    for _,p in ipairs(placements.expected) do
        local r=placed[p.key]
        check(r.type_id==raw(p.rawcode) and r.owner==p.owner,'map preplaced unit type/owner readback')
        check(math.abs(j.GetUnitX(r.handle)-p.x)<1 and math.abs(j.GetUnitY(r.handle)-p.y)<1,'source map placement survives LNI pack and initialization')
    end
    for _,r in ipairs(placements.regions(j)) do
        local b=r.bounds
        check(j.GetRectMinX(r.handle)==b[1] and j.GetRectMinY(r.handle)==b[2] and j.GetRectMaxX(r.handle)==b[3] and j.GetRectMaxY(r.handle)==b[4],'source map region initialized before Lua')
    end
    for index,name in ipairs{'Reimu','Marisa','Sakuya'} do
        local r=units:create(0,raw('H00'..index),-1536+index*256,-1536,0)
        j.PauseUnit(r.handle,true)
        check(j.GetUnitName(r.handle)==name,'custom hero object name readback '..name)
    end
    local hero=units:create(0,raw('H001'),-512,0,0)
    local old_id,old_handle=hero.id,hero.handle
    local death_events,owner_events,summon_events,calls=0,0,0,0
    units.events:on(function(kind)
        if kind=='death' then death_events=death_events+1 end
        if kind=='owner' then owner_events=owner_events+1 end
        if kind=='summoned' then summon_events=summon_events+1 end
    end)
    units:after(hero.id,200,function() calls=calls+1 end)
    scheduler:after(30,function()
        j.KillUnit(hero.handle)
        check(hero.state=='dead' and death_events==1,'native death event invalidates life tasks but retains unit ID')
    end)
    scheduler:after(100,function()
        check(j.ReviveHero(hero.handle,-512,0,false),'native hero revive succeeds')
        units:refresh(hero.id)
        check(hero.state=='alive' and hero.id==old_id and hero.handle==old_handle,'revival retains stable ID and observed native handle')
        units:after(hero.id,200,function() calls=calls+1 end)
        j.SetUnitOwner(hero.handle,j.Player(1),false)
    end)
    scheduler:after(150,function()
        units:refresh(hero.id)
        check(hero.owner==1 and owner_events==1,'native owner change refreshes ownership')
        j.RemoveUnit(hero.handle)
        log.info(string.format('[REMOVE_OBSERVE] phase=immediate type=%d life=%.3f hidden=%s dead=%s',j.GetUnitTypeId(old_handle),j.GetWidgetLife(old_handle),tostring(j.IsUnitHidden(old_handle)),tostring(j.IsUnitType(old_handle,j.UNIT_TYPE_DEAD))))
    end)
    scheduler:after(151,function()
        log.info(string.format('[REMOVE_OBSERVE] phase=next_tick type=%d life=%.3f hidden=%s dead=%s',j.GetUnitTypeId(old_handle),j.GetWidgetLife(old_handle),tostring(j.IsUnitHidden(old_handle)),tostring(j.IsUnitType(old_handle,j.UNIT_TYPE_DEAD))))
        units:refresh(old_id)
        check(units:get(old_id)==nil,'external removal is detected after native state catches up')
    end)
    scheduler:after(200,function()
        log.info(string.format('[REMOVE_OBSERVE] phase=half_second type=%d life=%.3f hidden=%s dead=%s',j.GetUnitTypeId(old_handle),j.GetWidgetLife(old_handle),tostring(j.IsUnitHidden(old_handle)),tostring(j.IsUnitType(old_handle,j.UNIT_TYPE_DEAD))))
        check(not units:detach(old_id),'repeated external-remove notification is idempotent')
    end)
    local morph,summoner,bear,custom_morph,custom_bear
    scheduler:after(250,function()
        check(calls==0,'old life callbacks do not execute after death or owner change')
        morph=units:create(0,raw('Edem'),0,0,0)
        j.SetHeroLevel(morph.handle,6,false)
        j.SelectHeroSkill(morph.handle,raw('AEme'))
        check(j.IssueImmediateOrder(morph.handle,'metamorphosis'),'native metamorphosis order accepted')
        summoner=units:create(0,raw('Hamg'),512,0,0)
        j.UnitRemoveAbility(summoner.handle,raw('AHwe'))
        j.UnitAddAbility(summoner.handle,raw('A002'))
        check(j.IssueImmediateOrder(summoner.handle,'waterelemental'),'native summon order accepted')
        bear=units:create(0,raw('edoc'),768,0,0)
        j.SetPlayerTechResearched(j.Player(0),raw('Redc'),2)
        check(j.IssueImmediateOrder(bear.handle,'bearform'),'native bear-form order accepted')
        custom_morph=units:create(0,raw('Edem'),1024,0,0)
        j.UnitRemoveAbility(custom_morph.handle,raw('AEme'))
        j.UnitAddAbility(custom_morph.handle,raw('A001'))
        j.UnitMakeAbilityPermanent(custom_morph.handle,true,raw('A001'))
        check(j.IssueImmediateOrder(custom_morph.handle,'metamorphosis'),'permanent custom morph order accepted')
        custom_bear=units:create(0,raw('edoc'),1280,0,0)
        j.UnitRemoveAbility(custom_bear.handle,raw('Abrf'))
        j.UnitAddAbility(custom_bear.handle,raw('A003'))
        j.UnitMakeAbilityPermanent(custom_bear.handle,true,raw('A003'))
        check(j.IssueImmediateOrder(custom_bear.handle,'bearform'),'permanent custom bear order accepted')
    end)
    scheduler:after(500,function()
        local before=morph.type_id;units:refresh(morph.id)
        log.info(string.format('[UNIT_FORM] before=%d after=%d id=%d epoch=%d ability=%d buff=%d order=%d summons=%d',before,morph.type_id,morph.id,morph.epoch,j.GetUnitAbilityLevel(morph.handle,raw('AEme')),j.GetUnitAbilityLevel(morph.handle,raw('BEme')),j.GetUnitCurrentOrder(morph.handle),summon_events))
        check(units:get(morph.id)==morph,'native morph preserves tracked object when native handle remains')
        check(morph.type_id==raw('Edmm') and morph.epoch>1 and j.GetUnitAbilityLevel(morph.handle,raw('BEme'))>0,'metamorphosis changes type, invalidates life generation and applies native buff')
        units:refresh(bear.id)
        log.info(string.format('[BEAR_FORM] type=%d epoch=%d ability=%d',bear.type_id,bear.epoch,j.GetUnitAbilityLevel(bear.handle,raw('Abrf'))))
        check(bear.type_id==raw('edcm') and bear.epoch>1,'bear form changes native type and invalidates life generation')
        units:refresh(custom_morph.id);units:refresh(custom_bear.id)
        log.info(string.format('[CUSTOM_FORM] morph_type=%d bear_type=%d morph_ability=%d bear_ability=%d',custom_morph.type_id,custom_bear.type_id,j.GetUnitAbilityLevel(custom_morph.handle,raw('A001')),j.GetUnitAbilityLevel(custom_bear.handle,raw('A003'))))
        check(custom_morph.type_id==raw('Edmm') and custom_bear.type_id==raw('edcm'),'permanent custom morph abilities survive form replacement')
        check(summon_events>=1,'native summon event registers summoned unit')
    end)
    local observed,reuses={},0
    local weak=setmetatable({},{__mode='v'})
    local weak_units=setmetatable({},{__mode='v'})
    local retained_tokens={}
    local function capture(value)return function() assert(value) end end
    local batch=0
    local reuse_job
    reuse_job=scheduler:after(600,function()
        local before=require('scaffold.handle_refs').snapshot()
        batch=batch+1
            for i=1,20 do
                local r=units:create(0,raw('n001'),0,-512,0)
                local handle=j.GetHandleId(r.handle)
                if observed[handle] then reuses=reuses+1 end
                observed[handle]=true
                local id=r.id
                local payload={};weak[batch*20+i]=payload
                local token=units:after(id,10000,capture(payload))
                if batch==1 and i<=8 then retained_tokens[i]=token;weak_units[i]=r end
                units:remove(id)
                assert(units:get(id)==nil,'removed unit ID cannot resolve')
            end
        local after=require('scaffold.handle_refs').snapshot()
        check(after.active==before.active and after.refs-before.refs==20 and after.unrefs-before.unrefs==20 and after.errors==0,'unit batch references return to baseline')
        if batch<100 then return end
        reuse_job:cancel()
        check(true,'2000 removed stable unit IDs remain invalid across 100 bounded batches')
        log.info(string.format('[HANDLE_REUSE] creates=2000 repeated_native_ids=%d mode=100_batches_20_units_10_tick_spacing',reuses))
        collectgarbage('collect');collectgarbage('collect')
        local retained=0;for _ in pairs(weak) do retained=retained+1 end
        check(retained==0,'native unit-owned cancelled callbacks release payloads')
        local retained_units=0;for _ in pairs(weak_units)do retained_units=retained_units+1 end
        check(#retained_tokens==8 and retained_units==0,'retained cancelled tokens release removed native unit records')
        observed={}
    end,10)
    local completed=false
    scheduler:after(2000,function()
        check(units:stop(),'native unit manager cleanup completes')
        check(units:count()==0 and units:task_count()==0,'native unit manager returns registrations to zero')
        completed=true
        log.info('[UNIT_LIFECYCLE_DONE] native lifecycle and bounded reuse experiment complete')
    end)
    return {
        snapshot=function()return completed and 'unit-probe:complete' or (units:snapshot()..';batch='..batch..';summons='..summon_events) end,
        complete=function()return completed end,
    }
end
return M
