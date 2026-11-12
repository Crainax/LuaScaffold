package.path='src/?.lua;src/?/init.lua;'..package.path
local Scheduler=require 'scaffold.scheduler'
local Manager=require 'game.unit.manager'
local pool,refs,effects={}, {}, {}
local next_id=100
local function fresh()next_id=next_id+1;return next_id end
local native={}
function native.create(owner,type_id,x,y)
    local id=fresh();local max=owner==12 and 180 or 600
    pool[id]={owner=owner,type_id=type_id,x=x,y=y,dead=false,life=max,max=max};return id
end
function native.info(h)return pool[h]end
function native.remove(h)pool[h]=nil end
function native.ref(h)assert(not refs[h]);refs[h]=true end
function native.unref(h)assert(refs[h]);refs[h]=nil end
package.loaded['game.unit.service']={new=function(scheduler)return Manager.new(native,scheduler)end}
package.loaded['world.generated_placements']={resolve=function()return{}end}
package.loaded['jass.debug']={handle_ref=native.ref,handle_unref=native.unref}
package.loaded['jass.common']={
    Player=function(p)return p end,
    SetUnitAcquireRange=function()end,PauseUnit=function()end,
    IsUnitEnemy=function(h,player)return pool[h].owner~=player end,
    GetUnitX=function(h)return pool[h].x end,GetUnitY=function(h)return pool[h].y end,
    SetUnitX=function(h,x)pool[h].x=x end,SetUnitY=function(h,y)pool[h].y=y end,
    GetWidgetLife=function(h)return pool[h].life end,
    UNIT_STATE_LIFE=1,UNIT_STATE_MAX_LIFE=2,
    GetUnitState=function(h,k)return k==2 and pool[h].max or pool[h].life end,
    SetUnitState=function(h,_,v)pool[h].life=v end,
    ReviveHero=function(h)pool[h].dead=false;pool[h].life=pool[h].max;return true end,
    AddSpecialEffectTarget=function()local h=fresh();effects[h]=true;return h end,
    DestroyEffect=function(h)assert(effects[h]);effects[h]=nil end,
    UnitDamageTarget=function(_,h,amount)
        pool[h].life=pool[h].life-amount;if pool[h].life<=0 then pool[h].dead=true end;return true
    end,
}
local scheduler=Scheduler.new()
local world=require('world.session').start(scheduler,{0,1},true)
local function step(n)for _=1,n do scheduler:step()end end
local function command(player,verb,index,value)
    return world:command(player,{verb=verb,entity=world.heroes.by_player[player][index].unit_id,value=value})
end
local party=world.heroes.by_player[0]
assert(world.units:count()==6 and world.skills:count()==6)
for i=1,3 do assert(command(0,'talent',i,1))end
assert(world.skills:get(party[1].unit_id).definition.damage==75)
assert(world.skills:get(party[2].unit_id).definition.hits==4)
assert(world.skills:get(party[3].unit_id).definition.hits==4)
assert(not command(0,'talent',1,2))
assert(command(0,'challenge',1,1))
local session=world.challenges:get(0);local generation=session.id
local hero=world.units:get(party[1].unit_id)
local state=world.skills:get(hero.id);state.energy=42;pool[hero.handle].life=50
assert(not command(0,'challenge',1,1))
assert(state.energy==42 and pool[hero.handle].life==50,'rejected repeated start cannot restore resources')
assert(not command(0,'leave',1,generation+1) and world.challenges:get(0)==session)
local accepted,reason=world:command(1,{verb='cast',entity=hero.id,value=session.boss_id})
assert(not accepted and reason=='not owner')
world.heroes:restore(0)
for i=1,3 do assert(command(0,'cast',i,session.boss_id))end
step(100)
assert(world.challenges.completed[0]==1 and not world.challenges:get(0))
assert(world.combat.effects==0 and not next(effects) and world.skills:active_count()==0)
assert(not command(0,'leave',1,generation))
assert(world.challenges.completed[0]==1)
assert(command(0,'challenge',1,1))
session=world.challenges:get(0)
assert(not command(0,'cast',2,session.boss_id),'starting a new challenge must not reset cooldown')
step(210)
assert(command(0,'cast',2,session.boss_id))
assert(world:stop());step(400)
assert(world.units:count()==0 and world.skills:count()==0 and world.challenges:count()==0 and not next(refs) and not next(effects))
assert(not pcall(function()command(0,'challenge',1,1)end))
scheduler:stop()
-- Defeat and timeout are mock coverage, separate from native victory/abandon/removal probes.
local second=Scheduler.new()
local next_world=require('world.session').start(second,{0},true)
assert(next_world.challenges:start(0,require 'content.challenges.training.definition'))
local doomed=next_world.challenges:get(0)
pool[next_world.units:get(doomed.boss_id).handle].life=80
for _,h in ipairs(next_world.heroes.by_player[0])do pool[next_world.units:get(h.unit_id).handle].life=1 end
for _=1,40 do second:step()end
assert(doomed.phase==2 and doomed.state=='defeat' and not next_world.challenges:get(0))
assert(not next_world.challenges.completed[0] and next_world.heroes:alive(0)==3)
assert(next_world.challenges:start(0,require 'content.challenges.training.definition'))
local timed=next_world.challenges:get(0)
for _=1,2000 do second:step()end
assert(timed.state=='timeout' and not next_world.challenges:get(0) and not next_world.challenges.completed[0])
local j=package.loaded['jass.common'];local pause=j.PauseUnit
j.PauseUnit=function()error('controlled boss preparation failure')end
local prepared,why=pcall(next_world.challenges.start,next_world.challenges,0,require 'content.challenges.training.definition')
j.PauseUnit=pause
assert(not prepared and why:find('controlled boss preparation failure',1,true))
assert(next_world.units:count()==3 and next_world.challenges:count()==0 and next_world.units:task_count()==0)
assert(next_world.challenges:start(0,require 'content.challenges.training.definition'))
local departing=next_world.challenges:get(0)
local first=next_world.heroes.by_player[0][1].unit_id
assert(next_world.skills:cast(0,first,departing.boss_id))
local summon=next_world.units:create(0,123,0,0)
local borrowed=native.create(0,123,0,0);next_world.units:adopt(borrowed,false)
local transferred=next_world.units:get(next_world.heroes.by_player[0][3].unit_id)
pool[transferred.handle].owner=1;next_world.units:refresh(transferred.id)
next_world.units.events:emit('player_left',0) -- Simulated engine notification, not a real network departure.
assert(departing.state=='player left' and next_world.challenges:count()==0)
assert(next_world.units:count()==2 and next_world.skills:count()==1 and next_world.combat.effects==0)
assert(not next_world.units:get(summon.id) and pool[borrowed] and next_world.units:get(transferred.id))
local accepted,reason=next_world:command(0,{verb='cast',entity=first,value=departing.boss_id})
assert(not accepted and reason=='inactive player' and not next_world:leave_player(0))
assert(next_world:stop() and not next(refs) and not next(effects));second:stop()
assert(pool[borrowed]);native.remove(borrowed)
print('WORLD MOCK PASS talents, ownership, atomicity, victory, cooldown, defeat/timeout, preparation failure, simulated player departure and shutdown')
