--[[
    用来处理控件的事件同步
]]
local ui = require 'ui.client.util'

local queue = game.sync_queue

local sync_key_map = {}

ac.sync_key_map = sync_key_map



local function find(t, list)
	for name, value in pairs(t) do
		table.insert(list, {name, value})
	end
	local mt = getmetatable(t)
	if mt then
		local it = mt.__index
		if it and type(it) == 'table' then
			find(it, list)
		end
	end
end

function apairs(tbl)

	local list = {}

	find(tbl, list)

	local i = 0

	return function ()
		i = i + 1
		local info = list[i]
		if info then
			return table.unpack(info)
		end
		return
	end
end

local function control_has_func(control, func_name)
    local object = control
    while object ~= nil do 
        if object[func_name] then 
            return true 
        end 
        object = object.parent
    end 
    return false 
end 


local function seach_sync_func(control)
    for name, func in apairs(control) do 
        if type(func) == 'function' and name:find('on_sync_') then 
            ui.add_str(name)
        end 
    end 
    if control.parent then 
        seach_sync_func(control.parent)
    end     
end 

--将同步的控件信息记录到哈希表中
local function update_hashtable()
    local i = 0
    for key, button in pairs(sync_key_map) do 
        if button._id == nil or button._id == 0 then 
            sync_key_map[key] = nil
        end 
    end 

    for _, button in pairs(class.button.button_map) do 
        local key = button.sync_key
        if key and sync_key_map[key] == nil then 
            i = i + 1
            sync_key_map[key] = button
            ui.add_str(key)
            seach_sync_func(button)
        end 
    end 
end 


setmetatable(queue, { __newindex = function (self, index, first)
    local control = first.control
    local func_name = 'on_sync_' .. first.event_name:sub(4, -1)
    for i = 1, first.count do 
        local value = first.args[i]
        if type(value) == 'table' then
            if value.sync_key then
                first.args[i] = {ui.get_hash(value.sync_key)}
            else
                first.args[i] = nil
            end
        elseif type(value) == 'function' then
            first.args[i] = nil
        end 
    end 

    --搜索是否拥有有效的回调方法
    local has = control_has_func(control, func_name)
    if has then 
         rawset(self, index, first)
    end 
end})

--刷新队列
local function update_queue()

    update_hashtable()

    if #queue == 0 then 
        return 
    end 

    local first = queue[1] 

    table.remove(queue, 1)
    local control = first.control
    local func_name = 'on_sync_' .. first.event_name:sub(4, -1)
    local info = {
        type = 'sync',
        func_name = 'on_sync',
        params = {
            [1] = ui.get_hash(control.sync_key),
            [2] = ui.get_hash(func_name),
            [3] = first.args,
            [4] = control.sync_data
        }
    }
    ui.send_message(info)
end 


--每0.15秒处理一次队列中的控件事件
game.loop(150, update_queue)