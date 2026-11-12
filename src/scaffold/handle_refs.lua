-- Framework-owned explicit references only, NOT the engine's global ref count.
-- Numeric handle keys are diagnostic bookkeeping; never iterate them for gameplay.
local Context=require 'scaffold.context'
local M={}
local kinds={'unit','effect','trigger','timer'}
function M.new(native)
    local held,stats={},{}
    for _,kind in ipairs(kinds)do
        held[kind]={};stats[kind]={refs=0,unrefs=0,active=0,peak=0,errors=0}
    end
    local self={}
    local function validate(kind,handle)
        Context.assert_sync()
        assert(stats[kind],'unknown reference kind')
        assert(type(handle)=='number' and handle>0 and handle%1==0,'level-0 handle required')
        return stats[kind],held[kind]
    end
    local function invoke(fn,handle,s)
        local ok,err=pcall(fn,handle)
        if not ok then s.errors=s.errors+1;error(err,0)end
    end
    function self.ref(kind,handle)
        local s,h=validate(kind,handle)
        invoke(native.handle_ref,handle,s)
        h[handle]=(h[handle] or 0)+1
        s.refs=s.refs+1;s.active=s.active+1;s.peak=math.max(s.peak,s.active)
    end
    function self.unref(kind,handle)
        local s,h=validate(kind,handle)
        if not h[handle] then s.errors=s.errors+1;error('unmatched handle_unref: '..kind,0)end
        invoke(native.handle_unref,handle,s)
        h[handle]=h[handle]>1 and h[handle]-1 or nil
        s.unrefs=s.unrefs+1;s.active=s.active-1
    end
    function self.snapshot()
        local out={active=0,refs=0,unrefs=0,errors=0,kinds={}}
        for _,kind in ipairs(kinds)do
            local s=stats[kind]
            out.kinds[kind]={refs=s.refs,unrefs=s.unrefs,active=s.active,peak=s.peak,errors=s.errors}
            for _,key in ipairs{'active','refs','unrefs','errors'}do out[key]=out[key]+s[key]end
        end
        return out
    end
    return self
end
local instance
local function current()
    if not instance then instance=M.new(require 'jass.debug')end
    return instance
end
function M.ref(kind,handle)return current().ref(kind,handle)end
function M.unref(kind,handle)return current().unref(kind,handle)end
function M.snapshot()return current().snapshot()end
return M
