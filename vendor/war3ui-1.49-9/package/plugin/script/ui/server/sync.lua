local ui = require 'ui.server.util'

local event = {
    on_sync = function (key_hash, event_hash, args, sync_data)
        local key = ui.get_str(key_hash)
        local event_name = ui.get_str(event_hash)

        if key == nil then 
            print('同步错误， 不存在的键值', key_hash, debug.traceback())
        end 
        if event_name == nil then 
            print('同步错误， 不存在的事件名', event_hash, debug.traceback())
        end 

        args = args or {}

        local button = ac.sync_key_map[key]
        if button == nil then 
            print('同步错误， 不存在的按钮', key, debug.traceback())
            return
        end 

        for k, v in pairs(args) do 
            if type(v) == 'table' then
                local str = ui.get_str(v[1])
                if str then
                    local col = ac.sync_key_map[str] 
                    if col then
                        args[k] = col
                    end 
                end
            end
        end 
        button.sync_data = sync_data 
        if ac.game then 
            local player = ui.player 
            --拦截同步的ui操作
            if player:event_dispatch('ui:' .. event_name, player, button, table.unpack(args)) then 
                return 
            end 
        end 
        
        -- print('派发同步事件', event_name, table.unpack(args))
        button:event_callback(event_name, ui.player, table.unpack(args))

    end,
}

ui.register_event('sync', event)