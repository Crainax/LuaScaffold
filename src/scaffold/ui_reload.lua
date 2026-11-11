-- Transactional local view replacement. Does not reload the renderer or gameplay modules.
local Scope=require 'scaffold.scope'
local Context=require 'scaffold.context'
local M={}
local function copy_state(value,seen)
    local kind=type(value)
    if kind=='nil' or kind=='string' or kind=='boolean' or kind=='number' then return value end
    assert(kind=='table','view state must contain only data')
    seen=seen or {};assert(not seen[value],'cyclic view state unsupported');seen[value]=true
    local copy={}
    for k,v in pairs(value) do
        assert(type(k)=='string' or type(k)=='number','invalid state key')
        copy[k]=copy_state(v,seen)
    end
    seen[value]=nil;return copy
end
function M.new(ui,bridge,enabled)
    local current,stopped,faulted=nil,false,false
    local self={}
    function self:reload(factory)
        assert(enabled and not stopped and not faulted,'view reload unavailable')
        return Context.local_call(function()
            local scope=Scope.new()
            local candidate={scope=scope,active=false}
            local ok,err=pcall(function()
                candidate.state=copy_state(current and current.state or {})
                candidate.root=ui.class.panel:builder{x=0,y=0,w=1920,h=1080,is_show=false}
                assert(candidate.root,'view root creation failed')
                scope:defer(function() candidate.root:destroy() end)
                local ctx={state=candidate.state}
                function ctx:create(kind,params)
                    assert(kind~='ui_base' and ui.class[kind],'unsupported control')
                    local args={};for k,v in pairs(params or {}) do args[k]=v end
                    args.parent=args.parent or candidate.root
                    local owner=args.parent
                    while owner and owner~=candidate.root do owner=owner.parent end
                    assert(owner==candidate.root,'view cannot own controls outside its root')
                    local control=ui.class[kind]:builder(args)
                    assert(control,'view control creation failed')
                    return control
                end
                function ctx:on(handlers)
                    local wrapped={}
                    for name,fn in pairs(handlers) do
                        wrapped[name]=function(...) if candidate.active then return fn(...) end end
                    end
                    local off=ui.game.register_event(wrapped);scope:defer(off);return off
                end
                function ctx:wait(ms,fn) return candidate.root:wait(ms,function(t) if candidate.active then fn(t) end end) end
                function ctx:loop(ms,fn) return candidate.root:loop(ms,function(t) if candidate.active then fn(t) end end) end
                function ctx:send(...) assert(candidate.active,'inactive view');return bridge:send(...) end
                factory(ctx)
                copy_state(candidate.state) -- validate state before committing
            end)
            if not ok then
                local clean,cleanup_error=scope:close()
                if not clean then faulted=true;err=tostring(err)..'; cleanup: '..cleanup_error end
                return false,tostring(err)
            end
            local previous=current
            candidate.active=true;candidate.root:show();current=candidate
            if previous then
                previous.active=false
                local clean,cleanup_error=previous.scope:close()
                if not clean then faulted=true;return false,'old view cleanup failed: '..cleanup_error end
            end
            return true
        end)
    end
    function self:state() return current and copy_state(current.state) end
    function self:stop()
        if stopped then return true end
        stopped=true
        if not current then return true end
        current.active=false
        local old=current;current=nil
        return Context.local_call(function() return old.scope:close() end)
    end
    return self
end
return M
