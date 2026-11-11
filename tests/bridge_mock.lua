package.path = 'src/?.lua;' .. package.path
local refs, live, actions, tick, on_message = {}, {}, {}, nil, nil
local next_handle, raw, sender = 1000, '', 0
local function create(kind)
    next_handle = next_handle + 1
    live[next_handle] = kind
    return next_handle
end
local runtime = {}
local jass = {
    CreateTrigger = function() return create('trigger') end,
    DestroyTrigger = function(h) assert(live[h] == 'trigger'); live[h] = nil end,
    TriggerAddAction = function(h, fn) actions[h] = fn; on_message = fn; return 99 end,
    TriggerRemoveAction = function(h, a) assert(a == 99); actions[h] = nil end,
    CreateTimer = function() return create('timer') end,
    PauseTimer = function(h) assert(live[h] == 'timer') end,
    DestroyTimer = function(h) live[h] = nil end,
    TimerStart = function(_, _, _, fn) tick = fn end,
    GetPlayerId = function(p) return p end,
}
local sent
package.loaded['jass.runtime'] = runtime
package.loaded['jass.common'] = jass
package.loaded['jass.japi'] = {
    SetOwner = function() end,
    SendCustomMessage = function(value) sent = value end,
    RegisterMessageEvent = function() end,
    GetTriggerMessage = function() return raw end,
    GetMessagePlayer = function() return sender end,
}
package.loaded['jass.debug'] = {
    handle_ref = function(h) refs[h] = (refs[h] or 0) + 1 end,
    handle_unref = function(h) refs[h] = refs[h] - 1 end,
}
package.loaded['jass.log'] = {error = function() end}
local applied = 0
local bridge = require('scaffold.innerjapi').start({ping = function(p)
    assert(p == 2); applied = applied + 1
end}, function(p, cmd) return p == 2 and cmd.entity == 0 and cmd.value == 0 end)
assert(runtime.handle_level == 0 and runtime.sleep == false)
bridge:send('ping', 0, 0)
assert(applied == 0) -- local send MUST NOT apply gameplay immediately
for _=1,10 do tick() end
raw, sender = sent, 2
on_message(); on_message(); assert(applied == 1)
local ticks = 0
bridge.scheduler:after(1, function() ticks = ticks + 1 end)
tick(); assert(ticks == 1)
bridge.scheduler:after(1, function() error('fault probe') end)
tick(); assert(bridge:is_faulted())
assert(next(live)) -- fault does not locally destroy native handles
assert(bridge:stop()); assert(bridge:stop())
assert(not next(live) and not next(actions))
for _, n in pairs(refs) do assert(n == 0) end
tick(); on_message(); assert(applied == 1)
print('BRIDGE MOCK PASS transport boundary, fault state, balanced refs and idempotent teardown')
