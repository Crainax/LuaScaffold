local Context = require 'scaffold.context'
local env = require 'scaffold.ui_env'
local M = {}
local started, stopped = false, false
local function initialize()
    require 'ui.base'
    local class, game = env.class, env.game
    local japi = env.japi
    game.add_event_sync = function()
        error('sync_key disabled; send an explicit command through the bridge')
    end
    local old_register = game.register_event
    game.register_event = function(handlers)
        old_register(handlers)
        local active = true
        return function()
            if not active then return end
            active = false
            for i = #game.game_event, 1, -1 do
                if game.game_event[i] == handlers then table.remove(game.game_event, i) end
            end
        end
    end
    local function own_task(self, schedule, ms, fn)
        assert(not self._destroyed and self._id, 'control destroyed')
        self._tasks = self._tasks or {}
        local token
        token = schedule(ms, function(t)
            if not self._destroyed then fn(t) end
            if schedule == game.wait and self._tasks then self._tasks[token] = nil end
        end)
        self._tasks[token] = true
        token.on_remove = function()
            if self._tasks then self._tasks[token] = nil end
        end
        return token
    end
    class.ui_base.wait = function(self, ms, fn) return own_task(self, game.wait, ms, fn) end
    class.ui_base.loop = function(self, ms, fn) return own_task(self, game.loop, ms, fn) end
    class.ui_base.set_time = function(self, seconds)
        if self._life_task then self._life_task:remove() end
        self._life_task = self:wait(seconds * 1000, function() self:destroy() end)
    end
    -- Native children before native parents, including hidden background panels.
    local function destroy(self)
        if self._destroyed or self._destroying then return end
        self._destroying = true
        local owner = rawget(self, '_control')
        if owner and not owner._destroying then destroy(owner) end
        if self._tasks then
            for task in pairs(self._tasks) do task:remove() end
            self._tasks = nil
        end
        if self._timer then self._timer:remove(); self._timer = nil end
        local children = self.children or {}
        for i = #children, 1, -1 do
            local child = children[i]
            if child then destroy(child) end
        end
        if game.release_control then game.release_control(self) end
        local id = rawget(self, '_id')
        if id and id ~= 0 then
            for _, name in ipairs({'panel', 'button', 'text', 'edit', 'model', 'model2', 'texture'}) do
                local map = class[name] and class[name][name .. '_map']
                if map then map[id] = nil end
            end
            japi.DestroyFrame(id)
        end
        self._id = nil
        local background = rawget(self, '_panel')
        if background then destroy(background) end
        local parent = rawget(self, 'parent')
        if parent and parent.children then
            for i = #parent.children, 1, -1 do
                if parent.children[i] == self then table.remove(parent.children, i) end
            end
        end
        class.ui_base._controls[self] = nil
        if self._index then class.ui_base.handle_manager:free(self._index); self._index = nil end
        for key in pairs(self) do
            if key ~= '__index' and key ~= '_destroying' then self[key] = nil end
        end
        self.children, self._destroyed, self._destroying = {}, true, nil
    end
    for _, name in ipairs({'ui_base', 'panel', 'button', 'text', 'texture', 'edit', 'model', 'model2', 'progress'}) do
        class[name].destroy = destroy
    end
    local builder = class.panel.builder
    class.panel.builder = function(cls, params)
        assert(not stopped, 'UI stopped')
        assert(params.sync_key == nil, 'sync_key disabled; use commands')
        assert(not params.parent or not params.parent._destroyed, 'parent destroyed')
        return builder(cls, params)
    end
    local notify, callback = class.ui_base.event_notify, class.ui_base.event_callback
    class.ui_base.event_notify = function(self, name, ...)
        if self._destroyed then return end
        return Context.local_call(notify, self, name, ...)
    end
    class.ui_base.event_callback = function(self, name, ...)
        if self._destroyed then return end
        return Context.local_call(callback, self, name, ...)
    end
    class.ui_base.bind_unit_overhead = function()
        error('legacy ac unit wrapper unavailable; use set_world_position with local view data')
    end
    _G.WindowEventCallBack = function(...)
        if stopped then return false end
        return Context.local_call(env.WindowEventCallBack, ...)
    end
    _G.FrameEventCallBack = function(...)
        if stopped then return end
        return Context.local_call(env.FrameEventCallBack, ...)
    end
    M.class, M.game = class, game
end
function M.start()
    Context.assert_sync()
    assert(not started, 'UI initialization is once per match')
    started = true
    initialize()
    return M
end
function M.step()
    if not stopped then return Context.local_call(M.game.step) end
end
function M.count()
    local n = 0
    for _ in pairs(M.class.ui_base._controls) do n = n + 1 end
    return n
end
function M.stop()
    if stopped then return end
    local list = {}
    for control in pairs(M.class.ui_base._controls) do list[#list + 1] = control end
    table.sort(list, function(a, b) return a._index < b._index end)
    for _, control in ipairs(list) do control:destroy() end
    stopped = true
    M.game.stop()
    M.game.game_event = {}
end
return M
