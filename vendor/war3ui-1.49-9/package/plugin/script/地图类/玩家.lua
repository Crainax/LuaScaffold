local jass = require 'jass.common'
local dbg = require 'jass.debug'
local player = {}

setmetatable(player, player)
ac.player = player

local mt = {}

player.__index = mt 

mt.type = '玩家'

--句柄
mt.handle = jass.ConvertUnitState(0)

mt.id = 1 


function mt:get()
    return self.id 
end 


function mt:get_name()
    return jass.GetPlayerName(self.handle)
end 

--是否是玩家
function mt:is_player()
	return jass.GetPlayerController(self.handle) == jass.MAP_CONTROL_USER and jass.GetPlayerSlotState(self.handle) == jass.PLAYER_SLOT_STATE_PLAYING
end

--是否是本地玩家
function mt:is_self()
	return self == player.self
end

--发送消息
--	消息内容
--	[持续时间]
function mt:sendMsg(text, time)
	jass.DisplayTimedTextToPlayer(self.handle, 0, 0, time or 30, text)
end

--设置科技等级
function mt:set_upgrade_level(id, level)
    if type(id) == 'string' then 
        id = ID(id)
    end 
    return jass.SetPlayerTechResearched(self.handle, id, level)
end 

--获取科技等级
function mt:get_upgrade_level(id)
    if type(id) == 'string' then 
        id = ID(id)
    end 
    return jass.GetPlayerTechCount(self.handle, id, true)
end

--注册事件
function mt:event(name)
	return ac.event_register(self, name)
end

local ac_game = ac.game

--发起事件
function mt:event_dispatch(name, ...)
	local res = ac.event_dispatch(self, name, ...)
	if res ~= nil then
		return res
	end
	local res = ac.event_dispatch(ac_game, name, ...)
	if res ~= nil then
		return res
	end
	return nil
end


function mt:event_notify(name, ...)
	ac.event_notify(self, name, ...)
	ac.event_notify(ac_game, name, ...)
end


function player:__call(i)
	return player[i]
end


--创建玩家(一般不允许外部创建)
function player.create(id, jPlayer)
	local p = {}
    setmetatable(p, player)
    
    p.handle = jPlayer
	dbg.handle_ref(jPlayer)
    player[jPlayer] = p

    p.id = id

    p.base_name = p:get_name()
    
    player[id] = p

    return p 
end 

--一些常用事件
function player.regist_jass_triggers()
	--玩家聊天事件
	local trg = war3.CreateTrigger(function()
		local player = ac.player(jass.GetTriggerPlayer())
		player:event_notify('玩家-聊天', player, jass.GetEventPlayerChatString())
    end)
    
	for i = 1, 16 do
		jass.TriggerRegisterPlayerChatEvent(trg, player[i].handle, '', false)
	end

	--玩家离开事件
	local trg = war3.CreateTrigger(function()
		local p = ac.player(jass.GetTriggerPlayer())
		if p:is_player() then
			player.count = player.count - 1
		end
		p:event_notify('玩家-离开', p)
    end)
    
	for i = 1, 16 do
		jass.TriggerRegisterPlayerEvent(trg, player[i].handle, jass.EVENT_PLAYER_LEAVE)
	end
end


local function init()
	--存活玩家数
	player.count = 0

	--预设玩家
	for i = 1, 16 do
		player.create(i, jass.Player(i - 1))

		--是否在线
		if player[i]:is_player() then
			player.count = player.count + 1
		end
	end


	--本地玩家
	player.self = ac.player(jass.GetLocalPlayer())
	log.debug(('本地玩家[%s][%s]'):format(player.self:get(), player.self:get_name()))

	--注册常用事件
	player.regist_jass_triggers()


end

init()

return player