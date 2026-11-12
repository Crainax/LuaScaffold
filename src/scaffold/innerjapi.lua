local Refs=require 'scaffold.handle_refs'
-- Engine bridge for the pinned InnerJAPI 1.49-9 runtime.
-- start/stop must be called on ALL clients, outside local UI branches.
local Scope = require 'scaffold.scope'
local Scheduler = require 'scaffold.scheduler'
local Command = require 'scaffold.command'
local M = {}
local Context = require 'scaffold.context'
function M.start(handlers, authorize)
    Context.assert_sync()
    local runtime = require 'jass.runtime'
    runtime.handle_level = 0
    runtime.sleep = false
    local jass = require 'jass.common'
    local japi = require 'jass.japi'
    local dbg = require 'jass.debug'
    local log = require 'jass.log'
    for _, name in ipairs({'SetOwner', 'SendCustomMessage', 'RegisterMessageEvent', 'GetTriggerMessage', 'GetMessagePlayer'}) do
        assert(type(japi[name]) == 'function', 'InnerJAPI missing: ' .. name)
    end
    assert(type(dbg.handle_ref) == 'function' and type(dbg.handle_unref) == 'function', 'handle reference API missing')
    local scope, scheduler = Scope.new(), Scheduler.new('sync')
    local receive = Command.receiver(handlers, authorize)
    local sequence, active, faulted = 0, true, false
    local outgoing, send_tick = {}, 0
    local self = {scheduler = scheduler,transport={accepted=0,rejected=0,reasons={}}}
    local function fail(err)
        faulted = true
        scheduler:stop()
        log.error('FAIL: [LuaScaffold] FAULT', tostring(err), debug.traceback())
        -- Do not destroy synchronized handles from a possibly local error callback.
    end
    local function protect(fn)
        local ok, err = pcall(fn)
        if not ok then fail(err) end
    end
    function self:stop()
        Context.assert_sync()
        if not active then return true end
        active = false
        outgoing = {}
        scheduler:stop()
        return scope:close()
    end
    function self:is_faulted() return faulted end
    function self:abort(err)
        Context.assert_sync()
        if not faulted then fail(err)end
    end
    function self:send(verb, entity, value)
        assert(active and not faulted, 'bridge inactive')
        if #outgoing >= 32 then return false, 'outgoing queue full' end
        local message = Command.encode(sequence + 1, verb, entity, value)
        sequence = sequence + 1 -- local-only counter, isolated from gameplay IDs
        outgoing[#outgoing + 1] = message
        return true,sequence
    end
    local ok, err = pcall(function()
        local trigger = jass.CreateTrigger()
        assert(trigger ~= nil and trigger ~= 0, 'CreateTrigger failed')
        Refs.ref('trigger',trigger)
        scope:defer(function()
            jass.DestroyTrigger(trigger)
            Refs.unref('trigger',trigger)
        end)
        japi.RegisterMessageEvent(trigger)
        local action = jass.TriggerAddAction(trigger, function()
            if not active or faulted then return end
            protect(function()
                local raw = japi.GetTriggerMessage()
                if type(raw) ~= 'string' or raw:sub(1, 4) ~= 'LS1|' then return end
                local sender = jass.GetPlayerId(japi.GetMessagePlayer())
                local accepted,reason=receive(sender, raw)
                if accepted then self.transport.accepted=self.transport.accepted+1
                else
                    self.transport.rejected=self.transport.rejected+1
                    self.transport.reasons[reason]=(self.transport.reasons[reason] or 0)+1
                    if self.transport.reasons[reason]<=3 then log.info('[COMMAND_REJECT]',reason)end
                end
            end)
        end)
        scope:defer(function() jass.TriggerRemoveAction(trigger, action) end)
        local timer = jass.CreateTimer()
        assert(timer ~= nil and timer ~= 0, 'CreateTimer failed')
        Refs.ref('timer',timer)
        scope:defer(function()
            jass.PauseTimer(timer)
            jass.DestroyTimer(timer)
            Refs.unref('timer',timer)
        end)
        jass.TimerStart(timer, 0.01, true, function()
            if active and not faulted then protect(function()
                send_tick = send_tick + 1
                if send_tick % 10 == 0 and #outgoing > 0 then
                    japi.SendCustomMessage(table.remove(outgoing, 1))
                end
                scheduler:step()
            end) end
        end)
    end)
    if not ok then self:stop(); error(err, 0) end
    return self
end
return M
