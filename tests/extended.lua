package.path='src/?.lua;'..package.path
local Context=require 'scaffold.context'
local Events=require 'scaffold.events'
local e,seen=Events.new('sync'),{}
local off1,off2
off1=e:on(function() seen[#seen+1]='a';off1();off2();e:on(function() seen[#seen+1]='c' end) end)
off2=e:on(function() error('removed listener ran') end)
e:emit();e:emit();assert(table.concat(seen)=='ac' and e:count()==1)
e:clear();assert(e:count()==0)
local off=e:on(function() error('expected') end)
assert(not pcall(function() e:emit() end));off();e:emit()
assert(not pcall(function() Context.local_call(function() e:on(function() end) end) end))
local s=require('scaffold.scheduler').new('sync')
local ac=require('scaffold.ac').new({scheduler=s})
local n=0
local t=ac.timer(15,3,function() n=n+1 end)
assert(t:get_remaining()==20);s:step();t:pause();s:step();assert(n==0)
t:resume();for _=1,5 do s:step() end;assert(n==3 and t:get_remaining()==0)
local weak=setmetatable({},{__mode='v'})
local retained
do local object={};weak[1]=object;retained=ac.loop(1000,function() return object end) end
s:stop();collectgarbage('collect');collectgarbage('collect');assert(not weak[1]);retained:remove()
local local_queue=require('scaffold.scheduler').new('local')
local_queue:after(1,function() Context.assert_sync() end)
assert(not pcall(function() local_queue:step() end))
local mutation=require('scaffold.scheduler').new('sync')
local pending,runs
runs=0
mutation:after(1,function() pending:pause();pending:resume() end)
pending=mutation:after(1,function() runs=runs+1 end)
mutation:step();assert(runs==0,'rescheduled due task ran in old dispatch batch')
mutation:step();assert(runs==1);mutation:stop()
local paused=require('scaffold.scheduler').new('sync')
paused:after(1,function() pending:pause() end)
pending=paused:after(1,function() error('paused due task ran') end)
paused:step();paused:stop()
print('EXTENDED PASS events mutation/error/domain, ac repeat/pause/stop capture release')
