local runtime = require 'jass.runtime'
local setmetatable = setmetatable
local table = table

local mt = {}
mt.__index = mt

ac.all_triggers = setmetatable({}, {__mode = 'kv'})

--结构
mt.type = 'trigger'

--是否允许
mt.enable_flag = true

mt.removed = false

--事件
mt.event = nil

--禁用触发器
function mt:disable()
	self.enable_flag = false
end

function mt:enable()
	self.enable_flag = true
end

function mt:is_enable()
	return self.enable_flag
end

--运行触发器
function mt:__call(...)
	if self.removed then
		return
	end
	if self.enable_flag then
		return self:callback(...)
	end
end

--摧毁触发器(移除全部事件)
function mt:remove()
	if not self.event then
		return
	end	
	local event = self.event
	self.event = nil
	self.removed = true
	ac.all_triggers[self] = nil 
	ac.wait(0, function()
		for i, trg in ipairs(event) do
			if trg == self then
				table.remove(event, i)
				break
			end
		end
	end)
end

--创建触发器
function ac.trigger(event, callback)

	local info = debug.getinfo(2, "Sl") or {}
	local trg = {
		event = event,
		callback = callback,
		_src = info.short_src,
		_line = info.currentline,
	}
	setmetatable(trg, mt)
	ac.all_triggers[trg] = true 

	table.insert(event, trg)
	return trg
end


function ac.event_dispatch(obj, name, ...)
	local events = obj.events
	if not events then
		return
	end
	local event = events[name]
	if not event then
		return
	end
	for i = #event, 1, -1 do
		local res = event[i](...)
		if res ~= nil then
			return res
		end
	end
end

function ac.event_notify(obj, name, ...)
	local events = obj.events
	if not events then
		return
	end
	local event = events[name]
	if not event then
		return
	end
	--print(name)
	for i = #event, 1, -1 do
		xpcall(event[i],runtime.error_handle,...)
	end

end

function ac.event_register(obj, name)
	local events = obj.events
	if not events then
		events = {}
		obj.events = events
	end
	local event = events[name]
	if not event then
		event = {}
		events[name] = event
		function event:remove()
			events[name] = nil
		end
	end
	return function (f)
		return ac.trigger(event, f)
	end
end

function ac.game:event_dispatch(name, ...)
	return ac.event_dispatch(self, name, ...)
end

function ac.game:event_notify(name, ...)
	return ac.event_notify(self, name, ...)
end

function ac.game:event(name)
	return ac.event_register(self, name)
end


