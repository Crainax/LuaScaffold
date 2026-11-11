-- Ordered listeners; additions during dispatch start next dispatch, removals are immediate.
local Context=require 'scaffold.context'
local M={}
function M.new(domain)
    domain=domain or 'sync'
    assert(domain=='sync' or domain=='local','invalid event domain')
    local list, depth, dirty, count={},0,false,0
    local function guard() if domain=='sync' then Context.assert_sync() end end
    local function compact()
        if depth~=0 or not dirty then return end
        local n=0
        for i=1,#list do if list[i].fn then n=n+1;list[n]=list[i] end end
        for i=#list,n+1,-1 do list[i]=nil end
        dirty=false
    end
    local self={}
    function self:on(fn)
        guard();assert(type(fn)=='function','listener required')
        local record={fn=fn};list[#list+1]=record;count=count+1
        return function()
            guard()
            if record.fn then record.fn=nil;count=count-1;dirty=true;compact() end
        end
    end
    function self:emit(...)
        guard();depth=depth+1
        local limit=#list
        local result=false
        local function dispatch(...)
            for i=1,limit do
                local fn=list[i].fn
                if fn then local value=fn(...);result=result or not not value end
            end
        end
        local ok,err
        if domain=='local' then ok,err=pcall(Context.local_call,dispatch,...)
        else ok,err=pcall(dispatch,...) end
        depth=depth-1;compact()
        if not ok then error(err,0) end
        return result
    end
    function self:clear()
        guard()
        for _,record in ipairs(list) do record.fn=nil end
        count=0;dirty=true;compact()
    end
    function self:count() return count end
    return self
end
return M
