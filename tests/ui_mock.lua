package.path = 'src/?.lua;src/?/init.lua;' .. package.path
local frames, next_frame, files = {}, 100, {}
local japi = setmetatable({}, {__index=function(_, key)
    return function() return 0 end
end})
function japi.GetGameUI() return 1 end
function japi.FrameGetParent() return 1 end
function japi.CreateFrameByTagName(_, _, parent)
    next_frame = next_frame + 1
    frames[next_frame] = {parent=parent, text='', width=0, height=0}
    return next_frame
end
function japi.FrameAddModel(parent) return japi.CreateFrameByTagName('', '', parent) end
function japi.DestroyFrame(id)
    assert(frames[id], 'double native frame destruction')
    for _, frame in pairs(frames) do assert(frame.parent ~= id, 'native child outlived its parent') end
    frames[id] = nil
end
function japi.FrameSetText(id, text) assert(frames[id]); frames[id].text=text end
function japi.FrameGetText(id) return frames[id].text end
function japi.FrameSetSize(id, w, h) frames[id].width=w; frames[id].height=h end
function japi.FrameSetWidth(id, v) frames[id].width=v end
function japi.FrameSetHeight(id, v) frames[id].height=v end
function japi.FrameGetWidth(id) return frames[id].width end
function japi.FrameGetHeight(id) return frames[id].height end
function japi.GetTargetObject() return nil end
function japi.IsWindowActive() return true end
package.loaded['jass.japi']=japi
package.loaded['jass.common']={InitHashtable=function() return 10 end}
package.loaded['jass.log']={info=function() end,error=error}
package.loaded['jass.runtime']={error_handle=error}
package.loaded['jass.hook']={}
package.loaded['jass.debug']={}
package.loaded['jass.message']={}
package.loaded['jass.storm']={save=function(p,data) files[p]=data end,load=function(p) return files[p] or '' end}
local ui=require('scaffold.ui').start()
local c=ui.class
for i=1,100 do
    local p=c.panel:builder {x=10,y=10,w=500,h=400}
    local b=c.button:builder {parent=p,x=0,y=0,w=32,h=32}
    local t=c.text:builder {parent=p,x=0,y=40,w=100,h=30,text='hello'}
    local e=c.edit:builder {parent=p,x=0,y=80,w=100,h=30,text='edit'}
    local m=c.model:builder {parent=p,x=0,y=120,w=50,h=50,model='Units\\Human\\Footman\\Footman.mdx'}
    local scroll=c.panel:builder {parent=p,x=100,y=80,w=50,h=50,is_scroll=true}
    scroll:set_scroll_y(0)
    assert(scroll.scroll_y == 0)
    assert(t:get_text()=='hello' and e:get_text()=='edit')
    local weak=setmetatable({},{__mode='v'})
    local function capture()
        local payload={}; weak[1]=payload
        b:loop(100000,function() return payload end)
    end
    capture()
    p:destroy(); b:destroy(); p:destroy()
    collectgarbage('collect'); collectgarbage('collect')
    assert(weak[1]==nil and ui.count()==0 and not next(frames))
end
local calls=0
local off=ui.game.register_event({on_init=function() calls=calls+1 end})
off();off();ui.step()
assert(calls==0)
assert(not pcall(function() c.button:builder{sync_key='unsafe'} end))
assert(_G.class==nil and math.abs(math.sin(math.pi/2)-1)<1e-9)
local weak = setmetatable({}, {__mode='v'})
local retained
do
    local payload = {}; weak[1] = payload
    retained = ui.game.wait(100000, function() return payload end)
end
ui.stop(); ui.stop()
collectgarbage('collect'); collectgarbage('collect')
assert(weak[1] == nil and ui.game.timer_size() == 0)
retained:remove()
print('UI MOCK PASS 100 nested lifecycles, child-first destruction, closure release, unregister and isolation')
