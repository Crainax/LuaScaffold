-- IDs are assigned ONLY in a shared, deterministic creation order.
-- Never call register() while enumerating an unordered engine group.
local M = {}
local Context = require 'scaffold.context'
function M.new()
    local next_id, by_id, by_handle = 0, {}, {}
    local self = {}
    function self:register(handle)
        Context.assert_sync()
        assert(handle ~= nil and handle ~= 0, 'invalid handle')
        assert(not by_handle[handle], 'handle already registered')
        assert(next_id < 2147483647, 'entity IDs exhausted')
        next_id = next_id + 1
        local record = {id = next_id, handle = handle, alive = true}
        by_id[next_id], by_handle[handle] = record, record
        return record
    end
    function self:get(id) return by_id[id] end
    function self:find(handle) return by_handle[handle] end
    function self:remove(id)
        Context.assert_sync()
        local record = by_id[id]
        if not record then return false end
        by_handle[record.handle], by_id[id] = nil, nil
        record.handle, record.alive = nil, false
        return true
    end
    return self
end
return M
