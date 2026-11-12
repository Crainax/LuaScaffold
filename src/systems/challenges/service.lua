-- Common encounter lifecycle. Specific bosses live in content/challenges/.
local Context=require 'scaffold.context'
local Scope=require 'scaffold.scope'
local Arenas=require 'world.arenas'
local M={}
function M.new(units,scheduler,heroes,combat,engine,on_end)
    local sessions,sequence,stopped={},0,false
    local self={completed={},started=0,ended=0}
    local function finish(player,reason)
        local s=sessions[player];if not s then return false end
        sessions[player]=nil;s.state=reason;self.ended=self.ended+1
        if reason=='victory' then self.completed[player]=(self.completed[player] or 0)+1 end
        local ok,err=s.scope:close()
        local notified,why=pcall(on_end,s,reason)
        if not notified then error((ok and '' or tostring(err)..'\n')..tostring(why),0)end
        if not ok then error(err,0)end
        return true
    end
    function self:get(player)return sessions[player]end
    function self:finish(player,id,reason)
        Context.assert_sync();assert(not stopped,'challenge service stopped')
        local s=sessions[player];if not s or s.id~=id then return false,'stale session' end
        return finish(player,reason or 'abandoned')
    end
    function self:start(player,definition)
        Context.assert_sync();assert(not stopped,'challenge service stopped')
        if sessions[player] then return false,'already in challenge' end
        if not heroes.by_player[player] or heroes:alive(player)==0 then return false,'no live party' end
        local scope=Scope.new()
        sequence=sequence+1
        local s={id=sequence,player=player,scope=scope,state='active',phase=1,pulses=0}
        local ok,err=pcall(function()
            local p=Arenas.for_player(player)
            local boss=units:create(12,string.unpack('>I4',definition.rawcode),p.x,p.y+350,270)
            s.boss_id=boss.id
            scope:defer(function()units:remove(boss.id)end)
            engine.prepare_boss(boss)
            scope:defer(boss.events:on(function(event)
                if event=='death' then finish(player,'victory')
                elseif event=='removed' then finish(player,'boss removed')end
            end))
            local pulse=scheduler:after(definition.first_pulse,function()
                definition.boss.pulse(s,units,heroes,combat,engine)
                if sessions[player]==s and heroes:alive(player)==0 then finish(player,'defeat')end
            end,definition.pulse_interval)
            scope:defer(function()pulse:cancel()end)
            local timeout=scheduler:after(definition.duration,function()finish(player,'timeout')end)
            scope:defer(function()timeout:cancel()end)
        end)
        if not ok then
            local clean,why=scope:close()
            error(tostring(err)..(clean and '' or '\ncleanup: '..tostring(why)),0)
        end
        sessions[player]=s;self.started=self.started+1
        return true,s
    end
    function self:count()local n=0;for _ in pairs(sessions)do n=n+1 end;return n end
    function self:snapshot()
        local out={}
        for player=0,15 do
            local s=sessions[player]
            out[#out+1]=table.concat({player,self.completed[player] or 0,s and s.id or 0,s and s.boss_id or 0,s and s.phase or 0,s and s.pulses or 0},':')
        end
        return table.concat(out,'|')
    end
    function self:stop()
        Context.assert_sync();if stopped then return true end;stopped=true
        local errors={}
        for player=0,15 do local ok,err=pcall(finish,player,'shutdown');if not ok then errors[#errors+1]=tostring(err)end end
        if #errors>0 then return false,table.concat(errors,'\n')end
        return true
    end
    return self
end
return M
