local tool = require 'ui.tool.tool'
local replay = require 'ui.tool.replay'
local storm = require 'jass.storm'
local ui = require 'ui.client.util'
local japi = require 'jass.japi'
local jassbind = require 'ui.tool.jassbind'


local str2value = tool.str2value
local value2str = tool.value2str

local config_info = tool.config_info


class.config_object = extends(class.panel)
{
    new = function (parent, x, y, w, h, index)
        local panel = class.config_object:builder
        {
            parent = parent,
            x = x,
            y = y,
            w = w,
            h = h,

            normal_image = '',

            button = {
                type = 'button',
                hide_has_event = true,
                w = 96,
                _panel_type = 'tooltip_backdrop',
                text = {
                    type = 'text',
                    text = '使用',
                    align = 'center',
                    font_size = 10,
                }
            },


            edit_background = {
                type = 'panel',
                _type = index ~= 1 and 'tooltip_backdrop',
                normal_image = index == 1 and '',
                x = 102,
                w = w - 106,

                edit = {
                    type = index == 1 and 'text' or 'edit',
                    text = '',
                    x = 10,
                }
            },
        }

        return panel
    end,

    on_button_mouse_enter = function (self, button)
        if button == nil then 
            return 
        end

        if button.attr_type == nil then 
            return
        end 
        local attr_type = button.attr_type

        button:tooltip('属性界面', '右边可以编辑对应的参数。|n数据类型 : ' .. attr_type .. '|n' .. (button.tip or ''), 'top')
    end,
}

class.config_panel = extends(class.panel)
{
    create = function (count)

        local panel = class.config_panel:builder
        {
            _type = 'tooltip_backdrop',
            x = 1920 - 560,
            y = 50,
            w = 400,
            h = 400,

        }

        local list = {}

        local x, y = 20, 60
        local w = panel.w - 40
        local h = 42

        panel.title = panel:add_title_button('', '控件属性', 0, 0, panel.w, 64, 20)

        for i = 1, 20 do 
            local child = panel:add(class.config_object, x, y, w, h, i)
            local button = child.button
            local text = child.text
           
            --button.keys = {'ENTER'}
            --button.keys = {10 - i + 1}
            y = y + h + 10
            list[i] = child
        end 
        panel.list = list

        panel:set_control_size(panel.w, y)
        return panel
    end,

    set_frame_attr = function (self, frame, data)

        local info = config_info[frame.type] or {}
        local default_info = config_info['default']
        for index, child in ipairs(self.list) do 
            local attr_info = default_info[index] or info[index - #default_info]
            if attr_info then 
                local key, tp, name, func = table.unpack(attr_info)

                if func and key and data[key] then 
                    local value = data[key] 

                    local str = value2str(value or 0, tp)
                    local v = str2value(str or '', tp)

                    func(frame, v)
                end 

            end 
        end 

    end,


    set_frame = function (self, frame)
        self.frame = frame 

        local type = frame.type 

        self.title.text:set_text(tool.type_to_name(type))

        local info = config_info[type] or {}
        local default_info = config_info['default']

        local max_height = 60

        for index, child in ipairs(self.list) do 
            local button = child.button
            local text = child.button.text
            local edit = child.edit_background.edit 

            local attr_info = default_info[index] or info[index - #default_info]
            if attr_info then 
                local key, attr_type, name, func, tip = table.unpack(attr_info)
                text:set_text(name)

                local get = tool.get_attr_map[key]
                local value  = frame[key]
                if get then 
                    value = get(frame)
                end 
                local str = value2str(value, attr_type)
                edit:set_text(str)
                button.attr_type = attr_type
                button.tip = tip
                button.func = func 

                max_height = max_height + child.h + 10
                child:show()
            else 
                child:hide()
                child.button.func = nil 

            end 
        end
        self:set_control_size(self.w, max_height)
    end,



    on_button_key_up = function (self, button, str)

        local frame = self.frame 
        if frame == nil then 
            return 
        end 

        local edit = button.parent.edit_background.edit 
        local str = edit:get_text()

        if str == nil or str:len() == 0 then 
            return 
        end 

        if button.func then 
 
            local tp = button.attr_type
            local value = str2value(str, tp)
            local s = value2str(value, tp)
            button.func(frame, value)
            edit:set_text(s)
        end 
        if edit.set_focus then
            edit:set_focus(false)
        end
    end,

    --on_edit_text_changed = function (self, edit, new_str, old_str)
    --   
    --end,
}

local panel = class.config_panel.create(10)

panel:hide()


game.loop(100, function ()
    if #tool.select_group == 1 then 
        panel:show()
        if panel.frame ~= tool.select_group[1] then 
            panel:set_frame(tool.select_group[1])
        end
    else 
        panel:hide()
    end 
    
end)


local event = {
    on_key_down = function (code)

        if code == KEY.ENTER then 
            panel.old_info = nil
            local frame = panel.frame
            if frame == nil then 
                return 
            end 
    
            panel.old_info = replay.frame_encode(frame)

            for index, child in ipairs(panel.list) do 
                if child.is_show then
                    panel:on_button_key_up(child.button, 'ENTER')
                end
            end 
        end
       
    end,

    on_key_up = function (code)
        if code == KEY.ENTER then 
            local frame = panel.frame
            if frame == nil then 
                return 
            end 
            local new_info = replay.frame_encode(frame)
            if panel.old_info then 
                table.insert(tool.cancel_stack, {
                    name = 'change_attr',
                    num = frame.num,
                    new_info = new_info,
                    old_info = panel.old_info,
                })
            end 
        end
    end,
}

game.register_event(event)

return panel