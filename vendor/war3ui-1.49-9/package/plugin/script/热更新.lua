
--清空ui类 以及 控件对象
local function clean_ui()
    for control in pairs(class.ui_base._controls) do 
        if control.destroy then 
            control:destroy()
        end 
    end 

    local map = {
        ['ui_base'] = true,
        ['panel'] = true,
        ['button'] = true,
        ['text'] = true,
        ['texture'] = true,
        ['edit'] = true,
        ['model'] = true,
        ['model2'] = true,
        ['handle_manager'] = true,
        ['progress'] = true,
        ['__newindex'] = true,
    }
    for name, cls in pairs(class) do 
        if map[name] == nil then 
            print('重置类', name)
            rawset(class, name, nil)
        end 
    end 
    game.game_event = {}
end




--重载脚本
local function reload(name)
    for requires in pairs(package.loaded) do 
        if requires:find(name) then 
            package.loaded[requires] = nil

            local path = name:gsub('%.', '\\')
            for trigger in pairs(ac.all_triggers) do 
                local src = trigger._src 
                if src and src:find(path) and trigger.removed ~= true then 
                    trigger:remove()
                    print('重载触发器', trigger._src, trigger._line)
                end 
            end 

            for timer in pairs(ac.all_timers) do 
                local src = timer._src 
                if src and src:find(path) and timer.removed ~= true then 
                    timer:remove()
                    print('重载计时器', timer._src, timer._line)
                end 
            end 
        end 
    end 

    xpcall(require, function (msg)
        print(msg, debug.traceback())
    end,name)
end



local ref = {
    [KEY.F5] = function ()
        

        clean_ui()

        reload('界面')
        reload('热更新')
    end,

}

local event = {
    on_key_up = function (code)
        if ref[code] then
            ref[code]()
            return true
        end
    end,
}
game.register_event(event)