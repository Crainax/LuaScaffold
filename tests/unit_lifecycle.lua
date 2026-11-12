package.path='src/?.lua;src/?/init.lua;'..package.path
local Manager=require 'game.unit.manager'
local Scheduler=require 'scaffold.scheduler'
local Context=require 'scaffold.context'
local pool,refs={},{}
local next_handle=100
local native={}
function native.info(h) return pool[h] end
function native.ref(h) refs[h]=(refs[h] or 0)+1 end
function native.unref(h) refs[h]=refs[h]-1;assert(refs[h]==0);refs[h]=nil end
function native.remove(h) pool[h]=nil end
function native.create(owner,type_id)
    local h=next_handle;next_handle=next_handle+1
    pool[h]={owner=owner,type_id=type_id,dead=false};return h
end
local scheduler=Scheduler.new();local units=Manager.new(native,scheduler)
local a=units:create(0,123,0,0);local first_id,old_handle=a.id,a.handle
local calls=0;units:after(a.id,1,function() calls=calls+1 end)
pool[a.handle].dead=true;units:refresh(a.id)
assert(a.state=='dead' and units:get(a.id)==a and units:task_count()==0)
scheduler:step();assert(calls==0)
pool[a.handle].dead=false;units:refresh(a.id);assert(a.id==first_id and a.state=='alive')
units:after(a.id,1,function() calls=calls+1 end)
pool[a.handle].owner=1;units:refresh(a.id);scheduler:step();assert(calls==0)
units:after(a.id,1,function() calls=calls+1 end)
pool[a.handle].type_id=456;units:refresh(a.id);scheduler:step();assert(calls==0)
local weak=setmetatable({},{__mode='v'});local payload={};weak[1]=payload
local function callback(value)return function() assert(value) end end
local token=units:after(a.id,10000,callback(payload));payload=nil
weak[2]=a
units:remove(a.id);assert(a.state=='removed' and not a.handle)
a=nil
collectgarbage('collect');collectgarbage('collect');assert(weak[1]==nil and token.fn==nil)
assert(weak[2]==nil,'retained cancelled token must release removed unit record')
-- Deliberately force reuse in the mock; this is NOT native-engine evidence.
next_handle=old_handle
local b=units:create(0,123,0,0)
assert(b.handle==old_handle and b.id>first_id and units:get(first_id)==nil)
units:after(b.id,1,function() calls=calls+1 end);scheduler:step();assert(calls==1 and units:task_count()==0)
native.remove(b.handle);units:refresh(b.id);assert(not units:get(b.id) and not next(refs))
local borrowed=native.create(0,321);local r=units:adopt(borrowed,false)
assert(not pcall(function() units:remove(r.id) end))
assert(not pcall(function() Context.local_call(function() units:create(0,1,0,0) end) end))
assert(units:stop());assert(pool[borrowed] and not next(refs) and units:count()==0)
assert(not pcall(function() units:create(0,1,0,0) end))
scheduler:stop()
local s2=Scheduler.new();local m2=Manager.new(native,s2)
local borrowed2=native.create(0,321)
assert(not pcall(function() m2:register_placements{{key='a',handle=borrowed2},{key='b',handle=borrowed2}} end))
assert(m2:count()==0 and not next(refs))
m2.events:on(function(event,r)
    if event=='created' then m2:after(r.id,1,function() error('must be cancelled') end);error('deliberate creation listener failure') end
end)
assert(not pcall(function() m2:adopt(borrowed2,false) end))
assert(m2:count()==0 and m2:task_count()==0 and not next(refs) and pool[borrowed2])
s2:step();m2:stop();s2:stop()
local service=require 'game.unit.service'
local disconnected=0
native.bind=function()return function()disconnected=disconnected+1;return false,'deliberate disconnect failure' end end
local s3=Scheduler.new();local m3=service.new(s3,native)
m3:create(0,123,0,0)
local stopped,err=m3:stop()
assert(not stopped and err:find('deliberate disconnect failure',1,true))
assert(disconnected==1 and m3:count()==0 and not next(refs))
assert(m3:stop() and disconnected==1);s3:stop()
print('UNIT MOCK PASS death/revive/form/owner invalidation, forced handle reuse, callback release, external removal, borrowed ownership and sync guard')
