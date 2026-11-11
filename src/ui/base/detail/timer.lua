-- Local tasks driven by one shared clock. Milliseconds, rounded up to 10 ms.
local _ENV = require 'scaffold.ui_env'
local Scheduler = require 'scaffold.scheduler'
local queue = Scheduler.new()
game.step = function() queue:step() end
local count = 0
local active = {}
game.stop = function()
    local tokens = {}
    for token in pairs(active) do tokens[#tokens + 1] = token end
    for _, token in ipairs(tokens) do token:remove() end
    queue:stop()
end
game.timer_size = function() return count end
local function schedule(ms, fn, repeat_count)
    assert(type(fn) == 'function', 'UI callback required')
    local ticks = math.max(1, math.ceil(ms / 10))
    local token, done, task = {}, false
    active[token] = true
    count = count + 1
    function token:remove()
        if done then return end
        done = true
        active[token] = nil
        count = count - 1
        task:cancel()
        fn = nil
        local notify = token.on_remove
        token.on_remove = nil
        if notify then notify() end
    end
    token.cancel = token.remove
    function token:pause() task:pause() end
    function token:resume() task:resume() end
    function token:get_remaining() return task:get_remaining() * 10 end
    task = queue:after(ticks, function()
        if done then return end
        local callback = fn
        if repeat_count == 1 then token:remove()
        elseif repeat_count > 1 then repeat_count = repeat_count - 1 end
        callback(token)
    end, ticks)
    return token
end
game.wait = function(ms, fn) return schedule(ms, fn, 1) end
game.loop = function(ms, fn) return schedule(ms, fn, 0) end
game.timer = function(ms, n, fn)
    assert(type(n) == 'number' and n >= 0 and n % 1 == 0)
    return schedule(ms, fn, n)
end
