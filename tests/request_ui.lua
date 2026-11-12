package.path='src/?.lua;src/?/init.lua;'..package.path
local timers,update={},nil
local controls={}
local function builder()
    local c={}
    controls[#controls+1]=c
    function c:set_text(s)self.text=s end
    function c:wait(ms,fn)
        local t={fn=fn,ms=ms};function t:remove()self.fn=nil end
        timers[#timers+1]=t;return t
    end
    function c:loop(_,fn)update=fn end
    function c:destroy()for _,t in ipairs(timers)do t:remove()end end
    return c
end
local ui={class={panel={builder=builder},text={builder=builder},button={builder=builder}}}
package.loaded['jass.common']={GetPlayerId=function()return 0 end,GetLocalPlayer=function()return 0 end,
    GetUnitX=function()return 0 end,GetUnitY=function()return 0 end,PanCameraToTimed=function()end,ClearSelection=function()end,SelectUnit=function()end}
local sequence,full=0,false
local bridge={scheduler={now=function()return 0 end}}
function bridge:send()if full then return false,'outgoing queue full' end;sequence=sequence+1;return true,sequence end
local hero={unit_id=1,talent_choice=0,definition=require 'content.heroes.reimu.definition'}
local world={heroes={by_player={[0]={hero}}},units={get=function()return{handle=1}end},
    skills={get=function()return{cooldown_until=0,energy=100,max_energy=100}end},
    challenges={get=function()end,completed={}},results={}}
local view=require('presentation.challenge_view').start(ui,bridge,world)
view.buttons.start:on_button_clicked();assert(view.request.seq==1 and view.request.status=='queued')
world.results[0]={seq=0,ok=true};update();assert(view.request.status=='queued')
world.results[0]={seq=1,ok=true};update();assert(view.request.status=='business_succeeded' and timers[1].fn==nil)
view.buttons.start:on_button_clicked();view.buttons.start:on_button_clicked()
assert(timers[2].fn==nil and view.request.seq==3)
world.results[0]={seq=2,ok=true};update();assert(view.request.status=='queued','older result cannot confirm a newer request')
assert(timers[3].ms==10000);timers[3].fn();assert(view.request.status=='unconfirmed' and sequence==3,'timeout must not retry or imply failure')
world.results[0]={seq=3,ok=false,reason='already in challenge'};update();assert(view.request.status=='business_rejected')
for i=4,5 do
    view.buttons.start:on_button_clicked();assert(controls[5].text:find('等待执行结果',1,true))
    world.results[0]={seq=i,ok=true};update()
    assert(view.request.status=='business_succeeded' and controls[5].text:find('已完成操作',1,true),'identical successive results must replace the queued status text')
end
full=true;view.buttons.start:on_button_clicked();update();assert(view.request.status=='not_queued' and sequence==5)
view:stop()
print('REQUEST UI MOCK PASS sequence correlation, old result isolation, bounded waiting, late rejection, no automatic retry and queue refusal')
