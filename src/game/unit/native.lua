-- All operations belong to the synchronized domain; this adapter has no implicit hooks.
local j=require 'jass.common'
local dbg=require 'jass.debug'
local Scope=require 'scaffold.scope'
local Context=require 'scaffold.context'
local M={}
function M.info(handle)
    if not handle or handle==0 then return nil end
    local type_id=j.GetUnitTypeId(handle)
    if type_id==0 then return nil end
    return {type_id=type_id,owner=j.GetPlayerId(j.GetOwningPlayer(handle)),
        dead=j.IsUnitType(handle,j.UNIT_TYPE_DEAD) or j.GetWidgetLife(handle)<=0.405}
end
function M.create(owner,type_id,x,y,facing) return j.CreateUnit(j.Player(owner),type_id,x,y,facing) end
function M.remove(handle) j.RemoveUnit(handle) end
function M.ref(handle) dbg.handle_ref(handle) end
function M.unref(handle) dbg.handle_unref(handle) end
function M.bind(manager,on_fault)
    Context.assert_sync()
    local scope,active=Scope.new(),true
    local trigger=j.CreateTrigger();assert(trigger and trigger~=0,'unit event trigger creation failed');dbg.handle_ref(trigger)
    scope:defer(function() j.DestroyTrigger(trigger);dbg.handle_unref(trigger) end)
    local ok,err=pcall(function()
    for i=0,15 do
        j.TriggerRegisterPlayerEvent(trigger,j.Player(i),j.EVENT_PLAYER_LEAVE)
        j.TriggerRegisterPlayerUnitEvent(trigger,j.Player(i),j.EVENT_PLAYER_UNIT_DEATH,nil)
        j.TriggerRegisterPlayerUnitEvent(trigger,j.Player(i),j.EVENT_PLAYER_UNIT_CHANGE_OWNER,nil)
        j.TriggerRegisterPlayerUnitEvent(trigger,j.Player(i),j.EVENT_PLAYER_HERO_REVIVE_FINISH,nil)
        j.TriggerRegisterPlayerUnitEvent(trigger,j.Player(i),j.EVENT_PLAYER_UNIT_SUMMON,nil)
    end
    local function dispatch()
        if j.GetTriggerEventId()==j.EVENT_PLAYER_LEAVE then
            manager.events:emit('player_left',j.GetPlayerId(j.GetTriggerPlayer()))
        elseif j.GetTriggerEventId()==j.EVENT_PLAYER_UNIT_SUMMON then
            local parent=manager:find(j.GetSummoningUnit())
            local handle=j.GetSummonedUnit()
            if parent and not manager:find(handle) then
                local child=manager:adopt(handle,true)
                child.summoner_id=parent.id
                manager.events:emit('summoned',child,parent)
            end
        else
            local r=manager:find(j.GetTriggerUnit())
            if r then manager:refresh(r.id) end
        end
    end
    local faulted=false
    local action=j.TriggerAddAction(trigger,function()
        if not active or faulted then return end
        local succeeded,why=pcall(dispatch)
        if not succeeded then
            faulted=true
            if on_fault then on_fault(why)end
            error(why,0)
        end
    end)
    scope:defer(function()j.TriggerRemoveAction(trigger,action)end)
    end)
    if not ok then
        active=false;local clean,why=scope:close()
        error(tostring(err)..(clean and '' or '\ncleanup: '..tostring(why)),0)
    end
    return function()
        Context.assert_sync()
        if not active then return true end;active=false
        return scope:close()
    end
end
return M
