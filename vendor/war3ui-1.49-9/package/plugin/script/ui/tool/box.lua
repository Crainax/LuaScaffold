local replay = require 'ui.tool.replay'
local japi = require 'jass.japi'
local storm = require 'jass.storm'
local tool = require 'ui.tool.tool'


local fraframe_tip_map = tool.fraframe_tip_map


class.tool_box_panel = extends(class.panel)
{
    create = function ()

        local base_control = {
            'panel', 'texture', 
            'text', 'edit',
            'button', 'model',
        }

        local panel = class.tool_box_panel:builder
        {
            _type = 'tooltip_backdrop',
            x = 1920 - 168,
            y = 100,
            w = 158,
            h = 64 + #base_control / 2 * 74 + 20,
        }

        panel.title = panel:add_title_button('', '工具箱', 0, 0, panel.w, 64, 20)
        local x, y = 10, 74
        for index, name in ipairs(base_control) do 
            local child = panel:child_builder {
                type = 'button',
                normal_image = 'core\\' .. name .. '.tga',
                name = name,
                x = x,
                y = y,
                w = 64,
                h = 64,
                has_ani = true,
                level = 2,
            }

            x = x + 74
            if index % 2 == 0 then 
                x = 10
                y = y + 74
            end
        end 


        panel.path_panel = panel:child_builder
        {
            type = 'panel',
            _type = 'tooltip_backdrop',
            y = y + 20,
            x = -100,
            w = 300,
            h = 128,

            title = {
                y = 10,
                h = 32,
                type = 'text',
                align = 'top',
                font_size = 13,
                text = '本地路径'
            },
            

        }

        panel.save_button = panel.path_panel:child_builder {
            _panel_type = 'tooltip_backdrop',
            type = 'button',
            x = 20,
            y = 74,
            w = 94,
            h = 42,
            has_ani = true,
            text = {
                type = 'text',
                text = '保存',
                align = 'center',
                font_size = 13,
            }
        }

        panel.load_button = panel.path_panel:child_builder {
            _panel_type = 'tooltip_backdrop',
            type = 'button',
            x = 138,
            y = 74,
            w = 94,
            h = 42,
            has_ani = true,
            text = {
                type = 'text',
                text = '读取',
                align = 'center',
                font_size = 13,
            }
        }

        panel.input_edit = panel.path_panel:child_builder {
            type = 'panel',
            x = 10,
            y = 32,
            w = 248,
            h = 42,
            _type = 'tooltip_backdrop',
            edit = {
                type = 'edit',
                x = 10,
                w = 238,
                text = "save.lua"
            }
        }


        return panel
    end,

    set_focus = function (self, button)

        if button == nil then 
            if self.focus then 
                self.focus:set_enable(true)
                self.focus_texture:destroy()
                self.focus = nil
            end 
        else 
            self.focus = button 
            self.focus:set_enable(false)
            self.focus_texture = class.panel:builder 
            {
                parent = self.title,
                _type = 'tooltip_backdrop',
                x = button.x,
                y = button.y,
                w = button.w,
                h = button.h 
            }
        end
       
    end,

    on_button_mouse_enter = function (self, button)
        if button == nil then 
            return 
        end 
        local name = button.name 
        if name == nil then 
            return 
        end

        local info =  tool.frame_tip_map[name]
        if info == nil then 
            return 
        end 

        button:tooltip(info[1], info[2], 'top', 300)

    end,

    on_button_clicked = function (self, button)
        if button == nil then 
            return 
        end 
        if button == self.save_button then 
            local name = self.input_edit.edit:get_text()
            if name:len() > 0 then 
                local file_path = (package.local_map_path or '') .. "007\\" .. name
                print(file_path)
                storm.save(file_path, tool.save(name) or '')
            end 
        elseif button == self.load_button then 
            local name = self.input_edit.edit:get_text()
            if name:len() > 0 then 
                local file_path = (package.local_map_path or '') .. "007\\" .. name
                print(file_path)
                local str = storm.load(file_path)
                if str then 
                    tool.load(name, str)
                end 
            end
        else
            self:set_focus(nil)
            game.wait(100, function ()
               self:set_focus(button)
            end)
        end 
        
    end,
}



local box = class.tool_box_panel.create()




return box