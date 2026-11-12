-- Read the final map with the existing StormLib host; never modify it.
local runtime,map_path,payload,script_output,source_map=table.unpack(arg)
package.path=runtime..'/script/common/?.lua;'..package.path
package.cpath=runtime..'/bin/modules/?.dll;'..runtime..'/bin/?.dll;'..package.cpath
require 'filesystem'
local map=assert(require('ffi.stormlib').open(fs.path(map_path),true))
local count=0
local function walk(path,prefix)
    for p in path:list_directory() do
        local name=prefix..p:filename():string()
        if fs.is_directory(p) then walk(p,name..'\\') else
            local f=assert(io.open(p:string(),'rb'));local bytes=f:read('*a');f:close()
            assert(map:load_file(name)==bytes,'final payload changed: '..name)
            count=count+1
        end
    end
end
walk(fs.path(payload),'')
if source_map then
    for _,name in ipairs{'war3mapUnits.doo','war3map.w3r','war3map.w3e','war3map.wpm','war3map.doo','war3map.shd'} do
        local f=assert(io.open(source_map..'/'..name,'rb'));local bytes=f:read('*a');f:close()
        assert(map:load_file(name)==bytes,'map initialization resource changed: '..name)
    end
end
local j=assert(map:load_file('war3map.j'))
local f=assert(io.open(script_output,'wb'));f:write(j);f:close()
assert(not map:has_file('script\\ui\\client\\util.lua'))
map:close()
print('FINAL PAYLOAD BYTE CHECK PASS '..count..' files and map initialization resources')
