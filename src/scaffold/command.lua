-- Deliberately narrow wire format: no load(), handles, nested tables or floats.
-- Sender identity MUST come from the transport, never from this payload.
local M = {}
local MAX = 2147483647
local function uint(v)
    return type(v) == 'number' and v >= 0 and v <= MAX and v % 1 == 0
end
function M.encode(seq, verb, entity, value)
    assert(uint(seq) and seq > 0, 'invalid sequence')
    assert(type(verb) == 'string' and #verb <= 24 and verb:match('^[a-z][a-z_]*$'), 'invalid verb')
    assert(uint(entity) and uint(value), 'invalid command arguments')
    return ('LS1|%d|%s|%d|%d'):format(seq, verb, entity, value)
end
function M.decode(raw)
    if type(raw) ~= 'string' or #raw > 128 then return nil, 'invalid size' end
    local seq, verb, entity, value = raw:match('^LS1|([0-9]+)|([a-z_]+)|([0-9]+)|([0-9]+)$')
    seq, entity, value = tonumber(seq), tonumber(entity), tonumber(value)
    if not uint(seq) or seq == 0 or not uint(entity) or not uint(value) or not verb then
        return nil, 'invalid fields'
    end
    local ok, canonical = pcall(M.encode, seq, verb, entity, value)
    if not ok or canonical ~= raw then return nil, 'noncanonical command' end
    return {seq = seq, verb = verb, entity = entity, value = value}
end
function M.receiver(handlers, authorize)
    assert(type(authorize) == 'function', 'authorization validator required')
    local last = {}
    return function(sender, raw)
        if not uint(sender) or sender > 15 then return false, 'invalid sender' end
        local cmd, err = M.decode(raw)
        if not cmd then return false, err end
        local handler = handlers[cmd.verb]
        if type(handler) ~= 'function' then return false, 'unknown command' end
        if cmd.seq <= (last[sender] or 0) then return false, 'duplicate or stale' end
        -- Validation must be deterministic, side-effect free and non-yielding.
        if not authorize(sender, cmd) then return false, 'not authorized' end
        last[sender] = cmd.seq
        handler(sender, cmd) -- caller owns fail-stop and diagnostics on errors
        return true
    end
end
return M
