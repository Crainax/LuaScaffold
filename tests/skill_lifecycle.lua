package.path='src/?.lua;src/?/init.lua;'..package.path
local Scheduler=require 'scaffold.scheduler'
local Units=require 'game.unit.manager'
local Skills=require 'game.skill.service'
local Context=require 'scaffold.context'
local scheduler=Scheduler.new()
local pool,refs={},{};local next_handle=100
local native={}
function native.create(owner,type_id,x,y)
    next_handle=next_handle+1;pool[next_handle]={owner=owner,type_id=type_id,dead=false,x=x,y=y,life=1000};return next_handle
end
function native.info(h)return pool[h]end
function native.remove(h)pool[h]=nil end
function native.ref(h)refs[h]=true end
function native.unref(h)assert(refs[h]);refs[h]=nil end
local units=Units.new(native,scheduler)
local effects,damage=0,0
local weak=setmetatable({},{__mode='v'})
local combat={}
function combat.is_enemy(a,b)return a.owner~=b.owner end
function combat.in_range(a,b,r)return math.abs(pool[a.handle].x-pool[b.handle].x)<=r end
function combat.effect()
    effects=effects+1;local payload={};weak[1]=payload
    return function()assert(payload);effects=effects-1 end
end
function combat.damage(_,target,value)
    damage=damage+value;local p=pool[target.handle];p.life=p.life-value
    if p.life<=0 then p.dead=true;units:refresh(target.id)end
end
local skills=Skills.new(units,scheduler,combat)
local definition={key='sample',cost=20,cooldown=10,windup=2,interval=2,hits=3,damage=10,range=500}
local function step(n)for _=1,n do scheduler:step()end end
local function pair()
    local a=units:create(0,123,0,0);local b=units:create(1,321,100,0)
    local s=skills:register(a.id,definition,100)
    return a,b,s
end
local function clear(a,b)
    units:remove(a.id);units:remove(b.id)
    assert(skills:count()==0 and skills:active_count()==0 and effects==0 and units:task_count()==0)
end
local a,b,s=pair()
assert(not skills:cast(1,a.id,b.id) and s.energy==100)
assert(not skills:cast(0,a.id,a.id) and s.energy==100)
pool[b.handle].x=1000;assert(not skills:cast(0,a.id,b.id));pool[b.handle].x=100
assert(skills:cast(0,a.id,b.id) and s.energy==80 and effects==1)
local retained_cast=s.cast
assert(not skills:cast(0,a.id,b.id))
step(6);assert(damage==30 and effects==0 and not s.cast and units:task_count()==0)
collectgarbage('collect');collectgarbage('collect');assert(weak[1]==nil and retained_cast.scope:is_closed())
assert(not skills:cast(0,a.id,b.id));step(4)
assert(skills:cast(0,a.id,b.id));pool[a.handle].dead=true;units:refresh(a.id)
step(6);assert(damage==30 and effects==0 and s.energy==60)
clear(a,b)
for _,kind in ipairs{'removed','owner','form'}do
    a,b,s=pair();assert(skills:cast(0,a.id,b.id))
    if kind=='removed' then units:remove(b.id)
    elseif kind=='owner' then pool[a.handle].owner=1;units:refresh(a.id)
    else pool[a.handle].type_id=456;units:refresh(a.id)end
    step(6);assert(damage==30 and not s.cast and effects==0 and s.energy==80)
    clear(a,b)
end
a,b,s=pair();assert(skills:cast(0,a.id,b.id));pool[b.handle].x=1000
step(6);assert(damage==30 and not s.cast and effects==0);clear(a,b)
a,b,s=pair();pool[b.handle].life=5
assert(skills:cast(0,a.id,b.id));step(6)
assert(damage==40 and not s.cast and effects==0,'reentrant death must close remaining channel work')
local old_id,old_handle=b.id,b.handle;units:remove(b.id);next_handle=old_handle-1
local replacement=units:create(1,321,100,0)
assert(replacement.handle==old_handle and replacement.id~=old_id)
step(4);assert(not skills:cast(0,a.id,old_id) and s.energy==80)
clear(a,replacement)
a,b,s=pair()
local good_effect=combat.effect
combat.effect=function()error('deliberate effect preparation failure')end
assert(not pcall(function()skills:cast(0,a.id,b.id)end))
assert(s.energy==100 and s.cooldown_until==0 and not s.cast and effects==0 and units:task_count()==0)
assert(a.events:count()==1 and b.events:count()==0,'failed preparation must remove cast listeners')
combat.effect=good_effect
assert(not pcall(function()Context.local_call(function()skills:cast(0,a.id,b.id)end)end))
assert(skills:cast(0,a.id,b.id));assert(skills:stop());step(6)
assert(skills:count()==0 and effects==0 and damage==40)
assert(not pcall(function()skills:register(a.id,definition)end))
units:stop();scheduler:stop();assert(not next(refs))
print('SKILL MOCK PASS commit/cooldown/ownership/range, death/form/owner/removal cancellation, reused handle, reentrant kill and preparation cleanup')
