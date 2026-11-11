-- Execute original Lua modules in an isolated mock environment, never in Warcraft.
-- A PASS means a reported upstream issue was reproduced, not that it is safe.
local root = 'vendor/war3ui-1.49-9/package/plugin/script/'
local function env()
    local e = setmetatable({}, {__index = _G})
    e._G = e
    e.load = function(chunk) return load(chunk, 'upstream-audit', 't', e) end
    e.game = {loop = function() end}
    e.ac = {table = {}}
    e.japi = {SendCustomMessage = function(msg) e.sent = msg end}
    e.log = {error = function(msg) error(msg) end}
    return e
end
local e = env()
local ui = assert(loadfile(root .. 'ui/client/util.lua', 't', e))()
local invoked = false
e.audit_probe = function() invoked = true; return {} end
ui.decode('audit_probe "harmless offline marker"')
assert(invoked)
print('REPRODUCED decoder executes a function without parentheses')
ui.send({type = 'sync', func_name = 'on_sync', params = {string.rep('x', 700)}})
assert(e.sent == '{}')
print('REPRODUCED oversized first event becomes an empty message')
local mixed = {11, label = 'lost'}
local decoded = assert(ui.decode(ui.encode(mixed)))
assert(decoded[1] == 11 and decoded.label == nil)
print('REPRODUCED mixed array/map loses named fields')
assert(load('return ' .. ui.encode({['end'] = 1})) == nil)
print('REPRODUCED keyword table key emits invalid Lua')
local te = env()
te.ac = {}
local native_tick
te.require = function(name)
    if name == 'jass.common' then
        return {CreateTimer = function() return 1 end,
            TimerStart = function(_, _, _, fn) native_tick = fn end}
    elseif name == 'jass.debug' then return {handle_ref = function() end} end
    error(name)
end
assert(loadfile(root .. 'ac/timer.lua', 't', te))()
local weak = setmetatable({}, {__mode = 'v'})
local function schedule()
    local object = {}; weak[1] = object
    return te.ac.wait(600000, function() return object end)
end
local task = schedule(); task:remove(); task = nil
collectgarbage('collect'); collectgarbage('collect')
assert(weak[1])
print('REPRODUCED cancelled long timer retains captured object in its queue')
local me = env(); me.math = {}
for k, v in pairs(math) do me.math[k] = v end
assert(loadfile(root .. 'ac/math.lua', 't', me))()
assert(math.abs(me.math.sin(90) - 1) < 1e-9)
assert(math.abs(me.math.sin(math.pi / 2) - 1) > 0.9)
print('REPRODUCED ac.math changes standard trigonometry to degrees')
print('UPSTREAM AUDIT PASS 6 reproduced behaviors; no native engine calls')
