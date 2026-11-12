package.path='src/?.lua;src/?/init.lua;'..package.path
local trace={}
local function mark(s)trace[#trace+1]=s end
package.loaded['app.config']={ui=true,runtime_test=false}
package.loaded['jass.log']={info=function()end}
package.loaded['jass.common']={Player=function(p)return p end,MAP_CONTROL_USER=1,PLAYER_SLOT_STATE_PLAYING=1,
    GetPlayerController=function(p)return p==0 and 1 or 0 end,GetPlayerSlotState=function()return 1 end}
package.loaded['scaffold.innerjapi']={start=function()
    mark('bridge start')
    return {scheduler={},stop=function()mark('bridge stop');return true end}
end}
package.loaded['world.session']={start=function()
    mark('world start')
    return {stop=function()mark('world stop');return true end}
end}
package.loaded['scaffold.ui']={start=function()mark('ui start');error('controlled UI start failure')end,
    stop=function()mark('ui stop');error('controlled UI stop failure')end}
local app=require 'app.main'
local ok,why=pcall(app.start)
assert(not ok and why:find('controlled UI start failure',1,true) and why:find('controlled UI stop failure',1,true))
assert(table.concat(trace,',')=='bridge start,world start,ui start,world stop,ui stop,bridge stop')
assert(app.world==nil and app:stop())
local n=#trace;assert(not pcall(app.start) and #trace==n)
print('APP MOCK PASS failed initialization attempts all cleanup, preserves errors and refuses unsupported whole-app restart')
