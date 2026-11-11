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
package.loaded['jass.common']={InitHashtable=function() return 10 end,GetPlayerId=function() return 0 end,GetLocalPlayer=function() return 1 end}
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
local clip=c.panel:builder{x=100,y=100,w=100,h=100,is_scroll=true,not_scroll_button=true}
local child=c.button:builder{parent=clip,x=0,y=80,w=80,h=50}
assert(child:point_in_rect(110,190) and not child:point_in_rect(110,220))
clip:set_scroll_y(12.5)
local x,y=child:get_real_position()
assert(y==167.5 and child:point_in_rect(110,190) and not child:point_in_rect(110,210))
local nested=c.panel:builder{parent=clip,x=0,y=10,w=50,h=50,clip_children=true}
local nested_child=c.button:builder{parent=nested,x=0,y=45,w=40,h=30}
local nx,ny=nested_child:get_real_position()
assert(nested_child:point_in_rect(nx+5,ny+2) and not nested_child:point_in_rect(nx+5,ny+10))
clip:destroy()
local broken=setmetatable({build=function(self) self._id=japi.CreateFrameByTagName('','',1);error('expected construction failure') end},{__index=c.panel})
assert(not pcall(function() broken:builder{x=0,y=0,w=20,h=20} end))
assert(ui.count()==0 and not next(frames))
local scroll=c.panel:builder{x=100,y=100,w=200,h=200,is_scroll=true,not_scroll_button=true}
local nested_scroll=c.panel:builder{parent=scroll,x=10,y=10,w=100,h=100,is_scroll=true,not_scroll_button=true}
c.panel:builder{parent=nested_scroll,x=0,y=300,w=30,h=30}
c.panel:builder{parent=scroll,x=0,y=500,w=30,h=30}
function japi.GetMouseVectorX() return 130/1920*1024 end
function japi.GetWheelDelta() return -1 end
-- Native mouse Y is measured from the top in this adapter.
function japi.GetMouseVectorY() return 768-130/1080*768 end
WindowEventCallBack(6)
assert(nested_scroll.scroll_y==10 and scroll.scroll_y==0)
scroll:hide();WindowEventCallBack(6)
assert(nested_scroll.scroll_y==10 and scroll.scroll_y==0)
scroll:destroy()
local off=ui.game.register_event({on_init=function() calls=calls+1 end})
off();off();ui.step()
assert(calls==0)
assert(not pcall(function() c.button:builder{sync_key='unsafe'} end))
assert(_G.class==nil and math.abs(math.sin(math.pi/2)-1)<1e-9)
local weak = setmetatable({}, {__mode='v'})
require('probes.hotreload').run(ui,{send=function() end},function(ok,name) assert(ok,name) end)
local retained
do
    local payload = {}; weak[1] = payload
    retained = ui.game.wait(100000, function() return payload end)
end
ui.stop(); ui.stop()
assert(not pcall(function() ui.game.wait(10,function() end) end))
assert(not pcall(function() ui.game.register_event({on_probe=function() end}) end))
assert(ui.game.timer_size()==0 and ui.game.events:count()==0)
collectgarbage('collect'); collectgarbage('collect')
assert(weak[1] == nil and ui.game.timer_size() == 0)
retained:remove()
print('UI MOCK PASS 100 nested lifecycles, child-first destruction, closure release, unregister and isolation')
