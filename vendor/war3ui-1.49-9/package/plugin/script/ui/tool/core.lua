local tool = require 'ui.tool.tool'
local canvas = require 'ui.tool.canvas'
local box = require 'ui.tool.box'
local replay = require 'ui.tool.replay'
local config_panel = require 'ui.tool.config'
local treelist = require 'ui.tool.treelist'
local jassbind = require 'ui.tool.jassbind'
local mouse_focus 
local is_mouse_down = true
local start_anchor 
local start_x, start_y, start_w, start_h = 0,0,0,0

--操作栈 用来储存每一个操作 以便按 Ctrl + Z 撤回
local cancel_stack = {}

--储存每一个Ctrl+Z的操作 以便按 Ctrl + y 恢复
local resume_stack = {}

local control_map = {}

tool.control_map = control_map

local num = 0


local pointer = class.model:builder 
{
    x = 0,
    y = 0,
    w = 256,
    h = 256,
    model = [[UI\Cursor\HumanCursor.mdl]],
    is_show = false,
}

local clock = os.clock()

tool.is_move = false 

tool.is_drop = false

tool.is_select = false

tool.cancel_stack = cancel_stack

--选择组 是可以同时 复制 删除 移动多个ui的
tool.select_group = {}


--移动组 是可以同时移动多个的 继承自选择组
tool.move_group = {}


--动画索引
tool.anchors = {
    topleft         = 13,
    topright        = 12,
    bottomleft      = 11,
    bottomright     = 10,
}



--创建控件
tool.create_control = function (name_or_info, x, y, not_cancel)

    local name = name_or_info
    local info 
    if type(name) ~= 'string' then 
        name = name_or_info.type 
        info = name_or_info
    end

    local button = class.button:builder 
    {
        _panel_type = 'tooltip_backdrop',
        parent = canvas.buttons,
        x = x,
        y = y,
        w = 16,
        h = 16,
        alpha = 0,

        texture = {
            type = 'texture',
            normal_image = 'core\\move_background.blp',
            is_show = false,
        },

        select = {
            type = 'panel',
            _type = 'tooltip_backdrop',
            alpha = 0.5,
            is_show = false,
        },

        text = {
            type = 'text',
            y = -32,
            w = 200,
            h = 32,
            alpha = 0,
            align = 'topleft',
            font_size = 12,
        },
    }

    function button:set_alpha(alpha)
        class.button.set_alpha(self, alpha)
        self.text:set_alpha(alpha)
    end 

    local control = class[name]:builder
    {
        parent = canvas.controls,
        type = name,
        x = x,
        y = y,
        w = 16,
        h = 16,
        alpha = 0.5,
        normal_image = 'core\\background.blp',
    }


    
    control.is_enable = false

    button.bind_control = control

    control.button = button
    num = num + 1 
    control.num = num 
    control_map[num] = control

    local list_ui = treelist:add_child_tree()

    control.list_ui = list_ui
    list_ui.num = num
    treelist:set_state(true)

    local set_parent = list_ui.set_parent 
    function list_ui:set_parent(parent, not_cancel)
        local target_list_ui = parent.parent 
        local num = target_list_ui.num 

   
        local target = control_map[num or 0]

        if not_cancel == nil then
            table.insert(cancel_stack, {
                name = 'set_parent',
                num = control.num,
                old_parent_num = control.parent and control.parent.num,
                new_parent_num = target and target.num,
            })
        end

        local x, y = control:get_real_position()

        control:set_parent(target)

        set_parent(self, parent)
       
       
        control:set_real_position(x, y)
    end 

    if not_cancel == nil then
 
        table.insert(cancel_stack, {name = 'create_control', num = num, x = x, y = y})

        
    end 

    local set_position = control.set_position
    function control:set_position(x, y)
        set_position(self, x, y)

        local x, y = self:get_real_position()
        button:set_real_position(x - 10, y - 10)
        
        local rx, ry = self:get_real_position()
        local str = string.format("|cffff0000%.0f, %.0f,|r|cff00ff00 %.0f, %.0f|r", rx, ry, self.w, self.h)
        button.text:set_text(str)


        local function reset_position(object)
            if object.children then
                for index, child in ipairs(object.children) do 
                    if child.button then 
                        local x, y = child:get_real_position()
                        child.button:set_real_position(x - 10, y - 10)
                    end 
                    reset_position(child)
                end 
            end
        end
        reset_position(self)
    end 

    local set_control_size = control.set_control_size
    function control:set_control_size(w, h)
        set_control_size(self, w, h)
        button:set_control_size(w + 20, h + 20)

        button.texture:set_position(button.w / 4, button.h / 4)
        button.texture:set_control_size(button.w / 2, button.h / 2)
        button.select:set_control_size(button.w, button.h)
        
        local str = string.format("%0f, %0f, %0f, %f", self.x, self.y, self.w, self.h)
        button.text:set_text(str)

    end 
    
    control:set_position(x, y)

    if info then
        local parent = control_map[info.parent_num or 0]
        if parent and parent.list_ui then 
            control.list_ui:set_parent(parent.list_ui.bar, true)
        end

        for k, v in ipairs(info) do
            if type(v) == 'table' and v.type and v._id == nil then 
                local child = tool.create_control(v, v.x, v.y, true)
                child.list_ui:set_parent(list_ui.bar, true)
                child:set_position(v.x, v.y)
            end
        end
        list_ui:set_state(true)
        config_panel:set_frame_attr(control, info)
    end 
    
    return control
