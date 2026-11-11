-- A development boundary, not a sandbox against direct native calls.
local M = {}
local domain = 'sync'
function M.assert_sync()
    assert(domain == 'sync', 'gameplay mutation from local UI context')
end
function M.local_call(fn, ...)
    local previous = domain
    domain = 'local'
    local result = table.pack(pcall(fn, ...))
    domain = previous
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end
return M
