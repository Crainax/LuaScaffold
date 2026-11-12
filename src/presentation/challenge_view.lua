-- Local presentation only. Every gameplay action crosses the command bridge.
local M={}
local messages={
    ['not owner']='无法操作其他玩家的英雄', ['unknown hero']='英雄已失效',
    ['stale target']='目标已失效，请重新开始试炼', ['actor unavailable']='英雄无法施法',
    ['target unavailable']='目标已失效', ['already casting']='正在施法', ['cooldown']='技能尚未冷却',
    ['energy']='能量不足', ['range']='目标超出距离', ['friendly target']='不能攻击友方',
    ['already chosen']='天赋已选择', ['skill busy']='施法期间不能选择天赋',
    ['already in challenge']='试炼已经开始', ['stale session']='这场试炼已经结束',
    ['inactive player']='玩家已退出，无法执行操作',
}
function M.start(ui,bridge,world)
    local j=require 'jass.common'
    local player=j.GetPlayerId(j.GetLocalPlayer())
    local party=world.heroes.by_player[player] or {}
    local class=ui.class
    local self={selected=1,buttons={},labels={}}
    local panel=class.panel:builder{x=20,y=20,w=590,h=355,normal_image='core\\panel.blp'}
    self.panel=panel
    local function text(x,y,w,h,value,size)
        return class.text:builder{parent=panel,x=x,y=y,w=w,h=h,text=value,font_size=size or 16}
    end
    text(16,10,560,30,'守卫试炼',22)
    local details=text(16,84,555,64,'',16)
    local tips=text(16,240,555,42,'',14)
    local status=text(16,292,555,52,'选择英雄，然后开始试炼。',16)
    local latest_request,timeout_task
    local last_details,last_status,last_hero
    local function clear_timeout()
        if timeout_task then timeout_task:remove();timeout_task=nil end
    end
    local function send(verb,value)
        local hero=party[self.selected];if not hero then return end
        local ok,why=bridge:send(verb,hero.unit_id,value)
        clear_timeout()
        last_status=nil
        if ok then
            latest_request=why
            self.request={seq=why,status='queued'}
            status:set_text('指令已入队，等待执行结果。')
            timeout_task=panel:wait(10000,function()
                timeout_task=nil
                self.request.status='unconfirmed'
                status:set_text('暂未确认执行结果，请检查当前状态。不会自动重试。')
            end)
        else
            latest_request=nil;self.request={status='not_queued',reason=why}
            status:set_text(why=='outgoing queue full' and '指令过多，本次未入队。' or '指令未能入队。')
        end
    end
    local function button(key,x,y,w,label,action)
        local control=class.button:builder{parent=panel,x=x,y=y,w=w,h=34,normal_image='core\\button.blp'}
        self.buttons[key]=control
        self.labels[key]=class.text:builder{parent=control,x=5,y=5,w=w-10,h=24,text=label,font_size=15}
        function control:on_button_clicked()action()end
    end
    local function select_hero(index)
        self.selected=index
        local hero=party[index]
        local unit=hero and world.units:get(hero.unit_id)
        if unit then
            j.PanCameraToTimed(j.GetUnitX(unit.handle),j.GetUnitY(unit.handle),0.25)
            j.ClearSelection();j.SelectUnit(unit.handle,true)
        end
    end
    for index,hero in ipairs(party)do
        local selected=index
        button('hero'..index,16+(index-1)*185,44,175,hero.definition.name,function()select_hero(selected)end)
    end
    button('cast',16,151,175,'施放技能',function()
        local encounter=world.challenges:get(player)
        if encounter then send('cast',encounter.boss_id)else status:set_text('请先开始试炼。')end
    end)
    button('start',201,151,175,'开始试炼',function()send('challenge',1)end)
    button('leave',386,151,175,'结束试炼',function()
        local encounter=world.challenges:get(player)
        if encounter then send('leave',encounter.id)else status:set_text('当前没有进行中的试炼。')end
    end)
    button('talent1',16,200,265,'天赋一',function()send('talent',1)end)
    button('talent2',296,200,265,'天赋二',function()send('talent',2)end)
    local function update()
        local hero=party[self.selected];if not hero then return end
        local skill=world.skills:get(hero.unit_id)
        if not skill then return end
        if last_hero~=hero then
            self.labels.talent1:set_text(hero.definition.talents[1].name)
            self.labels.talent2:set_text(hero.definition.talents[2].name)
            self.labels.cast:set_text(hero.definition.skill.name)
            tips:set_text(hero.definition.talents[1].description..'\n'..hero.definition.talents[2].description)
            last_hero=hero
        end
        local cooldown=math.max(0,skill.cooldown_until-bridge.scheduler:now())/100
        local selected=hero.talent_choice>0 and hero.definition.talents[hero.talent_choice].name or '未选择'
        local value=string.format('%s  |  能量 %d/%d  |  冷却 %.1f 秒\n天赋：%s',hero.definition.name,skill.energy,skill.max_energy,cooldown,selected)
        if value~=last_details then details:set_text(value);last_details=value end
        local result=world.results[player]
        if result and result.seq==latest_request then
            clear_timeout()
            self.request.status=result.ok and 'business_succeeded' or 'business_rejected'
            local encounter=world.challenges:get(player)
            value=result.ok and (encounter and '试炼进行中：施放技能击败守卫。' or '已完成操作。') or (messages[result.reason] or '当前无法执行此操作。')
            value=value..'  已完成试炼：'..(world.challenges.completed[player] or 0)
            if value~=last_status then status:set_text(value);last_status=value end
        end
    end
    panel:loop(100,update);select_hero(1);update()
    function self:stop()panel:destroy();self.buttons={};self.labels={}end
    return self
end
return M