end 
 
tool.destroy_control = function (control_group, not_cancel)

    if not_cancel == nil then 
        local list = {}
        for index, control in ipairs(control_group) do 

            local info = replay.frame_encode(control)
            info.num = control.num 
            table.insert(list, info)
        end 
        
        table.insert(cancel_stack, {
            name = 'destroy_control', 
            info_list = list
        })
    end 


    local function destroy(object)
        if object.children then
            for index, child in ipairs(object.children) do
                destroy(child)
            end
        end
        if object.list_ui then 
            object.list_ui:destroy()
            object.button:destroy()
        end
    end

    for i = #control_group, 1, -1 do 
        local control = control_group[i]
        destroy(control)
        control:destroy()
        table.remove(control_group, i)
    end 

end



tool.mouse_move_start = function (focus, x, y)

    tool.is_move = true 

    
    local press_ctrl = japi.GetKeyState(KEY.CTRL)
    if #tool.select_group == 1 and focus ~= tool.select_group[1] and not press_ctrl then 
        tool.clear_select()
    end

    local is_only = true 

    --拖拽 单击选中的 控件
    for index, control in ipairs(tool.select_group) do 
        local rx, ry = control:get_real_position()
        table.insert(tool.move_group,{
            num = control.num,
            start_x = rx,
            start_y = ry,
            start_w = control.w,
            start_h = control.h,

            move_offset_x = rx - x,
            move_offset_y = ry - y 
        })

        control.button.texture:show() 

        is_only = false 
    end 

    -- 如果 指向的是唯一的 没有在选中的控件里 则 拖拽指向的按钮
    if is_only then 
        local rx, ry = focus:get_real_position()
        table.insert(tool.move_group,{
            num = focus.num,
            start_x = rx,
            start_y = ry,
            start_w = focus.w,
            start_h = focus.h,

            move_offset_x = rx - x,
            move_offset_y = ry - y 
        })
        focus.button.texture:show() 
    end 

       
    mouse_focus = focus
    
    table.insert(cancel_stack, {
        name = 'mouse_move', 
        move_list = tool.move_group,
    })
end 


tool.mouse_move_end = function ()
    tool.move_position()
    
    for index, info in ipairs(tool.move_group) do 
        local control = control_map[info.num]
        local rx, ry = control:get_real_position()
        info.target_x = rx 
        info.target_y = ry
        info.target_w = control.w 
        info.target_h = control.h
    end 
   
    tool.move_group = {}

    if #tool.select_group == 1 and tool.is_drop then 
        tool.clear_select()
    end

    tool.is_move = false 
end 


--返回移动后的 x, y
tool.move_position = function ()
    local x, y = game.get_mouse_pos()
    if tool.is_move then 

        for index, info in ipairs(tool.move_group) do 
            local control = control_map[info.num]
            local move_x, move_y = x + info.move_offset_x, y + info.move_offset_y
            control:set_real_position(move_x, move_y)
        end

        if #tool.select_group == 1 then 
            local frame = tool.select_group[1]
            config_panel:set_frame(frame)
        end 
    end 
end 



