-- Stable object identity is distinct from native life, form and ownership.
local Context=require 'scaffold.context'
local Registry=require 'scaffold.entity_registry'
local Events=require 'scaffold.events'
local M={}
local function keys(t)
    local out={};for id in pairs(t) do out[#out+1]=id end;table.sort(out);return out
end
function M.new(native,scheduler)
    local registry,records=Registry.new(),{}
    local stopped,job_sequence=false,0
    local self={events=Events.new('sync')}
    local function guard() Context.assert_sync();assert(not stopped,'unit manager stopped') end
    local function cancel_jobs(r)
        for _,id in ipairs(keys(r.jobs)) do r.jobs[id]:cancel() end
    end
    local function invalidate_life(r)
        r.epoch=r.epoch+1
        for _,id in ipairs(keys(r.jobs)) do if r.jobs[id].life then r.jobs[id]:cancel() end end
    end
    local function release(r,destroy)
        if not records[r.id] then return false end
        local handle=r.handle
        -- Invalidate first: native RemoveUnit may synchronously fire callbacks.
        records[r.id]=nil;registry:remove(r.id)
        r.state='removed';r.handle=nil;r.epoch=r.epoch+1
        cancel_jobs(r)
        local errors={}
        local function attempt(fn,...)
            local ok,err=pcall(fn,...);if not ok then errors[#errors+1]=tostring(err) end
        end
        attempt(r.events.emit,r.events,'removed',r)
        attempt(self.events.emit,self.events,'removed',r)
        r.events:clear()
        if destroy then attempt(native.remove,handle) end
        attempt(native.unref,handle)
        if #errors>0 then error(table.concat(errors,'\n'),0) end
        return true
    end
    function self:adopt(handle,owned,key)
        guard()
        assert(not registry:find(handle),'unit already registered')
        local info=assert(native.info(handle),'cannot adopt absent unit')
        native.ref(handle)
        local ok,entry=pcall(registry.register,registry,handle)
        if not ok then native.unref(handle);error(entry,0) end
        local r={id=entry.id,handle=handle,owned=not not owned,key=key,state=info.dead and 'dead' or 'alive',
            type_id=info.type_id,owner=info.owner,epoch=1,jobs={},events=Events.new('sync')}
        records[r.id]=r
        local announced,err=pcall(self.events.emit,self.events,'created',r)
        if not announced then
            local clean,why=pcall(release,r,false)
            error(tostring(err)..(clean and '' or '\ncleanup: '..tostring(why)),0)
        end
        return r
    end
    function self:create(owner,type_id,x,y,facing)
        guard()
        local handle=native.create(owner,type_id,x,y,facing or 0)
        local ok,r=pcall(self.adopt,self,handle,true)
        if not ok then
            -- adopt can notify a listener after registration; release any partially registered record.
            local entry=registry:find(handle)
            if entry then release(records[entry.id],true) else native.remove(handle) end
            error(r,0)
        end
        return r
    end
    function self:get(id) return records[id] end
    function self:find(handle)
        local entry=registry:find(handle);return entry and records[entry.id]
    end
    function self:refresh(id)
        guard()
        local r=records[id];if not r then return nil end
        local info=native.info(r.handle)
        if not info then release(r,false);return nil end
        local state=info.dead and 'dead' or 'alive'
        local changes={}
        if r.state~=state then changes[#changes+1]=state=='dead' and 'death' or 'revived' end
        if r.type_id~=info.type_id then changes[#changes+1]='form' end
        if r.owner~=info.owner then changes[#changes+1]='owner' end
        if #changes>0 then
            invalidate_life(r)
            r.state,r.type_id,r.owner=state,info.type_id,info.owner
            for _,event in ipairs(changes) do
                if not records[id] then break end
                r.events:emit(event,r)
                self.events:emit(event,r)
            end
        end
        return records[id]
    end
    function self:refresh_all()
        guard();for _,id in ipairs(keys(records)) do self:refresh(id) end
    end
    function self:remove(id)
        guard();local r=records[id];if not r then return false end
        assert(r.owned,'borrowed unit must be detached, not destroyed')
        return release(r,true)
    end
    function self:detach(id)
        guard();local r=records[id];return r and release(r,false) or false
    end
    function self:remove_owned_by(player)
        guard();local errors={}
        for _,id in ipairs(keys(records)) do
            local r=self:refresh(id)
            if r and r.owned and r.owner==player then
                local ok,err=pcall(release,r,true)
                if not ok then errors[#errors+1]=tostring(err) end
            end
        end
        if #errors>0 then return false,table.concat(errors,'\n') end
        return true
    end
    function self:after(id,ticks,fn,life)
        guard();assert(type(fn)=='function','unit callback required')
        local r=assert(self:refresh(id),'unit removed')
        life=life~=false
        assert(not life or r.state=='alive','life task requires live unit')
        local epoch=r.epoch
        job_sequence=job_sequence+1;local key=job_sequence
        local job={life=life,fn=fn};local task;local owner=r
        function job:cancel()
            Context.assert_sync();self.fn=nil
            if owner then owner.jobs[key]=nil;owner=nil end
            if task then task:cancel() end
        end
        task=scheduler:after(ticks,function()
            local callback,expected=job.fn,owner
            job:cancel()
            local current=self:refresh(id)
            if current and current==expected and (not life or (current.epoch==epoch and current.state=='alive')) then callback(current) end
        end)
        r.jobs[key]=job
        return job
    end
    function self:register_placements(list)
        guard();local seen,handles={},{}
        -- The explicit source order, never a native enumeration, establishes IDs.
        for _,p in ipairs(list) do
            assert(type(p.key)=='string' and not seen[p.key],'duplicate placement key')
            assert(native.info(p.handle) and not registry:find(p.handle),'invalid placement')
            assert(not handles[p.handle],'duplicate placement handle')
            seen[p.key]=true;handles[p.handle]=true
        end
        local out={}
        local adopted={}
        local ok,err=pcall(function()
            for _,p in ipairs(list) do
                local r=self:adopt(p.handle,p.owned,p.key);out[p.key]=r;adopted[#adopted+1]=r
            end
        end)
        if not ok then
            for i=#adopted,1,-1 do pcall(release,adopted[i],false) end
            error(err,0)
        end
        return out
    end
    function self:snapshot()
        guard();self:refresh_all();local out={}
        for _,id in ipairs(keys(records)) do
            local r=records[id]
            out[#out+1]=table.concat({r.id,r.type_id,r.owner,r.state,r.epoch},':')
        end
        return table.concat(out,'|')
    end
    function self:count() local n=0;for _ in pairs(records) do n=n+1 end;return n end
    function self:task_count() local n=0;for _,r in pairs(records) do for _ in pairs(r.jobs) do n=n+1 end end;return n end
    function self:stop()
        Context.assert_sync();if stopped then return true end
        stopped=true
        local errors={}
        for _,id in ipairs(keys(records)) do
            local r=records[id];local ok,err=pcall(release,r,r.owned)
            if not ok then errors[#errors+1]=tostring(err) end
        end
        self.events:clear()
        if #errors>0 then return false,table.concat(errors,'\n') end
        return true
    end
    return self
end
return M
