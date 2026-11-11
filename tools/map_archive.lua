-- Run with the existing 32-bit YDWE Lua runtime for StormLib Unicode paths.
local runtime, action, target, source, payload = table.unpack(arg)
package.path = runtime .. '/script/common/?.lua;' .. package.path
package.cpath = runtime .. '/bin/modules/?.dll;' .. runtime .. '/bin/?.dll;' .. package.cpath
require 'filesystem'
local storm = require 'ffi.stormlib'
local names = {'war3map.w3e', 'war3map.w3i', 'war3map.wpm', 'war3map.doo', 'war3map.wts', 'war3map.shd'}
if action == 'extract' then
    local map = assert(storm.open(fs.path(source), true))
    for _, name in ipairs(names) do
        if map:has_file(name) then assert(map:extract(name, fs.path(target) / name)) end
    end
    map:close()
    print('Base terrain extracted; original map unchanged')
elseif action == 'pack' then
    assert(not fs.exists(fs.path(target)), 'map already exists')
    local map = assert(storm.create(fs.path(target), 1024))
    local imported = {}
    local function add_tree(path, prefix)
        for child in path:list_directory() do
            local name = prefix .. child:filename():string()
            if fs.is_directory(child) then add_tree(child, name .. '\\')
            else
                assert(map:add_file(name, child), 'import failed: ' .. name)
                imported[#imported + 1] = {name, child}
            end
        end
    end
    add_tree(fs.path(source), '')
    add_tree(fs.path(payload), '')
    map:close()
    map = assert(storm.open(fs.path(target), true))
    for _, entry in ipairs(imported) do
        local f = assert(io.open(entry[2]:string(), 'rb'))
        local bytes = f:read('*a'); f:close()
        assert(map:load_file(entry[1]) == bytes, 'MPQ mismatch: ' .. entry[1])
    end
    assert(not map:has_file('script\\ui\\client\\util.lua'))
    map:close()
    print('MPQ verified files=' .. #imported)
else error('unknown archive action') end
