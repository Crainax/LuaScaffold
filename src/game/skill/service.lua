-- Synchronized skill transactions. Native effects, listeners and delayed work belong to one cast.
local Context=require 'scaffold.context'
local Scope=require 'scaffold.scope'
local M={}
local function ordered(t)local out={};for id in pairs(t) do out[#out+1]=id end;table.sort(out);return out end
local function validate(d)
    assert(type(d)=='table' and type(d.key)=='string','skill definition required')
    for _,name in ipairs{'cost','cooldown','windup','interval','hits','damage','range'} do
        local n=d[name];assert(type(n)=='number' and n%1==0 and n>=0 and n<=1000000,'invalid skill '..name)
    end
    assert(d.hits>=1 and d.hits<=32 and d.windup>=1 and d.interval>=1,'bounded delayed skill required')
end
function M.new(units,scheduler,combat)
    local states,stopped={},false
    local self={accepted=0,hits=0,cancelled=0}
    local function guard()Context.assert_sync();assert(not stopped,'skill service stopped')end
    local function finish(s,reason)
        local cast=s.cast;if not cast then return false end
        s.cast=nil;cast.active=false;cast.reason=reason
        if reason~='complete' then self.cancelled=self.cancelled+1 end
        local ok,err=cast.scope:close()
        if not ok then error(err,0) end
        return true
    end
    local function unregister(id)
        local s=states[id];if not s then return false end
        states[id]=nil
        local ok,err=pcall(finish,s,'unregistered')
        s.off();s.off=nil
        if not ok then error(err,0) end
        return true
    end
    function self:register(id,definition,energy)
        guard();validate(definition)
        assert(not states[id],'skill actor already registered')
        local unit=assert(units:get(id),'skill actor missing')
        energy=energy or 100
        assert(type(energy)=='number' and energy%1==0 and energy>=0 and energy<=1000000,'invalid energy')
        local s={id=id,definition=definition,energy=energy,max_energy=energy,cooldown_until=0}
        s.off=unit.events:on(function(event)if event=='removed' then unregister(id)end end)
        states[id]=s
        return s
    end
    function self:get(id)return states[id]end
    function self:unregister(id)guard();return unregister(id)end
    function self:cancel(id,reason)guard();local s=states[id];return s and finish(s,reason or 'interrupted') or false end
    function self:set_definition(id,definition)
        guard();validate(definition)
        local s=assert(states[id],'skill actor missing');assert(not s.cast,'cannot change skill during cast')
        s.definition=definition -- cooldown and energy are deliberately retained
    end
    function self:replenish(id)
        guard();local s=assert(states[id],'skill actor missing');assert(not s.cast,'cannot replenish during cast')
        s.energy=s.max_energy
    end
    function self:cast(sender,id,target_id)
        guard()
        local s=states[id];if not s then return false,'unknown actor' end
        local actor,target=units:refresh(id),units:refresh(target_id)
        if not actor or actor.state~='alive' then return false,'actor unavailable' end
        if actor.owner~=sender then return false,'not owner' end
        if not target or target.state~='alive' then return false,'target unavailable' end
        if s.cast then return false,'already casting' end
        local d=s.definition
        if scheduler:now()<s.cooldown_until then return false,'cooldown' end
        if s.energy<d.cost then return false,'energy' end
        if not combat.is_enemy(actor,target) then return false,'friendly target' end
        if not combat.in_range(actor,target,d.range) then return false,'range' end
        local cast={scope=Scope.new(),active=true,target_id=target_id,hits=0}
        s.cast=cast
        local function schedule(delay,fn)
            local job=units:after(id,delay,fn)
            cast.scope:defer(function()job:cancel()end)
        end
        local function hit(current)
            if not cast.active then return end
            local dest=units:refresh(target_id)
            if not cast.active then return end
            if not dest or dest.state~='alive' or not combat.is_enemy(current,dest) then finish(s,'target unavailable');return end
            if not combat.in_range(current,dest,d.range) then finish(s,'target moved');return end
            cast.hits=cast.hits+1;self.hits=self.hits+1
            -- Native damage may synchronously kill/remove the target and close this scope.
            combat.damage(current,dest,d.damage)
            if not cast.active then return end
            if cast.hits>=d.hits then finish(s,'complete')else schedule(d.interval,hit)end
        end
        local ok,err=pcall(function()
            cast.scope:defer(actor.events:on(function(event)
                if event=='death' or event=='removed' or event=='owner' or event=='form' or event=='revived' then finish(s,'actor '..event)end
            end))
            cast.scope:defer(target.events:on(function(event)
                if event=='death' or event=='removed' or event=='owner' or event=='form' then finish(s,'target '..event)end
            end))
            cast.scope:defer(combat.effect(d,actor,target))
            schedule(d.windup,hit)
        end)
        if not ok then
            local clean,why=pcall(finish,s,'preparation failed')
            error(tostring(err)..(clean and '' or '\ncleanup: '..tostring(why)),0)
        end
        -- Commit only after effect/listener/task preparation succeeds. No refunds after commit.
        s.energy=s.energy-d.cost;s.cooldown_until=scheduler:now()+d.cooldown
        self.accepted=self.accepted+1
        return true
    end
    function self:active_count()local n=0;for _,s in pairs(states)do if s.cast then n=n+1 end end;return n end
    function self:count()local n=0;for _ in pairs(states)do n=n+1 end;return n end
    function self:snapshot()
        guard();local out={}
        for _,id in ipairs(ordered(states))do
            local s=states[id]
            out[#out+1]=table.concat({id,s.definition.key,s.energy,s.cooldown_until,s.cast and s.cast.hits or -1},':')
        end
        return table.concat(out,'|')
    end
    function self:stop()
        Context.assert_sync();if stopped then return true end;stopped=true
        local errors={}
        for _,id in ipairs(ordered(states))do local ok,err=pcall(unregister,id);if not ok then errors[#errors+1]=tostring(err)end end
        if #errors>0 then return false,table.concat(errors,'\n')end
        return true
    end
    return self
end
return M
