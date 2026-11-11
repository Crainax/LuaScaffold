package.path = 'src/?.lua;' .. package.path
local Scope = require 'scaffold.scope'
local Registry = require 'scaffold.entity_registry'
local Scheduler = require 'scaffold.scheduler'
local Command = require 'scaffold.command'
local count = 0
local function check(name, fn)
    fn()
    count = count + 1
    print('PASS ' .. name)
end
check('cleanup is reverse ordered, idempotent and continues after error', function()
    local s, seen = Scope.new(), {}
    s:defer(function() seen[#seen + 1] = 1 end)
    s:defer(function() seen[#seen + 1] = 2; error('expected') end)
    s:defer(function() seen[#seen + 1] = 3 end)
    local ok, err = s:close()
    assert(not ok and err:find('expected'))
    assert(table.concat(seen) == '321')
    assert(s:close() and #seen == 3)
    assert(not pcall(function() s:defer(function() end) end))
end)
check('different local handles have the same logical IDs', function()
    local a, b = Registry.new(), Registry.new()
    for i = 1, 10 do
        assert(a:register(100 + i).id == b:register(900 + i).id)
    end
    local old = a:get(1)
    assert(a:remove(1) and not a:get(1) and not old.alive and old.handle == nil)
    assert(a:register(101).id == 11) -- same native handle value, new lifetime
    assert(not pcall(function() a:register(101) end))
end)
check('timer cancellation releases captured data while token stays alive', function()
    local s, weak = Scheduler.new(), setmetatable({}, {__mode = 'v'})
    local function make()
        local payload = {}
        weak[1] = payload
        return s:after(100000, function() return payload end)
    end
    local token = make()
    collectgarbage('collect'); assert(weak[1])
    token:cancel()
    collectgarbage('collect'); collectgarbage('collect')
    assert(weak[1] == nil and token)
end)
check('timer dispatch has fixed order and handles cancellation and nesting', function()
    local s, order = Scheduler.new(), {}
    local second
    s:after(1, function()
        order[#order + 1] = 'a'
        second:cancel()
        s:after(1, function() order[#order + 1] = 'c' end)
    end)
    second = s:after(1, function() order[#order + 1] = 'b' end)
    s:step(); assert(table.concat(order) == 'a')
    s:step(); assert(table.concat(order) == 'ac')
end)
check('callback failure stops subsequent gameplay callbacks', function()
    local s, reached = Scheduler.new(), false
    s:after(1, function() error('expected callback error') end)
    s:after(1, function() reached = true end)
    assert(not pcall(function() s:step() end))
    assert(not reached and not pcall(function() s:step() end))
end)
check('wire decoder rejects execution, invalid values, holes and oversize', function()
    local raw = Command.encode(1, 'buy_item', 14, 3)
    local cmd = assert(Command.decode(raw))
    assert(cmd.seq == 1 and cmd.entity == 14 and cmd.value == 3)
    for _, bad in ipairs({'print"bad"', 'LS1|01|ping|0|0', 'LS1|1|ping|nan|0',
        'LS1|1|ping|0|0|extra', 'LS1|1|ping|2147483648|0', string.rep('x', 129)}) do
        assert(not Command.decode(bad), bad)
    end
    assert(not Command.decode({}))
    assert(not pcall(Command.encode, 1, 'ping', {}, 0))
end)
check('sender validation, authorization, duplicate rejection and player isolation', function()
    local calls = 0
    local rx = Command.receiver({ping = function() calls = calls + 1 end},
        function(sender, cmd) return sender < 2 and cmd.entity == 0 and cmd.value == 0 end)
    local raw = Command.encode(1, 'ping', 0, 0)
    assert(rx(0, raw)); assert(not rx(0, raw)); assert(rx(1, raw))
    assert(not rx(2, raw) and not rx(99, raw))
    assert(not rx(0, Command.encode(2, 'cheat', 0, 0)))
    assert(not rx(0, Command.encode(2, 'ping', 99, 0)))
    assert(calls == 2)
end)
check('Lua cycles collect; an external registry keeps a closure alive', function()
    local weak, registry = setmetatable({}, {__mode = 'v'}), {}
    local function make()
        local owner = {}
        owner.callback = function() return owner end
        registry[1], weak[1] = owner.callback, owner
    end
    make(); collectgarbage('collect'); assert(weak[1])
    registry[1] = nil
    collectgarbage('collect'); collectgarbage('collect'); assert(not weak[1])
end)
check('paused tasks resume deterministically and stop releases their captures', function()
    local s, calls = Scheduler.new(), 0
    local t = s:after(3, function() calls=calls+1 end)
    s:step(); t:pause(); s:step(); s:step(); assert(calls==0 and t:get_remaining()==2)
    t:resume(); s:step(); assert(calls==0); s:step(); assert(calls==1)
    local weak=setmetatable({},{__mode='v'})
    local function make()
        local payload={}; weak[1]=payload
        return s:after(100, function() return payload end)
    end
    local paused=make(); paused:pause(); s:stop()
    collectgarbage('collect');collectgarbage('collect');assert(not weak[1])
end)
check('local callbacks cannot enqueue synchronized gameplay', function()
    local sync = Scheduler.new('sync')
    assert(not pcall(function()
        require('scaffold.context').local_call(function() sync:after(1, function() end) end)
    end))
    sync:after(1, function() end);sync:step()
end)
print(('OFFLINE PASS %d cases; native engine and multiplayer not exercised'):format(count))