tool.reset_size_start = function (control, x, y, anchor, not_cancel)
    --记录起始坐标
    start_x, start_y = x, y 
    start_anchor = anchor or 'topleft'
    mouse_focus = control
    

    if not_cancel == nil then 
        local rx, ry = control:get_real_position()
        table.insert(cancel_stack, 
        {
            name = 'reset_size', 
            num = control.num, 
            start_x = rx, 
            start_y = ry, 
            start_w = control.w, 
            start_h = control.h
        })
    end 
end 

tool.reset_size_end = function (control)

    if control._is_init_size then 
        tool.reset_size()
        local rx, ry = control:get_real_position()
        table.insert(cancel_stack, {
            name = 'create_control', 
            num = control.num,
            x = rx,
            y = ry,
            w = control.w,
            h = control.h,
        })
    else 
        for i = #cancel_stack, 1, -1 do 
            local last = cancel_stack[i]
            if last.num == control.num and last.name == 'reset_size' then 
                local rx, ry = control:get_real_position()
                last.target_x = rx
                last.target_y = ry
                last.target_w = control.w 
                last.target_h = control.h
                break
            end 
        end 
    end
end 

tool.reset_size = function ()
    local x, y = game.get_mouse_pos()

    if x > start_x and y > start_y then 
        start_anchor = 'topleft'
    elseif x < start_x and y > start_y then 
        start_anchor = 'topright'
    elseif x < start_x and y < start_y then 
        start_anchor = 'bottomright'
    elseif x > start_x and y < start_y then 
        start_anchor = 'bottomleft'
    end 

    local w = math.abs(x - start_x)
    local h = math.abs(y - start_y)

    mouse_focus:set_control_size(w, h)

    local offset_x, offset_y = mouse_focus:get_anchor_offset(start_anchor)
    mouse_focus:set_real_position(start_x - offset_x, start_y - offset_y)

    config_panel:set_frame(mouse_focus)
end 


tool.add_select_control = function (control)
    local button = control.button 

    if button == nil then 
        return 
    end 

    for i = #tool.select_group, 1, - 1 do 
        local select = tool.select_group[i]
        if select == control then 
            return 
        end 
    end 

    button.select:show()
    table.insert(tool.select_group, control)
end 

tool.remove_select_control = function (control)
    local button = control.button 

    for i = #tool.select_group, 1, - 1 do 
        if tool.select_group[i] == control then 
            button.select:hide()
            table.remove(tool.select_group, i)
            return
        end 
    end 


end


tool.clear_select = function ()
    for i = #tool.select_group, 1, - 1 do 
        local control = tool.select_group[i]
        control.button.select:hide()
        control.button:clear_effect()
        table.remove(tool.select_group, i)
    end 
end

