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
-- Nested local boundaries preserve nil returns, error identity and the caller's domain.
local marker={}
local values=table.pack(Context.local_call(function()
    local ok,err=pcall(Context.local_call,function() error(marker,0) end)
    assert(not ok and err==marker)
    assert(not pcall(Context.assert_sync),'caught nested error escaped local domain')
    return Context.local_call(function(...) return ... end,1,nil,3,nil)
end))
assert(values.n==4 and values[1]==1 and values[2]==nil and values[3]==3 and values[4]==nil)
Context.assert_sync()
local ok,err=pcall(Context.local_call,function()
    Context.local_call(function() error(marker,0) end)
end)
assert(not ok and err==marker);Context.assert_sync()
ok,err=Context.local_try(function() error(marker,0) end)
assert(not ok and err==marker);Context.assert_sync()
Context.local_call(function()
    local success,why=Context.local_try(function() error(marker,0) end)
    assert(not success and why==marker and not pcall(Context.assert_sync))
end)
Context.assert_sync()

local local_events=Events.new('local')
local delivered=0
local_events:on(function(...)
    local args=table.pack(...)
    assert(args.n==3 and args[1]=='payload' and args[2]==nil and args[3]==7)
    delivered=delivered+1
    return true
end)
local_events:on(function() delivered=delivered+1;return false end)
assert(local_events:emit('payload',nil,7)==true and delivered==2)
local_events:clear();Context.assert_sync()

-- A failed local event must unwind depth/compact removals, including nested dispatch.
for _,nested in ipairs{false,true} do
    local events=Events.new('local')
    local off,off_later,entered
    local seen={}
    off=events:on(function()
        assert(not pcall(Context.assert_sync))
        if nested and not entered then entered=true;events:emit() end
        off();off_later()
        events:on(function() seen[#seen+1]='new' end)
        error(marker,0)
    end)
    off_later=events:on(function() error('later listener ran') end)
    local success,why=pcall(events.emit,events)
    assert(not success and why==marker);Context.assert_sync()
    assert(events:count()==1)
    events:emit();assert(table.concat(seen)=='new')
    events:clear()
end

-- Failure stops later tasks and releases captures even when already in a local domain.
for _,already_local in ipairs{false,true} do
    local queue=require('scaffold.scheduler').new('local')
    local weak=setmetatable({},{__mode='v'})
    queue:after(1,function() error(marker,0) end)
    local token
    do local payload={};weak[1]=payload;token=queue:after(1,function() error(payload) end,1) end
    local function step()
        local success,why=pcall(queue.step,queue)
        assert(not success and why==marker)
        assert(not pcall(queue.step,queue),'failed scheduler resumed')
        assert(token:get_remaining()==0)
    end
    if already_local then Context.local_call(step) else step() end
    Context.assert_sync()
    collectgarbage('collect');collectgarbage('collect');assert(not weak[1])
end
print('EXTENDED PASS events mutation/error/domain, local boundary restoration, ac repeat/pause/stop capture release')
