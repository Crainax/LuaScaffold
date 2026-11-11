-- Explicit ownership. Never use __gc to destroy synchronized game resources.
local M = {}
function M.new()
    local closed, cleanups = false, {}
    local self = {}
    function self:defer(fn)
        assert(type(fn) == 'function', 'cleanup must be a function')
        assert(not closed, 'scope is closed')
        cleanups[#cleanups + 1] = fn
        return fn
    end
    function self:is_closed() return closed end
    function self:close()
        if closed then return true end
        closed = true
        local errors = {}
        for i = #cleanups, 1, -1 do
            local fn = cleanups[i]
            cleanups[i] = nil
            local ok, err = pcall(fn)
            if not ok then errors[#errors + 1] = tostring(err) end
        end
        if #errors > 0 then return false, table.concat(errors, '\n') end
        return true
    end
    return self
end
return M