--撤回
tool.cancel = function ()
    if #cancel_stack == 0 then 
        return 
    end 

    local last = cancel_stack[#cancel_stack]
    table.remove(cancel_stack, #cancel_stack) 


    --记录恢复操作
    table.insert(resume_stack, last)


    if last.name == 'create_control' then --上一次操作是 创建控件 则进行删除

        local control = control_map[last.num]
        if control then 
            local rx, ry = control:get_real_position()
            local info = replay.frame_encode(control)
            info.name = last.name
            info.num = last.num 
            info.x = rx
            info.y = ry 
            last = info 
            tool.destroy_control({ control }, true)
        end 
    elseif last.name == 'destroy_control' then --上一次操作是删除控件 则重新创建回来 可能一次性删除多个 所以这里得循环
        for index, info in ipairs(last.info_list) do 
            local old_control = control_map[info.num]
            if old_control and old_control._id then 
                tool.destroy_control({ old_control }, true)
            end 

            local control = tool.create_control(info, info.x, info.y, true)
            control_map[info.num] = control
        end 
    elseif last.name == 'mouse_move' then --上一次的操作是 移动位置 还原位置
        for index, info in ipairs(last.move_list) do 
            local control = control_map[info.num]
            if control then 
                control:set_real_position(info.start_x, info.start_y)
            end 
        end 
       
    elseif last.name == 'reset_size' then --上一次的操作是 拖拽大小 还原位置跟大小
        local control = control_map[last.num]
        if control then 
            control:set_real_position(last.start_x, last.start_y)
            control:set_control_size(last.start_w, last.start_h)
        end 
    elseif last.name == 'change_attr' then --上一次操作是改变属性 撤回则把属性改回来
        local control = control_map[last.num]
        if control then 
            config_panel:set_frame_attr(control, last.old_info)
        end 
    elseif last.name == 'set_parent' then --上一次操作是改变父控件 则把属性改回来
        local control = control_map[last.num]
        if control then 
            local old_parent = control_map[last.old_parent_num or 0]
            local new_parent = control_map[last.new_parent_num or 0]
            
            local list_ui = control.list_ui
            local old_parent_list_ui = old_parent and old_parent.list_ui or treelist 
            local new_parent_list_ui = new_parent and new_parent.list_ui or treelist 

            list_ui:set_parent(old_parent_list_ui.bar, true)

            if old_parent_list_ui then 
                if old_parent_list_ui.parent then 
                    old_parent_list_ui.parent.parent:set_state(true)
                end
            end 
            if new_parent_list_ui then 
                new_parent_list_ui:set_state(true)
                if new_parent_list_ui.parent then 
                    new_parent_list_ui.parent.parent:set_state(true)
                end
            end
        end 
    end
end 

--恢复
tool.resume = function ()
    if #resume_stack == 0 then 
        return 
    end 
    local last = resume_stack[#resume_stack]
    table.remove(resume_stack, #resume_stack) 

    --将操作压回栈里 以便能再次被撤回
    table.insert(cancel_stack, last)

    if last.name == 'create_control' then --创建操作被撤回后 恢复应该重新创建出来
        local old_control = control_map[last.num]
        if old_control and old_control._id then 
            tool.destroy_control({ old_control }, true)
        end 

        local control = tool.create_control(last, last.x, last.y, true)
        control_map[last.num] = control
         
    elseif last.name == 'destroy_control' then --删除操作被撤回 恢复操作 应该重新删除它
        local list = {}
        for index, info in ipairs(last.info_list) do 
            local control = control_map[info.num]
            if control then 
                table.insert(list, control)
            end 
        end 
        tool.destroy_control(list, true)
       
    elseif last.name == 'mouse_move' then --移动操作被撤回 应该重新移动到目的地
        for index, info in ipairs(last.move_list) do 
            local control = control_map[info.num]
            if control then 
                control:set_real_position(info.target_x or info.start_x, info.target_y or info.start_y)
            end 
        end 
    elseif last.name == 'reset_size' then --拖拽操作被撤回 应该重新设置位置 跟大小
        local control = control_map[last.num]
        if control then 
            control:set_real_position(last.target_x or last.start_x, last.target_y or last.start_y)
            control:set_control_size(last.target_w or last.start_w, last.target_h or last.start_h)
        end 
    elseif last.name == 'change_attr' then --改变属性被撤回 重新修改一次
        local control = control_map[last.num]
        if control then 
            config_panel:set_frame_attr(control, last.new_info)
        end 
    elseif last.name == 'set_parent' then --改变父控件 重新修改一次
        local control = control_map[last.num]
        if control then 
            local old_parent = control_map[last.old_parent_num or 0]
            local new_parent = control_map[last.new_parent_num or 0]
            
            local list_ui = control.list_ui
            local old_parent_list_ui = old_parent and old_parent.list_ui or treelist 
            local new_parent_list_ui = new_parent and new_parent.list_ui or treelist 
            list_ui:set_parent(new_parent_list_ui.bar, true)
            if old_parent_list_ui then 
                old_parent_list_ui:set_state(true)
            end 
            if new_parent_list_ui then 
                new_parent_list_ui:set_state(true)
            end
        end 
    end 
end 

--剪切
tool.cut = function ()
    tool.copy()

    tool.destroy_control(tool.select_group)
    tool.select_group = {}
end 


--复制
tool.copy = function ()

    local data = {}
    
    local x, y = game.get_mouse_pos()

    for index, control in ipairs(tool.select_group) do 

        local rx, ry = control:get_real_position()
        local info = replay.frame_encode(control)
        info.x = rx - x
        info.y = ry - y
        info.parent_num = control.parent and control.parent.num 
        data[index] = info
    end 

    local str = replay.table_encode(data)

    japi.set_copy_str(str)
end 

--黏贴
tool.paste = function ()
    local str = japi.get_copy_str()
    if str == nil or str == '' then 
        return 
    end 

    local data


    pcall(function ()
        local func = load('return ' .. str)
        if func == nil then 
            return 
        end 

        data = func()
    end)

    if not data then 
        return 
    end 

    local x, y = game.get_mouse_pos()
    

    tool.clear_select()

    local list = {}
    for index, info in ipairs(data) do
        local control = tool.create_control(info, info.x + x, info.y + y) --黏贴
        
        local rx, ry = control:get_real_position()
        table.insert(tool.move_group,{
            num = control.num,
            start_x = rx,
            start_y = ry,
            start_w = control.w,
            start_h = control.h,

            move_offset_x = info.x,
            move_offset_y = info.y, 
            is_paste = true,
        })

        tool.add_select_control(control)
        control.button.texture:show() 
    end 
       
    tool.is_move = true,
    
    table.insert(cancel_stack, {
        name = 'mouse_move', 
        move_list = tool.move_group,
    })

end

--将当前画布里的内容 保存为字符串脚本
tool.save = function (file_path)
    local data = {}
    

    local function replace_name(object)
        if  type(object) == 'table' then 
            if object.name then 
                object.name = file_path .. object.name 
                object.sync_key = file_path .. object.sync_key 
            end
            for index, child in pairs(object) do 
                replace_name(child)
            end
        end 
    end 

    for index, control in ipairs(canvas.controls.children) do 
        if (control._panel) --所有2层叠加的控件
        or (control._panel == nil and control._control == nil) then --单层的控件 
            local info = replay.frame_encode(control)
            replace_name(info)
          
            table.insert(data, info)
        end
    end 

    local str = replay.table_encode(data)

    return str
end


--加载字符串脚本 到当前画布里
tool.load = function (file_path, str)
    local data


    pcall(function ()
        local func = load('return ' .. str)
        if func == nil then 
            return 
        end 

        data = func()
    end)

    if not data then 
        return 
    end 

    for index, info in ipairs(data) do
        info.name = nil 
        info.sync_key = nil
        local control = tool.create_control(info, info.x, info.y)
    end 

end


--自动对齐
tool.set_align = function (anchor)

    local minx, miny, maxx, maxy
    
    if #tool.select_group == 0 then 
        return 
    end 

    for index, control in ipairs(tool.select_group) do 
        local rx, ry = control:get_real_position()
        if anchor == 'left' then 
            
            if minx == nil or rx < minx then 
                minx = rx
            end
        elseif anchor == 'right' then 
            if maxx == nil or rx > maxx then 
                maxx = rx + control.w
            end
        elseif anchor == 'top' then 
            if miny == nil or ry < miny then 
                miny = ry
            end
        elseif anchor == 'bottom' then 
            if maxy == nil or ry > maxy then 
                maxy = ry + control.h
            end
        end 

    end 

    if minx then 
       minx = math.min(math.max(minx - 20, 0), 1920)
    end 
    if miny then 
        miny = math.min(math.max(miny - 20, 0), 1920)
    end 
    if maxx then 
        maxx = math.min(math.max(maxx + 20, 0), 1920)
    end 
    if maxy then 
        maxy = math.min(math.max(maxy + 20, 0), 1920)
    end 

    --搜索目标位置 寻找一个没有跟其他控件区域没有交集的坐标
    local function find_target_position(frame, x, y, w, h)
        local target_x, target_y = x, y
        if minx then 
            target_x = target_x + 10
            if target_x <= 0 or target_x >= 1920 then 
                return 0, target_y 
            end
        end 
        if miny then 
            target_y = target_y + 10
            if target_y <= 0 or target_y >= 1080 then 
                return target_x, 0 
            end
        end 
        if maxx then 
            target_x = target_x - 10
            if target_x <= 0 or target_x >= 1920 then 
                return 0, target_y 
            end
        end 
        if maxy then 
            target_y = target_y - 10
            if target_y <= 0 or target_y >= 1080 then 
                return target_x, 0 
            end
        end 

       
        local has = false
        for index, control in ipairs(tool.select_group) do
            if control ~= frame and (control:point_in_rect(target_x, target_y) 
            or control:point_in_rect(target_x + w, target_y) 
            or control:point_in_rect(target_x, target_y + h) 
            or control:point_in_rect(target_x + w, target_y + h))
            then 
                has = true
            end
        end

        if has == false then 
            return target_x, target_y
        end

        return find_target_position(frame, target_x, target_y, w, h)
    end
   
    local list = {}

    for i, v in ipairs(tool.select_group) do 
        list[i] = v
    end 
    table.sort(list, function (a, b)
        if minx then 
            return a.x < b.x 
        elseif miny then 
            return a.y < b.y 
        elseif maxx then 
            return a.x > b.x 
        elseif maxy then 
            return a.y > b.y
        end
        return true
    end)
    local move_list = {}
    for index, control in ipairs(list) do
        local rx, ry = control:get_real_position()
        local x = minx or maxx or rx
        local y = miny or maxy or ry

        x, y = find_target_position(control, x, y, control.w, control.h)

        table.insert(move_list, {
            num = control.num,
            start_x = rx,
            start_y = ry,
            start_w = control.w,
            start_h = control.h,
            target_x = x,
            target_y = y,
            target_w = control.w,
            target_h = control.h,
        }) 
        control:set_real_position(x, y)
    end
    table.insert(cancel_stack, {
        name = 'mouse_move', 
        move_list = move_list,
    })
end 


local event = {
    on_mouse_down = function ()

        if tool.is_move then 
            tool.mouse_move_end()
        end 

        is_mouse_down = true

        mouse_focus = nil

        tool.is_select = false 

        tool.is_move = false

        tool.is_drop = false 

        clock = os.clock()

        local x, y = game.get_mouse_pos()

        if box:point_in_rect(x, y) or (config_panel:point_in_rect(x, y) and config_panel:get_is_show()) then 
            return 
        end 
        
        --有新的操作之后 将无法再恢复撤回的指令
        resume_stack = {}

        local focus = box.focus
        --如果盒子没有选中按钮
        if focus == nil then
            --判断鼠标是否有选中一块界面
            local button = tool.mouse_button

            --如果鼠标点击空白区域 取消选择
            if button == nil or button.bind_control == nil then 
                tool.clear_select()
                tool.is_select = true
                start_x = x 
                start_y = y 
                return 
            end 
            local control = button.bind_control
            --判断鼠标在 界面的哪个边缘
            for anchor in pairs(tool.anchors) do 
                local cx, cy = button:get_anchor_offset_position(anchor)
                if math.abs(cx - x) < 24 and math.abs(cy - y) < 24 then 
                    --记录起始坐标
                    local sx, sy = control:get_anchor_offset_position(anchor, true)
                    tool.reset_size_start(control, sx, sy, anchor)
                    return 
                end
            end
                
            --否则在中心位置 则表示是移动
            local cx, cy = button:get_anchor_offset_position('center')
            if math.abs(cx - x) < button.w and math.abs(cy - y) <  button.h  then 
                tool.mouse_move_start(control, x, y)
            end
                
            return 
        else 
            local control = tool.create_control(focus.name, x, y, true) --拖拽创建
            control._is_init_size = true
            tool.reset_size_start(control, x, y, nil, true)
            
        end 

    end,

    on_mouse_up = function ()
        is_mouse_down = false 

        if os.clock() - clock <= 0.3 then 
            local button = tool.mouse_button

            if button and button.parent == canvas.buttons then 
                local press_ctrl = japi.GetKeyState(KEY.CTRL)
                local control = button.bind_control 
                if press_ctrl ~= true then 
                    tool.clear_select()
                else 
                    if button.select.is_show then 
                        tool.remove_select_control(control)
                        return 
                    end
                end
                tool.add_select_control(control)
            end
        else 
            tool.is_drop = true
        end

        if tool.is_move then 
            tool.mouse_move_end()
        elseif mouse_focus then
            tool.reset_size()
            tool.reset_size_end(mouse_focus)
        end 
        mouse_focus = nil


        tool.is_select = false
      
    end,

    on_mouse_move = function ()

        local x, y = game.get_mouse_pos()

        pointer:hide()
      

        pointer:set_real_position(x, y - pointer.h)

        --如果是框选
        if tool.is_select then 
            local x, y = game.get_mouse_pos()

            local minx = math.min(start_x, x)
            local miny = math.min(start_y, y)
            local maxx = math.max(start_x, x)
            local maxy = math.max(start_y, y)
            tool.clear_select()

            local list = {}
            local min_stack = 99999

            local function find_frame(object)
                if object.children then 
                    for index, control in ipairs(object.children) do 

                        if (control._panel) --所有2层叠加的控件
                        or (control._panel == nil and control._control == nil) then --单层的控件 
                            local rx, ry = control:get_real_position()
                            local cx, cy = rx + control.w / 2, ry + control.h / 2
                            if minx <= cx and cx <= maxx and miny <= cy and cy <= maxy and not control:point_in_rect(start_x, start_y) then 
                                local stack = control:get_stack_count()
                            
                                table.insert(list, {control, stack})
                            
                                if stack < min_stack then 
                                    min_stack = stack 
                                end
                            end
                            find_frame(control)
                        end
                    end
                end
            end

            find_frame(canvas.controls)

            for index, tbl in ipairs(list) do 
                if tbl[2] == min_stack then 
                    tool.add_select_control(tbl[1])
                end
            end 

        end


        --如果盒子没有选中按钮
        if tool.is_move ~= true and focus == nil and mouse_focus == nil then
            --判断鼠标是否有选中一块界面
            local button = tool.mouse_button
            if button then 
                local control = button.bind_control
                if control then 
                    button.texture:hide()
                    --判断鼠标在 界面的哪个边缘
                    for anchor, index in pairs(tool.anchors) do 
                        local cx, cy = button:get_anchor_offset_position(anchor)
                        if math.abs(cx - x) < 24 and math.abs(cy - y) < 24 then 
                            button.texture:hide()
                            pointer:show()
                            pointer:set_animation_by_index(index)
                            return
                        end
                    end
                    local cx, cy = button:get_anchor_offset_position('center')
                    if math.abs(cx - x) < button.w  and math.abs(cy - y) <  button.h then 
                        button.texture:show() 
                        pointer:show()
                        pointer:set_animation_by_index(0)
                    end
                    
                    return
                end  
            end     
        end 

        if tool.is_move then 
            tool.move_position()
        elseif mouse_focus then
            tool.reset_size()
        end 

        

    end,


    on_mouse_right_up = function ()
        box:set_focus(nil)

        local has = false 
        for index, info in ipairs(tool.move_group) do 
            if info.is_paste then 
                has = true 
            end 
        end 
        if has then 
            tool.destroy_control(tool.select_group)
        end 
        tool.clear_select()
        
    end,

    on_key_down = function (code)
        if mouse_focus then 
            return 
        end 

        local press_ctrl = japi.GetKeyState(KEY.CTRL)

        if code == KEY.Z and press_ctrl then --撤回操作
            tool.cancel()
        elseif code == KEY.Y and press_ctrl then --恢复撤回的操作
            tool.resume()
        end
    end,

    on_key_up = function (code)
        if mouse_focus then 
            return 
        end 

        box:set_focus(nil)

        local press_ctrl = japi.GetKeyState(KEY.CTRL)

        if code == KEY.ESC then 
            local has = false 
            for index, info in ipairs(tool.move_group) do 
                if info.is_paste then 
                    has = true 
                end 
            end 
            if has then 
                tool.destroy_control(tool.select_group)
            end 
            tool.clear_select()
        elseif code == 46 then -- del 
        
            --有新的操作之后 将无法再恢复撤回的指令
            resume_stack = {}
            tool.destroy_control(tool.select_group)
            
        --elseif code == KEY.Z and press_ctrl then --撤回操作
        --    tool.cancel()
        --elseif code == KEY.Y and press_ctrl then --恢复撤回的操作
        --    tool.resume()
        elseif code == KEY.X and press_ctrl then --剪切
            tool.cut()
        elseif code == KEY.C and press_ctrl then --复制
            tool.copy()
        elseif code == KEY.V and press_ctrl then --黏贴
            tool.paste()
        elseif code == KEY.A and press_ctrl then --全选
            for index, control in ipairs(canvas.controls.children) do 
                tool.add_select_control(control)
            end
        elseif code == KEY.LEFT then --向左对齐
            tool.set_align('left')
        elseif code == KEY.RIGHT then --向右对齐
            tool.set_align('right')
        elseif code == KEY.TOP then --向上对齐
            tool.set_align('top')
        elseif code == KEY.BOTTOM then --向下对齐
            tool.set_align('bottom')
        end
    end,
}


game.register_event(event)



return tool