-- Map composition root. Only this module assembles native services and project content.
local Context=require 'scaffold.context'
local Scope=require 'scaffold.scope'
local Talents=require 'systems.talents.service'
local Training=require 'content.challenges.training.definition'
local M={}
function M.start(scheduler,players,test_mode,on_fault)
    Context.assert_sync()
    local j=require 'jass.common'
    local scope=Scope.new()
    local self={players=players,results={},commands=0,rejected=0,rejections={},stopped=false,departed={}}
    local known={};for _,player in ipairs(players)do known[player]=true end
    local engine={}
    function engine.prepare(unit)
        j.SetUnitAcquireRange(unit.handle,0)
        if test_mode then j.PauseUnit(unit.handle,true)end
    end
    function engine.prepare_boss(unit)j.PauseUnit(unit.handle,true)end
    function engine.life_fraction(unit)return j.GetWidgetLife(unit.handle)/j.GetUnitState(unit.handle,j.UNIT_STATE_MAX_LIFE)end
    function engine.restore(unit,x,y)
        if unit.state=='dead' then assert(j.ReviveHero(unit.handle,x,y,false),'hero restoration failed')end
        j.SetUnitX(unit.handle,x);j.SetUnitY(unit.handle,y)
        j.SetUnitState(unit.handle,j.UNIT_STATE_LIFE,j.GetUnitState(unit.handle,j.UNIT_STATE_MAX_LIFE))
    end
    local ok,err=pcall(function()
        self.units=require('game.unit.service').new(scheduler,nil,on_fault)
        scope:defer(function()local ok,why=self.units:stop();assert(ok,why)end)
        local placements=require 'world.generated_placements'
        self.placed=self.units:register_placements(placements.resolve(j))
        self.combat=require('game.combat.native').new(self.units)
        self.skills=require('game.skill.service').new(self.units,scheduler,self.combat)
        scope:defer(function()local ok,why=self.skills:stop();assert(ok,why)end)
        self.heroes=require('systems.heroes.service').new(self.units,self.skills,players,engine)
        self.challenges=require('systems.challenges.service').new(self.units,scheduler,self.heroes,self.combat,engine,function(session)
            if not self.stopped and not self.departed[session.player] then self.heroes:restore(session.player)end
        end)
        local challenges=self.challenges
        scope:defer(function()local ok,why=challenges:stop();assert(ok,why)end)
        scope:defer(self.units.events:on(function(event,player)
            if event=='player_left' then self:leave_player(player)end
        end))
    end)
    if not ok then self.stopped=true;local clean,why=scope:close();error(tostring(err)..(clean and '' or '\ncleanup: '..tostring(why)),0)end
    local function dispatch(sender,cmd)
        if self.departed[sender] or not known[sender] then return false,'inactive player' end
        local hero=self.heroes.by_id[cmd.entity]
        if not hero then return false,'unknown hero' end
        local unit=self.units:refresh(hero.unit_id)
        if not unit or unit.owner~=sender then return false,'not owner' end
        if cmd.verb=='cast' then
            local encounter=self.challenges:get(sender)
            if not encounter or encounter.boss_id~=cmd.value then return false,'stale target' end
            return self.skills:cast(sender,hero.unit_id,cmd.value)
        elseif cmd.verb=='talent' then
            return Talents.choose(hero,cmd.value,sender,self.units,self.skills)
        elseif cmd.verb=='challenge' then
            if cmd.value~=1 then return false,'unknown challenge' end
            if self.challenges:get(sender) then return false,'already in challenge' end
            self.heroes:restore(sender)
            return self.challenges:start(sender,Training)
        elseif cmd.verb=='leave' then
            return self.challenges:finish(sender,cmd.value,'abandoned')
        end
        return false,'unknown command'
    end
    function self:leave_player(player)
        Context.assert_sync();assert(not self.stopped,'world stopped')
        if not known[player] or self.departed[player] then return false end
        self.departed[player]=true -- Reject requests before cleanup can re-enter any event.
        local errors={}
        local function attempt(fn,...)
            local ok,success,why=pcall(fn,...)
            if not ok then errors[#errors+1]=tostring(success)
            elseif success==false and why then errors[#errors+1]=tostring(why)end
        end
        local encounter=self.challenges:get(player)
        if encounter then attempt(self.challenges.finish,self.challenges,player,encounter.id,'player left')end
        -- Original-party heroes transferred away remain under their current owner's control.
        -- All currently owned units (including managed summons) are retired in stable ID order.
        attempt(self.units.remove_owned_by,self.units,player)
        for _,hero in ipairs(self.heroes.by_player[player] or {})do
            if not self.units:get(hero.unit_id) then self.heroes.by_id[hero.unit_id]=nil end
        end
        self.results[player]=nil
        if #errors>0 then error(table.concat(errors,'\n'),0)end
        return true
    end
    function self:command(sender,cmd)
        Context.assert_sync();assert(not self.stopped,'world stopped')
        local accepted,reason=dispatch(sender,cmd)
        self.commands=self.commands+1
        if not accepted then self.rejected=self.rejected+1;self.rejections[reason]=(self.rejections[reason] or 0)+1 end
        if cmd.seq then
            self.results[sender]={seq=cmd.seq,serial=self.commands,verb=cmd.verb,ok=accepted,reason=type(reason)=='string' and reason or ''}
        end
        return accepted,reason
    end
    function self:snapshot()
        Context.assert_sync();assert(not self.stopped,'world stopped')
        local out={self.units:snapshot(),self.skills:snapshot(),self.challenges:snapshot(),self.commands,self.rejected}
        for _,player in ipairs(players)do
            out[#out+1]=self.departed[player] and 1 or 0
            for _,hero in ipairs(self.heroes.by_player[player])do
                local u=self.units:get(hero.unit_id)
                out[#out+1]=table.concat({hero.unit_id,hero.talent_choice,u and math.floor(j.GetWidgetLife(u.handle)*100) or 0},':')
            end
        end
        return table.concat(out,';')
    end
    function self:stop()
        Context.assert_sync();if self.stopped then return true end;self.stopped=true
        return scope:close()
    end
    return self
end
return M
