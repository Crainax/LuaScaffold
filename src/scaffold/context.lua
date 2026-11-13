-- A development boundary, not a sandbox against direct native calls.
local M = {}
local domain = 'sync'
function M.assert_sync()
    assert(domain == 'sync', 'gameplay mutation from local UI context')
end
function M.local_call(fn, ...)
    -- An outer boundary already owns restoration; preserve all return values.
    if domain == 'local' then return fn(...) end
    local previous = domain
    domain = 'local'
    local result = table.pack(pcall(fn, ...))
    domain = previous
    if not result[1] then error(result[2], 0) end
    return table.unpack(result, 2, result.n)
end
-- Internal dispatch boundary. Callers only need status/error, not callback results.
-- Keep protection even inside local_call: dispatchers must run their own cleanup.
function M.local_try(fn, ...)
    local previous = domain
    domain = 'local'
    local ok, err = pcall(fn, ...)
    domain = previous
    return ok, err
end
return M
