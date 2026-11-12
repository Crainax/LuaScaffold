package.path='src/?.lua;src/?/init.lua;'..package.path
local callback,refreshes,faults,destroyed,removed,refs= nil,0,0,0,0,0
local event=5
local j={EVENT_PLAYER_UNIT_DEATH=1,EVENT_PLAYER_UNIT_CHANGE_OWNER=2,EVENT_PLAYER_HERO_REVIVE_FINISH=3,EVENT_PLAYER_UNIT_SUMMON=4,EVENT_PLAYER_LEAVE=5}
function j.CreateTrigger()return 99 end
function j.Player(i)return i end
function j.TriggerRegisterPlayerUnitEvent()end
function j.TriggerRegisterPlayerEvent()end
function j.GetTriggerPlayer()return 3 end
function j.GetPlayerId(p)return p end
function j.TriggerAddAction(_,fn)callback=fn;return 17 end
function j.TriggerRemoveAction()removed=removed+1 end
function j.DestroyTrigger()destroyed=destroyed+1 end
function j.GetTriggerEventId()return event end
function j.GetTriggerUnit()return 42 end
package.loaded['jass.common']=j
package.loaded['jass.debug']={handle_ref=function()refs=refs+1 end,handle_unref=function()refs=refs-1 end}
local manager={find=function()return {id=1}end,refresh=function()refreshes=refreshes+1;error('controlled native dispatch failure')end}
local left=0;manager.events={emit=function(_,kind,player)assert(kind=='player_left' and player==3);left=left+1 end}
local close=require('game.unit.native').bind(manager,function(why)
    faults=faults+1;assert(why:find('controlled native dispatch failure',1,true))
end)
assert(pcall(callback) and left==1);event=1
assert(not pcall(callback) and refreshes==1 and faults==1)
assert(pcall(callback) and refreshes==1 and faults==1)
assert(close() and close() and removed==1 and destroyed==1 and refs==0)
assert(pcall(callback) and refreshes==1)
print('NATIVE UNIT BRIDGE MOCK PASS fault mutes dispatch and still releases action/trigger exactly once')
