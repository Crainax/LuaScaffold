-- Compare effective object fields after both inputs pass through the pinned frontend.
-- This covers OBJ and SLK storage without assuming war3map.w3u must exist.
local root,source,packed=table.unpack(arg)
package.path=root..'/script/?.lua;'..root..'/script/?/init.lua;'..package.path
package.cpath=root..'/bin/?.dll;'..package.cpath
local fs=require 'bee.filesystem'
fs.current_path(fs.path(root)/'script');require 'utility'
local core=require 'backend.sandbox_core'
local config=require 'share.config'
local builder=require 'map-builder'
local lni=require 'lni'
local errors=0
local msg={text=function()end,title=function()end,progress=function()end}
function msg.report(kind,level,message)
    if level==1 then errors=errors+1;print('[OBJECT_ERROR] '..message) end
end
local function load(path)
    local w=core()
    w:set_messager(msg)
    local settings={mode='lni',read_slk=true,extra_check=true}
    for k,v in pairs(config.global) do settings[k]=v end
    w:set_setting(settings)
    w.input_ar=assert(builder.load(fs.path(path)))
    if fs.is_directory(fs.path(path)) then w.input_mode='lni' end
    w.progress:start(1)
    local data={};w:frontend(data);w.progress:finish()
    return data
end
local expected=load(source)
local actual=load(packed)
assert(errors==0,'object parser reported errors')
local fields,objects=0,0
local function equal(a,b,path)
    if type(a)=='number' and type(b)=='string' then b=assert(tonumber(b),path..' nonnumeric object real') end
    if (a=='' and b==nil) or (a==nil and b=='') then return end -- absent/empty TXT field
    if type(a)=='number' and type(b)=='number' then
        if math.type(a)=='integer' then assert(a==b,path..' integer mismatch')
        else assert(math.abs(a-b)<=0.00001*math.max(1,math.abs(a)),path..' float mismatch') end
    elseif type(a)=='table' then
        assert(type(b)=='table',path..' missing table')
        for k,v in pairs(a) do equal(v,b[k],path..'['..tostring(k)..']') end
        for k,v in pairs(b) do if a[k]==nil then equal(nil,v,path..'['..tostring(k)..']') end end
    else assert(a==b,path..' mismatch expected='..tostring(a)..' actual='..tostring(b)) end
end
for _,kind in ipairs{'unit','ability','buff','item','upgrade','doodad','destructable'} do
    local file=io.open(source..'/table/'..kind..'.ini','rb')
    if file then
        local ids=lni(file:read('a'));file:close()
        for id in pairs(ids) do
            local a=assert(expected[kind][id],'source object missing: '..id)
            local b=assert(actual[kind][id],'packed object missing: '..id)
            objects=objects+1
            for key,value in pairs(a) do
                if key:sub(1,1)~='_' then
                    equal(value,b[key],kind..'.'..id..'.'..key);fields=fields+1
                end
            end
            for key,value in pairs(b) do
                if key:sub(1,1)~='_' and a[key]==nil then equal(nil,value,kind..'.'..id..'.'..key) end
            end
        end
    end
end
assert(objects>0,'no declared objects checked')
print(string.format('OBJECT SEMANTIC PASS objects=%d fields=%d (float32 tolerance=1e-5 relative)',objects,fields))
