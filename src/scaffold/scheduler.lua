-- Integer logical ticks; callers choose either a shared or a local clock.
-- A callback error stops this scheduler. It is not a multiplayer recovery policy.
local M = {}
local Context = require 'scaffold.context'
function M.new(domain)
    domain=domain or 'sync'
    assert(domain=='sync' or domain=='local','invalid scheduler domain')
    local function guard() if domain == 'sync' then Context.assert_sync() end end
    local tick, sequence, tasks, stopped, stepping = 0, 0, {}, false, false
    local self = {}
    function self:after(delay, fn, period)
        guard()
        assert(not stopped, 'scheduler stopped')
        assert(type(delay) == 'number' and delay >= 1 and delay % 1 == 0, 'positive integer delay required')
        assert(type(fn) == 'function', 'callback required')
        assert(period == nil or (type(period) == 'number' and period >= 1 and period % 1 == 0), 'invalid period')
        sequence = sequence + 1
        local id = sequence
        local task = {due = tick + delay, fn = fn, period = period}
        tasks[id] = task
        local token = {}
        function token:cancel()
            guard()
            task.fn = nil
            tasks[id] = nil
        end
        function token:get_remaining()
            if not task.fn then return 0 end
            return task.remaining or math.max(0, task.due - tick)
        end
        function token:pause()
            guard()
            if not task.fn or task.remaining then return end
            task.remaining = math.max(1, task.due - tick)
        end
        function token:resume()
            guard()
            if not task.fn or not task.remaining then return end
            task.due, task.remaining = tick + task.remaining, nil
            tasks[id] = task
        end
        return token
    end
    function self:stop()
        guard()
        stopped = true
        for id, task in pairs(tasks) do
            task.fn, tasks[id] = nil, nil
        end
    end
    function self:step()
        guard()
        assert(not stopped, 'scheduler stopped')
        assert(not stepping, 'reentrant scheduler step')
        stepping = true
        tick = tick + 1
        local due = {}
        for id, task in pairs(tasks) do
            if not task.remaining and task.due <= tick then due[#due + 1] = id end
        end
        table.sort(due) -- insertion order; never table/handle identity
        for _, id in ipairs(due) do
            local task = tasks[id]
            -- Earlier callbacks may pause or move another task after due was collected.
            if task and not task.remaining and task.due <= tick then
                local fn = task.fn
                if task.period then task.due = tick + task.period
                else tasks[id], task.fn = nil, nil end
                local ok, err
                if domain=='local' then ok,err=pcall(Context.local_call,fn)
                else ok,err=pcall(fn) end
                if not ok then
                    self:stop()
                    stepping = false
                    error(err, 0)
                end
            end
        end
        stepping = false
    end
    function self:now() return tick end
    return self
end
return M
